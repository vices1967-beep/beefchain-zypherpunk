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

// Import interfaces from other components
use crate::components::access_control::IAccessControlComponentDispatcher;
use crate::components::health::IHealthComponentDispatcher;
use crate::components::privacy::IPrivacyComponentDispatcher;
use crate::components::processing::IProcessingComponentDispatcher;
use crate::components::certification::ICertificationComponentDispatcher;
use crate::components::export::IExportComponentDispatcher;

/// Role constants for access control (English names)
/// @dev These must match the roles defined in AccessControlComponent
const DEFAULT_ADMIN_ROLE: felt252 = 0;
const PRODUCER_ROLE: felt252 = 'PRODUCER_ROLE';
const PROCESSING_FACILITY_ROLE: felt252 = 'PROCESSING_FACILITY_ROLE';
const VETERINARIAN_ROLE: felt252 = 'VETERINARIAN_ROLE';
const IOT_ROLE: felt252 = 'IOT_ROLE';
const CERTIFIER_ROLE: felt252 = 'CERTIFIER_ROLE';
const EXPORTER_ROLE: felt252 = 'EXPORTER_ROLE';
const AUDITOR_ROLE: felt252 = 'AUDITOR_ROLE';

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
    /// Caller must have PRODUCER_ROLE
    /// Caller becomes the owner
    /// Storage updates:
    /// - Increments next_token_id
    /// - Creates animal_data entry
    /// - Sets token_owner
    /// - Adds to animals_by_owner index
    /// - Initializes animal_cuts to 0
    /// - Creates qr_data entry
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
    /// Uses fixed metadata hash 'simple_animal_v1'
    /// Caller must have PRODUCER_ROLE
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
    /// @dev Reads from animal_cuts storage
    fn get_num_meat_cuts(self: @TContractState, animal_id: u128) -> u128;

    /// @notice Check if an animal is quarantined
    /// @param animal_id The animal ID
    /// @return bool True if animal is in quarantine
    /// @dev Delegates to HealthComponent if connected, otherwise returns false
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
    fn get_owner_statistics(self: @TContractState, producer: ContractAddress) -> (u32, u32, u128);

    // ============ SYSTEM STATISTICS ============

    /// @notice Get overall system statistics
    /// @return (total_animals, total_batches, total_cuts, processed_count, next_token_id,
    /// next_batch_id, next_lote_id)
    fn get_system_statistics(self: @TContractState) -> (u128, u128, u128, u128, u128, u128, u128);

    /// @notice Get role membership statistics
    /// @return (producers_count, processors_count, vets_count, iot_count, certifiers_count,
    /// exporters_count, auditors_count)
    fn get_role_statistics(self: @TContractState) -> (u32, u32, u32, u32, u32, u32, u32);

    /// @notice Update an animal's status in storage
    /// @param animal_id Target animal
    /// @param status New status value (0=Created, 1=Processed, 2=Certified, 3=Exported)
    /// @dev Internal function called by other components during state transitions
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
    use super::{
        DEFAULT_ADMIN_ROLE, PRODUCER_ROLE, PROCESSING_FACILITY_ROLE, VETERINARIAN_ROLE, 
        IOT_ROLE, CERTIFIER_ROLE, EXPORTER_ROLE, AUDITOR_ROLE
    };
    
    // Import dispatcher traits
    use super::{
        IAccessControlComponentDispatcher, IHealthComponentDispatcher, 
        IPrivacyComponentDispatcher, IProcessingComponentDispatcher,
        ICertificationComponentDispatcher, IExportComponentDispatcher
    };

    // ============ STORAGE ============

    #[storage]
    pub struct Storage {
        /// Next animal ID to be minted
        next_token_id: u128,
        /// Mapping: animal_id -> owner address
        token_owner: Map<u128, ContractAddress>,
        /// Mapping: animal_id -> metadata URI
        token_uri: Map<u128, felt252>,
        /// Mapping: animal_id -> full animal data (English field names)
        animal_data: Map<u128, AnimalData>,
        /// Number of cuts per animal
        animal_cuts: Map<u128, u128>,
        /// QR data hash for each animal
        qr_data: Map<u128, felt252>,
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
        total_cuts_created: u128,

        // ============ COMPONENT REFERENCES ============
        /// Reference to AccessControlComponent for role checks
        access_control_component: Map<u32, ContractAddress>,
        /// Reference to PrivacyComponent for privacy initialization
        privacy_component: Map<u32, ContractAddress>,
        /// Reference to HealthComponent for quarantine status
        health_component: Map<u32, ContractAddress>,
        /// Reference to ProcessingComponent for batch info
        processing_component: Map<u32, ContractAddress>,
        /// Reference to CertificationComponent for certification status
        certification_component: Map<u32, ContractAddress>,
        /// Reference to ExportComponent for export info
        export_component: Map<u32, ContractAddress>,
    }

    // ============ EVENTS ============

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AnimalCreated: AnimalCreated,
        AnimalTransferred: AnimalTransferred,
        AnimalWeightUpdated: AnimalWeightUpdated,
        ComponentLinked: ComponentLinked,
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
        /// Transfer type identifier
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

    /// @notice Emitted when a component is linked to AnimalCore
    #[derive(Drop, starknet::Event)]
    pub struct ComponentLinked {
        /// Component type identifier
        pub component_type: felt252,
        /// Contract address of the component
        pub component_address: ContractAddress,
        /// Timestamp of linking
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
            // Check if caller has PRODUCER_ROLE using AccessControlComponent
            _check_role(ref self, PRODUCER_ROLE);

            let animal_id = self.next_token_id.read();
            self.next_token_id.write(animal_id + 1);

            let caller = get_caller_address();
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
            
            // Initialize cuts counter to 0
            self.animal_cuts.write(animal_id, 0);
            
            // Create and store QR hash
            let qr_hash = metadata_hash + animal_id.into();
            self.qr_data.write(animal_id, qr_hash);

            // Initialize privacy data if PrivacyComponent is linked
            let privacy_component_addr = self.privacy_component.read(0);
            if privacy_component_addr != zero_address {
                let privacy_dispatcher = IPrivacyComponentDispatcher {
                    contract_address: privacy_component_addr
                };
                privacy_dispatcher.initialize_privacy_data(animal_id, caller);
            }

            // Add to owner's animal index using helper function
            _add_animal_to_owner(ref self, caller, animal_id);

            // Update system statistics
            self.total_animals_created.write(self.total_animals_created.read() + 1);
            self.transfer_count.write(animal_id, 0);
            self.last_transfer_time.write(animal_id, get_block_timestamp());

            // Emit creation event
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
            // Check if caller has PRODUCER_ROLE using AccessControlComponent
            _check_role(ref self, PRODUCER_ROLE);

            let timestamp = get_block_timestamp();
            // Use fixed metadata hash
            let metadata_hash = 'simple_animal_v1';
            
            // Call create_animal with simplified parameters
            self.create_animal(metadata_hash, breed, timestamp, 250)
        }

        fn update_animal_weight(
            ref self: ComponentState<TContractState>, animal_id: u128, new_weight: u128,
        ) {
            let caller = get_caller_address();
            let mut animal = self.animal_data.read(animal_id);
            
            // Validate ownership and state
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
            
            // Validate ownership
            assert!(animal.owner == caller, "NOT_OWNER");
            
            // Check if animal is quarantined using HealthComponent
            if _is_animal_quarantined(ref self, animal_id) {
                assert!(false, "ANIMAL_QUARANTINED");
            }
            
            _validate_transfer_conditions(ref self, animal_id);
            _transfer_animal_internal(ref self, animal_id, caller, to);

            self
                .emit(
                    Event::AnimalTransferred(
                        AnimalTransferred {
                            animal_id: animal_id,
                            from: caller,
                            to: to,
                            transfer_type: 'STANDARD_TRANSFER',
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
            
            // Validate ownership
            assert!(animal.owner == caller, "NOT_OWNER");
            
            // Check if caller has PRODUCER_ROLE using AccessControlComponent
            _check_role(ref self, PRODUCER_ROLE);
            
            // Check if recipient has PROCESSING_FACILITY_ROLE using AccessControlComponent
            let has_facility_role = _check_role_for_address(ref self, processing_facility, PROCESSING_FACILITY_ROLE);
            assert!(has_facility_role, "RECIPIENT_DOES_NOT_HAVE_PROCESSING_FACILITY_ROLE");
            
            // Check if animal is quarantined using HealthComponent
            if _is_animal_quarantined(ref self, animal_id) {
                assert!(false, "ANIMAL_QUARANTINED");
            }
            
            _validate_transfer_conditions(ref self, animal_id);
            _transfer_animal_internal(ref self, animal_id, caller, processing_facility);

            self
                .emit(
                    Event::AnimalTransferred(
                        AnimalTransferred {
                            animal_id: animal_id,
                            from: caller,
                            to: processing_facility,
                            transfer_type: 'PRODUCER_TO_FACILITY',
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
            // Direct read from storage
            self.animal_cuts.read(animal_id)
        }

        fn is_quarantined(self: @ComponentState<TContractState>, animal_id: u128) -> bool {
            _is_animal_quarantined(self, animal_id)
        }

        fn get_animals_by_owner(
            self: @ComponentState<TContractState>, producer: ContractAddress,
        ) -> Array<u128> {
            let count = self.animals_by_owner_count.read(producer);
            let mut animals = ArrayTrait::new();
            let mut i: u32 = 0;

            while i < count {
                let animal_id = self.animal_at_owner_index.read((producer, i));
                animals.append(animal_id);
                i += 1;
            };

            animals
        }

        fn get_owner_statistics(
            self: @ComponentState<TContractState>, producer: ContractAddress,
        ) -> (u32, u32, u128) {
            let animals_count = self.animals_by_owner_count.read(producer);
            
            // Calculate total weight for this producer
            let mut total_weight: u128 = 0;
            let count = animals_count;
            let mut i: u32 = 0;
            
            while i < count {
                let animal_id = self.animal_at_owner_index.read((producer, i));
                let animal = self.animal_data.read(animal_id);
                total_weight += animal.weight;
                i += 1;
            };
            
            // Get batch count from ProcessingComponent if connected
            let mut batch_count: u32 = 0;
            let processing_component_addr = self.processing_component.read(0);
            let zero_address: ContractAddress = 0.try_into().unwrap();
            
            if processing_component_addr != zero_address {
                let processing_dispatcher = IProcessingComponentDispatcher {
                    contract_address: processing_component_addr
                };
                let batches = processing_dispatcher.get_batches_by_owner(producer);
                batch_count = batches.len();
            }
            
            (animals_count, batch_count, total_weight)
        }

        fn get_system_statistics(
            self: @ComponentState<TContractState>,
        ) -> (u128, u128, u128, u128, u128, u128, u128) {
            let total_animals = self.total_animals_created.read();
            let total_batches = self.total_batches_created.read();
            let total_cuts = self.total_cuts_created.read();
            let next_token_id = self.next_token_id.read();
            
            // Count processed animals
            let mut processed: u128 = 0;
            if next_token_id > 1 {
                let mut i: u128 = 1;
                while i < next_token_id {
                    let animal = self.animal_data.read(i);
                    if animal.status >= 1 {
                        processed += 1;
                    }
                    i += 1;
                };
            }
            
            // Get next_batch_id from ProcessingComponent if connected
            let mut next_batch_id: u128 = 0;
            let processing_component_addr = self.processing_component.read(0);
            let zero_address: ContractAddress = 0.try_into().unwrap();
            
            if processing_component_addr != zero_address {
                // ProcessingComponent doesn't expose next_batch_id directly
                // We'll need to track this separately or estimate
                // For now, use the stored total_batches_created + 1 as estimate
                next_batch_id = total_batches + 1;
            }
            
            // Get next_lote_id from ExportComponent if connected
            let mut next_lote_id: u128 = 0;
            let export_component_addr = self.export_component.read(0);
            
            if export_component_addr != zero_address {
                // ExportComponent doesn't expose next_lote_id directly
                // We'll need to track this separately
                // For now, return 0
                next_lote_id = 0;
            }
            
            (total_animals, total_batches, total_cuts, processed, next_token_id, next_batch_id, next_lote_id)
        }

        fn get_role_statistics(
            self: @ComponentState<TContractState>,
        ) -> (u32, u32, u32, u32, u32, u32, u32) {
            // Query AccessControlComponent for actual role counts if connected
            let access_control_addr = self.access_control_component.read(0);
            let zero_address: ContractAddress = 0.try_into().unwrap();
            
            if access_control_addr != zero_address {
                let access_control_dispatcher = IAccessControlComponentDispatcher {
                    contract_address: access_control_addr
                };
                
                let producers = access_control_dispatcher.get_role_member_count(PRODUCER_ROLE);
                let processors = access_control_dispatcher.get_role_member_count(PROCESSING_FACILITY_ROLE);
                let vets = access_control_dispatcher.get_role_member_count(VETERINARIAN_ROLE);
                let iot = access_control_dispatcher.get_role_member_count(IOT_ROLE);
                let certifiers = access_control_dispatcher.get_role_member_count(CERTIFIER_ROLE);
                let exporters = access_control_dispatcher.get_role_member_count(EXPORTER_ROLE);
                let auditors = access_control_dispatcher.get_role_member_count(AUDITOR_ROLE);
                
                return (producers, processors, vets, iot, certifiers, exporters, auditors);
            }
            
            // Return zeros if AccessControlComponent is not linked
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

    // ============ INTERNAL FUNCTIONS ============

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

        while i < old_count {
            let stored_id = self.animal_at_owner_index.read((old_owner, i));
            if stored_id != animal_id {
                self.animal_at_owner_index.write((old_owner, new_count), stored_id);
                new_count += 1;
            }
            i += 1;
        };
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

    // ============ INTEGRATED COMPONENT FUNCTIONS ============

    /// @notice Check if caller has a specific role using AccessControlComponent
    fn _check_role<TContractState>(
        ref self: ComponentState<TContractState>,
        role: felt252
    ) {
        let access_control_addr = self.access_control_component.read(0);
        let zero_address: ContractAddress = 0.try_into().unwrap();
        
        if access_control_addr != zero_address {
            let access_control_dispatcher = IAccessControlComponentDispatcher {
                contract_address: access_control_addr
            };
            
            let caller = get_caller_address();
            let has_role = access_control_dispatcher.has_role(role, caller);
            assert!(has_role, "CALLER_DOES_NOT_HAVE_REQUIRED_ROLE");
        } else {
            // If AccessControlComponent is not linked, revert for safety
            assert!(false, "ACCESS_CONTROL_COMPONENT_NOT_LINKED");
        }
    }

    /// @notice Check if a specific address has a role using AccessControlComponent
    fn _check_role_for_address<TContractState>(
        ref self: ComponentState<TContractState>,
        address: ContractAddress,
        role: felt252
    ) -> bool {
        let access_control_addr = self.access_control_component.read(0);
        let zero_address: ContractAddress = 0.try_into().unwrap();
        
        if access_control_addr != zero_address {
            let access_control_dispatcher = IAccessControlComponentDispatcher {
                contract_address: access_control_addr
            };
            
            return access_control_dispatcher.has_role(role, address);
        }
        
        // If AccessControlComponent is not linked, return false for safety
        false
    }

    /// @notice Check if an animal is quarantined using HealthComponent
    fn _is_animal_quarantined<TContractState>(
        self: @ComponentState<TContractState>,
        animal_id: u128
    ) -> bool {
        let health_component_addr = self.health_component.read(0);
        let zero_address: ContractAddress = 0.try_into().unwrap();
        
        if health_component_addr != zero_address {
            let health_dispatcher = IHealthComponentDispatcher {
                contract_address: health_component_addr
            };
            
            return health_dispatcher.is_quarantined(animal_id);
        }
        
        // If HealthComponent is not linked, return false
        false
    }

    /// @notice Add animal to owner's index
    fn _add_animal_to_owner<TContractState>(
        ref self: ComponentState<TContractState>,
        owner: ContractAddress,
        animal_id: u128
    ) {
        let count = self.animals_by_owner_count.read(owner);
        self.animal_at_owner_index.write((owner, count), animal_id);
        self.animals_by_owner_count.write(owner, count + 1);
    }

    // ============ COMPONENT LINKING FUNCTIONS ============

    /// @notice Link AccessControlComponent to AnimalCoreComponent
    fn _link_access_control_component<TContractState>(
        ref self: ComponentState<TContractState>,
        component_address: ContractAddress
    ) {
        self.access_control_component.write(0, component_address);
        
        self
            .emit(
                Event::ComponentLinked(
                    ComponentLinked {
                        component_type: 'ACCESS_CONTROL',
                        component_address: component_address,
                        timestamp: get_block_timestamp(),
                    },
                ),
            );
    }

    /// @notice Link PrivacyComponent to AnimalCoreComponent
    fn _link_privacy_component<TContractState>(
        ref self: ComponentState<TContractState>,
        component_address: ContractAddress
    ) {
        self.privacy_component.write(0, component_address);
        
        self
            .emit(
                Event::ComponentLinked(
                    ComponentLinked {
                        component_type: 'PRIVACY',
                        component_address: component_address,
                        timestamp: get_block_timestamp(),
                    },
                ),
            );
    }

    /// @notice Link HealthComponent to AnimalCoreComponent
    fn _link_health_component<TContractState>(
        ref self: ComponentState<TContractState>,
        component_address: ContractAddress
    ) {
        self.health_component.write(0, component_address);
        
        self
            .emit(
                Event::ComponentLinked(
                    ComponentLinked {
                        component_type: 'HEALTH',
                        component_address: component_address,
                        timestamp: get_block_timestamp(),
                    },
                ),
            );
    }

    /// @notice Link ProcessingComponent to AnimalCoreComponent
    fn _link_processing_component<TContractState>(
        ref self: ComponentState<TContractState>,
        component_address: ContractAddress
    ) {
        self.processing_component.write(0, component_address);
        
        self
            .emit(
                Event::ComponentLinked(
                    ComponentLinked {
                        component_type: 'PROCESSING',
                        component_address: component_address,
                        timestamp: get_block_timestamp(),
                    },
                ),
            );
    }

    /// @notice Link CertificationComponent to AnimalCoreComponent
    fn _link_certification_component<TContractState>(
        ref self: ComponentState<TContractState>,
        component_address: ContractAddress
    ) {
        self.certification_component.write(0, component_address);
        
        self
            .emit(
                Event::ComponentLinked(
                    ComponentLinked {
                        component_type: 'CERTIFICATION',
                        component_address: component_address,
                        timestamp: get_block_timestamp(),
                    },
                ),
            );
    }

    /// @notice Link ExportComponent to AnimalCoreComponent
    fn _link_export_component<TContractState>(
        ref self: ComponentState<TContractState>,
        component_address: ContractAddress
    ) {
        self.export_component.write(0, component_address);
        
        self
            .emit(
                Event::ComponentLinked(
                    ComponentLinked {
                        component_type: 'EXPORT',
                        component_address: component_address,
                        timestamp: get_block_timestamp(),
                    },
                ),
            );
    }

    /// @notice Check if a component is linked
    fn _is_component_linked<TContractState>(
        self: @ComponentState<TContractState>,
        component_key: u32
    ) -> bool {
        let component_addr = match component_key {
            0 => self.access_control_component.read(0),
            1 => self.privacy_component.read(0),
            2 => self.health_component.read(0),
            3 => self.processing_component.read(0),
            4 => self.certification_component.read(0),
            5 => self.export_component.read(0),
            _ => 0.try_into().unwrap(),
        };
        
        let zero_address: ContractAddress = 0.try_into().unwrap();
        component_addr != zero_address
    }
}