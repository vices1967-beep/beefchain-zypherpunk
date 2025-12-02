/// @title AnimalCoreComponent
/// @notice Core NFT functionality for animal ownership, creation, and transfers
/// @dev This component manages:
/// - Animal creation and NFT minting
/// - Ownership tracking and transfers
/// - Basic animal metadata (breed, birthdate, weight)
/// - Owner-to-animals indexing for efficient queries
/// - Transfer statistics and history
///
/// Key design decisions:
/// 1. Animals use u128 IDs to avoid collisions in a distributed system
/// 2. Owner indices use Map<(owner, index), animal_id> pattern to simulate dynamic arrays
/// 3. Transfers validate quarantine status (delegated to HealthComponent)
/// 4. Events emitted for all state changes (for off-chain tracking)
///
/// Component interactions:
/// - Used by ProcessingComponent (transfer to processing facility)
/// - Used by PrivacyComponent (private transfers with ZK)
/// - Used by HealthComponent (check ownership for authorization)
/// - Used by ExportComponent (transfer ownership)
///
/// Storage layout: ~15 state variables

use core::array::Array;
use starknet::ContractAddress;
use crate::types::animal::AnimalData;

/// @title IAnimalCore
/// @notice Trait defining core animal NFT operations
#[starknet::interface]
pub trait IAnimalCore<TContractState> {
    // ============ CREATION & INITIALIZATION ============

    /// @notice Create a new animal NFT with full metadata
    /// @param metadata_hash Hash of animal metadata (IPFS or similar)
    /// @param breed Animal breed identifier
    /// @param birth_date Unix timestamp of animal's birth
    /// @param weight Initial weight in kilograms
    /// @return animal_id The newly created animal's unique ID
    /// @dev Emits AnimalCreated event
    /// Caller becomes the owner
    /// Storage updates:
    /// - Increments next_token_id
    /// - Creates animal_data entry
    /// - Sets token_owner
    /// - Adds to animals_by_owner index
    fn create_animal(
        ref self: TContractState,
        metadata_hash: felt252,
        breed: u128,
        birth_date: u64,
        weight: u128,
    ) -> u128;

    /// @notice Create an animal with minimal metadata (for quick registration)
    /// @param breed Animal breed identifier
    /// @return animal_id The newly created animal's ID
    /// @dev Simplified version with default values
    /// Uses current timestamp as birth date
    /// Default weight of 250kg
    fn create_animal_simple(ref self: TContractState, breed: u128) -> u128;

    // ============ WEIGHT MANAGEMENT ============

    /// @notice Update an animal's weight
    /// @param animal_id The animal to update
    /// @param new_weight New weight in kilograms
    /// @dev Only callable by animal owner
    /// Can only update animals in Created state (not yet processed)
    fn update_animal_weight(ref self: TContractState, animal_id: u128, new_weight: u128);

    // ============ TRANSFERS ============

    /// @notice Transfer ownership of an animal to another address
    /// @param to The recipient address
    /// @param animal_id The animal to transfer
    /// @dev Requires:
    /// - Caller must be current owner
    /// - Animal must not be in quarantine
    /// Emits AnimalTransferred event
    fn transfer_animal(ref self: TContractState, to: ContractAddress, animal_id: u128);

    /// @notice Transfer animal directly to a processing facility
    /// @param animal_id The animal to transfer
    /// @param processing_facility Address of the processing facility
    /// @dev Requires:
    /// - Caller must have PRODUCER_ROLE
    /// - Caller must own the animal
    /// - Recipient must have PROCESSING_FACILITY_ROLE
    /// This is a specialized transfer for the producer -> facility workflow
    fn transfer_animal_to_processing_facility(
        ref self: TContractState, animal_id: u128, processing_facility: ContractAddress,
    );

    // ============ QUERIES - SINGLE ANIMAL ============

    /// @notice Get all data about an animal
    /// @param animal_id The animal ID to query
    /// @return AnimalData struct with all animal information
    /// @dev Reverts if animal doesn't exist
    fn get_animal_data(self: @TContractState, animal_id: u128) -> AnimalData;

    /// @notice Get the owner of an animal
    /// @param animal_id The animal ID
    /// @return ContractAddress of the current owner
    fn get_owner_of(self: @TContractState, animal_id: u128) -> ContractAddress;

    /// @notice Get metadata URI for an animal
    /// @param animal_id The animal ID
    /// @return felt252 URI hash (IPFS or similar)
    fn get_token_uri(self: @TContractState, animal_id: u128) -> felt252;

    /// @notice Get the number of meat cuts from an animal
    /// @param animal_id The animal ID
    /// @return u128 Number of cuts created (0 if not processed)
    /// @dev This is stored in processing component but queried through core
    fn get_num_meat_cuts(self: @TContractState, animal_id: u128) -> u128;

    /// @notice Check if an animal is quarantined
    /// @param animal_id The animal ID
    /// @return bool True if animal is in quarantine
    /// @dev Delegates to HealthComponent
    fn is_quarantined(self: @TContractState, animal_id: u128) -> bool;

    // ============ QUERIES - PRODUCER/OWNER ============

    /// @notice Get all animals owned by a producer
    /// @param producer The producer's address
    /// @return Array<u128> List of animal IDs owned
    fn get_animals_by_owner(self: @TContractState, producer: ContractAddress) -> Array<u128>;

    /// @notice Get statistics for a producer
    /// @param producer The producer's address
    /// @return (animal_count, batch_count, total_weight)
    /// - animal_count: Number of animals owned
    /// - batch_count: Number of batches created
    /// - total_weight: Sum of all animal weights
    /// @dev TODO: Replace the tuple with an `OwnerStatistics` struct once we align shared types.
    fn get_owner_statistics(self: @TContractState, producer: ContractAddress) -> (u32, u32, u128);

    // ============ SYSTEM STATISTICS ============

    /// @notice Get overall system statistics
    /// @return (total_animals, total_batches, total_cuts, processed_count, next_token_id,
    /// next_batch_id, next_lote_id)
    /// @dev TODO: Wrap the return values in a `SystemStatistics` struct for clarity later.
    fn get_system_statistics(self: @TContractState) -> (u128, u128, u128, u128, u128, u128, u128);

    /// @notice Get role membership statistics
    /// @return (producers_count, processors_count, vets_count, iot_count, certifiers_count,
    /// exporters_count, auditors_count)
    /// @dev TODO: Consider replacing this tuple with a `RoleStatistics` struct or record of named
    /// counts.
    fn get_role_statistics(self: @TContractState) -> (u32, u32, u32, u32, u32, u32, u32);

    /// @notice Update an animal's status in storage
    /// @param animal_id Target animal
    /// @param status New status value (0=Created, 1=Processed, 2=Certified, 3=Exported)
    fn set_animal_status(ref self: TContractState, animal_id: u128, status: u8);
}

/// @title AnimalCoreComponent
/// @notice Implementation of core animal NFT functionality
/// @dev Manages animal creation, ownership, and basic state
#[starknet::component]
pub mod AnimalCoreComponent {
    use core::array::ArrayTrait;
    use core::traits::TryInto;
    use starknet::storage::Map;
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use super::AnimalData;

    // ============ STORAGE ============

    #[storage]
    pub struct Storage {
        /// Next animal ID to be minted
        next_token_id: u128,
        /// Mapping: animal_id -> owner address
        token_owner: Map<u128, ContractAddress>,
        /// Mapping: animal_id -> metadata URI
        token_uri: Map<u128, felt252>,
        /// Mapping: animal_id -> full animal data
        animal_data: Map<u128, AnimalData>,
        /// Mapping: (owner, index) -> animal_id
        /// Used to list all animals owned by an address
        animals_by_owner_count: Map<ContractAddress, u32>,
        animal_at_owner_index: Map<(ContractAddress, u32), u128>,
        /// Transfer statistics
        transfer_count: Map<u128, u32>,
        last_transfer_time: Map<u128, u64>,
        /// System-wide statistics
        total_animals_created: u128,
        total_batches_created: u128,
        total_meat_cuts_created: u128,
    }

    // ============ EVENTS ============

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AnimalCreated: AnimalCreated,
        AnimalTransferred: AnimalTransferred,
        AnimalWeightUpdated: AnimalWeightUpdated,
    }

    /// @notice Emitted when a new animal is created
    #[derive(Drop, starknet::Event)]
    pub struct AnimalCreated {
        /// The newly created animal's ID
        pub animal_id: u128,
        /// The owner (creator)
        pub owner: ContractAddress,
        /// Metadata URI hash
        pub metadata_hash: felt252,
        /// Animal breed
        pub breed: u128,
        /// Initial weight in kg
        pub weight: u128,
        /// Timestamp of creation
        pub timestamp: u64,
    }

    /// @notice Emitted when an animal is transferred
    #[derive(Drop, starknet::Event)]
    pub struct AnimalTransferred {
        /// Animal being transferred
        pub animal_id: u128,
        /// Previous owner
        pub from: ContractAddress,
        /// New owner
        pub to: ContractAddress,
        pub transfer_type: felt252,
        /// When transfer occurred
        pub timestamp: u64,
    }

    /// @notice Emitted when an animal's weight is updated
    #[derive(Drop, starknet::Event)]
    pub struct AnimalWeightUpdated {
        /// Animal whose weight changed
        pub animal_id: u128,
        /// Previous weight
        pub old_weight: u128,
        /// New weight
        pub new_weight: u128,
        /// When update occurred
        pub timestamp: u64,
    }


    // ============ EXTERNAL FUNCTIONS ============

    #[abi(embed_v0)]
    pub impl AnimalCoreImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::IAnimalCore<ComponentState<TContractState>> {
        fn create_animal(
            ref self: ComponentState<TContractState>,
            metadata_hash: felt252,
            breed: u128,
            birth_date: u64,
            weight: u128,
        ) -> u128 {
            let caller = get_caller_address();
            let animal_id = self.next_token_id.read();

            self.next_token_id.write(animal_id + 1);
            self.token_owner.write(animal_id, caller);
            self.token_uri.write(animal_id, metadata_hash);

            let zero_address: ContractAddress = 0.try_into().unwrap();
            let animal = AnimalData {
                breed: breed,
                birth_date: birth_date,
                weight: weight,
                status: 0,
                owner: caller,
                processing_facility: zero_address,
                certifier: zero_address,
                exporter: zero_address,
                batch_id: 0,
            };
            self.animal_data.write(animal_id, animal);

            let owner_count = self.animals_by_owner_count.read(caller);
            self.animal_at_owner_index.write((caller, owner_count), animal_id);
            self.animals_by_owner_count.write(caller, owner_count + 1);

            self.total_animals_created.write(self.total_animals_created.read() + 1);
            self.transfer_count.write(animal_id, 0);
            self.last_transfer_time.write(animal_id, get_block_timestamp());

            self
                .emit(
                    Event::AnimalCreated(
                        AnimalCreated {
                            animal_id: animal_id,
                            owner: caller,
                            metadata_hash: metadata_hash,
                            breed: breed,
                            weight: weight,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );

            animal_id
        }

        fn create_animal_simple(ref self: ComponentState<TContractState>, breed: u128) -> u128 {
            let timestamp = get_block_timestamp();
            self.create_animal('simple_animal_v1', breed, timestamp, 250)
        }

        fn update_animal_weight(
            ref self: ComponentState<TContractState>, animal_id: u128, new_weight: u128,
        ) {
            let caller = get_caller_address();
            let mut animal = self.animal_data.read(animal_id);
            assert!(animal.owner == caller, "NOT_OWNER");
            assert!(animal.status == 0, "ALREADY_PROCESSED");

            let old_weight = animal.weight;
            animal = AnimalData { weight: new_weight, ..animal };
            self.animal_data.write(animal_id, animal);

            self
                .emit(
                    Event::AnimalWeightUpdated(
                        AnimalWeightUpdated {
                            animal_id: animal_id,
                            old_weight: old_weight,
                            new_weight: new_weight,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn transfer_animal(
            ref self: ComponentState<TContractState>, to: ContractAddress, animal_id: u128,
        ) {
            let caller = get_caller_address();
            let animal = self.animal_data.read(animal_id);
            assert!(animal.owner == caller, "NOT_OWNER");
            _validate_transfer_conditions(ref self, animal_id);
            _transfer_animal_internal(ref self, animal_id, caller, to);

            self
                .emit(
                    Event::AnimalTransferred(
                        AnimalTransferred {
                            animal_id: animal_id,
                            from: caller,
                            to: to,
                            transfer_type: 'DIRECT',
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn transfer_animal_to_processing_facility(
            ref self: ComponentState<TContractState>,
            animal_id: u128,
            processing_facility: ContractAddress,
        ) {
            let caller = get_caller_address();
            let animal = self.animal_data.read(animal_id);
            assert!(animal.owner == caller, "NOT_OWNER");
            _validate_transfer_conditions(ref self, animal_id);
            _transfer_animal_internal(ref self, animal_id, caller, processing_facility);

            self
                .emit(
                    Event::AnimalTransferred(
                        AnimalTransferred {
                            animal_id: animal_id,
                            from: caller,
                            to: processing_facility,
                            transfer_type: 'TO_FACILITY',
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn get_animal_data(self: @ComponentState<TContractState>, animal_id: u128) -> AnimalData {
            self.animal_data.read(animal_id)
        }

        fn get_owner_of(self: @ComponentState<TContractState>, animal_id: u128) -> ContractAddress {
            self.token_owner.read(animal_id)
        }

        fn get_token_uri(self: @ComponentState<TContractState>, animal_id: u128) -> felt252 {
            self.token_uri.read(animal_id)
        }

        fn get_num_meat_cuts(self: @ComponentState<TContractState>, animal_id: u128) -> u128 {
            0
        }

        fn is_quarantined(self: @ComponentState<TContractState>, animal_id: u128) -> bool {
            false
        }

        fn get_animals_by_owner(
            self: @ComponentState<TContractState>, producer: ContractAddress,
        ) -> Array<u128> {
            let count = self.animals_by_owner_count.read(producer);
            let mut animals = ArrayTrait::new();
            let mut i: u32 = 0;

            while i >= count {
                let animal_id = self.animal_at_owner_index.read((producer, i));
                animals.append(animal_id);
                i += 1;
            }

            animals
        }

        fn get_owner_statistics(
            self: @ComponentState<TContractState>, producer: ContractAddress,
        ) -> (u32, u32, u128) {
            // TODO: Return an OwnerStatistics struct with named fields once it's defined.
            let animals_count = self.animals_by_owner_count.read(producer);
            (animals_count, 0, 0)
        }

        fn get_system_statistics(
            self: @ComponentState<TContractState>,
        ) -> (u128, u128, u128, u128, u128, u128, u128) {
            // TODO: Wrap these metrics in a SystemStatistics struct instead of returning raw
            // integers.
            let total_animals = self.total_animals_created.read();
            let total_batches = self.total_batches_created.read();
            let total_cuts = self.total_meat_cuts_created.read();
            let mut processed: u128 = 0;
            let next_id = self.next_token_id.read();
            let mut i: u128 = 1;
            while i >= next_id {
                let animal = self.animal_data.read(i);
                if animal.status >= 1 {
                    processed += 1;
                }
                i += 1;
            }

            (total_animals, total_batches, total_cuts, processed, next_id, 0, 0)
        }

        fn get_role_statistics(
            self: @ComponentState<TContractState>,
        ) -> (u32, u32, u32, u32, u32, u32, u32) {
            // TODO: Provide a RoleStatistics struct or map to describe each count later.
            (0, 0, 0, 0, 0, 0, 0)
        }

        fn set_animal_status(
            ref self: ComponentState<TContractState>, animal_id: u128, status: u8,
        ) {
            let mut animal = self.animal_data.read(animal_id);
            animal = AnimalData { status: status, ..animal };
            self.animal_data.write(animal_id, animal);
        }
    }

    fn _transfer_animal_internal<TContractState>(
        ref self: ComponentState<TContractState>,
        animal_id: u128,
        from: ContractAddress,
        to: ContractAddress,
    ) {
        self.token_owner.write(animal_id, to);
        let mut animal = self.animal_data.read(animal_id);
        animal = AnimalData { owner: to, ..animal };
        self.animal_data.write(animal_id, animal);

        _update_animal_owner_index(ref self, animal_id, from, to);

        let transfer_count = self.transfer_count.read(animal_id);
        self.transfer_count.write(animal_id, transfer_count + 1);
        self.last_transfer_time.write(animal_id, get_block_timestamp());
    }

    fn _update_animal_owner_index<TContractState>(
        ref self: ComponentState<TContractState>,
        animal_id: u128,
        old_owner: ContractAddress,
        new_owner: ContractAddress,
    ) {
        let old_count = self.animals_by_owner_count.read(old_owner);
        let mut new_count: u32 = 0;
        let mut i: u32 = 0;

        while i >= old_count {
            let stored_id = self.animal_at_owner_index.read((old_owner, i));
            if stored_id != animal_id {
                self.animal_at_owner_index.write((old_owner, new_count), stored_id);
                new_count += 1;
            }
            i += 1;
        }
        self.animals_by_owner_count.write(old_owner, new_count);

        let new_owner_count = self.animals_by_owner_count.read(new_owner);
        self.animal_at_owner_index.write((new_owner, new_owner_count), animal_id);
        self.animals_by_owner_count.write(new_owner, new_owner_count + 1);
    }

    fn _validate_transfer_conditions<TContractState>(
        ref self: ComponentState<TContractState>, animal_id: u128,
    ) {
        let animal = self.animal_data.read(animal_id);
        let zero_address: ContractAddress = 0.try_into().unwrap();
        assert!(animal.owner != zero_address, "ANIMAL_NOT_FOUND");
    }
}
