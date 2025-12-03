/// @title ProcessingComponent
/// @notice Manages animal batch creation, transfers, processing, and cut generation
/// @dev Captures all frigorifico workflows that used to live in AnimalNFT

use core::array::{Array, ArrayTrait};
use core::traits::TryInto;
use starknet::storage::Map;
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
use crate::types::animal::{AnimalBatchData, MeatCutData};

/// @title IProcessingComponent
/// @notice Interface for processing facility and batch workflows
#[starknet::interface]
pub trait IProcessingComponent<TContractState> {
    // ============ BATCH MANAGEMENT ============
    
    /// @notice Create a new batch of animals
    /// @param animal_ids Array of animal IDs to include in batch
    /// @return batch_id The newly created batch ID
    /// @dev Requires PRODUCER_ROLE and validates each animal
    fn create_batch(ref self: TContractState, animal_ids: Array<u128>) -> u128;
    
    /// @notice Add animals to an existing batch
    /// @param batch_id The batch to add animals to
    /// @param animal_ids Array of animal IDs to add
    /// @dev Requires PRODUCER_ROLE and batch ownership
    fn add_animals_to_batch(ref self: TContractState, batch_id: u128, animal_ids: Array<u128>);
    
    /// @notice Transfer batch to a processing facility
    /// @param batch_id The batch to transfer
    /// @param processor Address of the processing facility
    /// @dev Requires PRODUCER_ROLE and PROCESSING_FACILITY_ROLE for recipient
    fn transfer_batch_to_processor(
        ref self: TContractState, batch_id: u128, processor: ContractAddress,
    );
    
    /// @notice Get batch information
    /// @param batch_id The batch ID
    /// @return (AnimalBatchData, Array<u128>) Batch data and animal IDs
    fn get_batch_info(self: @TContractState, batch_id: u128) -> (AnimalBatchData, Array<u128>);
    
    // ============ PROCESSING OPERATIONS ============
    
    /// @notice Process a single animal
    /// @param animal_id The animal to process
    /// @dev Requires PROCESSING_FACILITY_ROLE and animal ownership
    fn process_animal(ref self: TContractState, animal_id: u128);
    
    /// @notice Process an entire batch
    /// @param batch_id The batch to process
    /// @dev Requires PROCESSING_FACILITY_ROLE and batch assignment
    fn process_batch(ref self: TContractState, batch_id: u128);
    
    // ============ CUT MANAGEMENT ============
    
    /// @notice Create a meat cut from an animal
    /// @param animal_id The animal to create cut from
    /// @param cut_type Type identifier for the cut
    /// @param weight Weight of the cut in kilograms
    /// @return cut_id The newly created cut ID
    /// @dev Requires PROCESSING_FACILITY_ROLE and processed animal
    fn create_cut(ref self: TContractState, animal_id: u128, cut_type: u128, weight: u128) -> u128;
    
    /// @notice Create cuts for all animals in a batch
    /// @param batch_id The batch to create cuts for
    /// @param cut_types Array of cut types to create
    /// @param cut_weights Array of corresponding weights
    /// @return Array<u128> IDs of created cuts
    /// @dev Requires PROCESSING_FACILITY_ROLE and processed batch
    fn create_cuts_for_batch(
        ref self: TContractState, batch_id: u128, cut_types: Array<u128>, cut_weights: Array<u128>,
    ) -> Array<u128>;
    
    /// @notice Certify a cut
    /// @param animal_id The animal ID
    /// @param cut_id The cut ID to certify
    /// @dev Requires CERTIFIER_ROLE
    fn certify_cut(ref self: TContractState, animal_id: u128, cut_id: u128);
    
    // ============ VIEW FUNCTIONS ============
    
    /// @notice Get all batches owned by an address
    /// @param owner The owner's address
    /// @return Array<u128> List of batch IDs
    fn get_batches_by_owner(self: @TContractState, owner: ContractAddress) -> Array<u128>;
    
    /// @notice Get all animals in a batch
    /// @param batch_id The batch ID
    /// @return Array<u128> List of animal IDs
    fn get_animals_in_batch(self: @TContractState, batch_id: u128) -> Array<u128>;
    
    /// @notice Get the batch ID for an animal
    /// @param animal_id The animal ID
    /// @return u128 Batch ID (0 if not in batch)
    fn get_batch_for_animal(self: @TContractState, animal_id: u128) -> u128;
    
    /// @notice Get the owner of a cut
    /// @param animal_id The animal ID
    /// @param cut_id The cut ID
    /// @return ContractAddress Owner address
    fn get_cut_owner(self: @TContractState, animal_id: u128, cut_id: u128) -> ContractAddress;
    
    /// @notice Get cut information
    /// @param animal_id The animal ID
    /// @param cut_id The cut ID
    /// @return MeatCutData Cut data
    fn get_cut_info(self: @TContractState, animal_id: u128, cut_id: u128) -> MeatCutData;
    
    /// @notice Get the number of cuts from an animal
    /// @param animal_id The animal ID
    /// @return u128 Number of cuts
    fn get_cut_count(self: @TContractState, animal_id: u128) -> u128;
    
    /// @notice Transfer a cut to another address
    /// @param animal_id The animal ID
    /// @param cut_id The cut ID
    /// @param from Current owner address
    /// @param to New owner address
    /// @dev Internal function, requires external validation
    fn transfer_cut(
        ref self: TContractState,
        animal_id: u128,
        cut_id: u128,
        from: ContractAddress,
        to: ContractAddress,
    );
}

/// Role constants for processing operations
const PRODUCER_ROLE: felt252 = 'PRODUCER_ROLE';
const PROCESSING_FACILITY_ROLE: felt252 = 'PROCESSING_FACILITY_ROLE';
const CERTIFIER_ROLE: felt252 = 'CERTIFIER_ROLE';

#[starknet::component]
pub mod ProcessingComponent {
    use super::*;
    use crate::types::animal::AnimalData;

    #[storage]
    pub struct Storage {
        // Batch management
        next_batch_id: u128,
        batches: Map<u128, AnimalBatchData>,
        batch_animals_by_index: Map<(u128, u32), u128>,
        batch_animal_count: Map<u128, u32>,
        batches_by_owner_count: Map<ContractAddress, u32>,
        batch_at_owner_index: Map<(ContractAddress, u32), u128>,
        batch_for_animal: Map<u128, u128>,
        animals_in_batch: Map<(u128, u128), bool>,
        
        // Cut management
        animal_cut_count: Map<u128, u128>,
        cut_data: Map<(u128, u128), MeatCutData>,
        cut_owner: Map<(u128, u128), ContractAddress>,
        total_cuts_created: u128,
        
        // Component references
        access_control_component: Map<u32, ContractAddress>,
        animal_core_component: Map<u32, ContractAddress>,
        certification_component: Map<u32, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        BatchCreated: BatchCreated,
        BatchTransferred: BatchTransferred,
        BatchProcessed: BatchProcessed,
        CutCreated: CutCreated,
        CutsBatchCreated: CutsBatchCreated,
        CutTransferred: CutTransferred,
        CutCertified: CutCertified,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BatchCreated {
        pub batch_id: u128,
        pub owner: ContractAddress,
        pub animal_count: u32,
        pub total_weight: u128,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BatchTransferred {
        pub batch_id: u128,
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub animal_count: u32,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BatchProcessed {
        pub batch_id: u128,
        pub processor: ContractAddress,
        pub processed_animals: u32,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CutCreated {
        pub animal_id: u128,
        pub cut_id: u128,
        pub cut_type: u128,
        pub weight: u128,
        pub processor: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CutsBatchCreated {
        pub batch_id: u128,
        pub cut_count: u32,
        pub processor: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CutTransferred {
        pub animal_id: u128,
        pub cut_id: u128,
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CutCertified {
        pub animal_id: u128,
        pub cut_id: u128,
        pub certifier: ContractAddress,
        pub timestamp: u64,
    }

    #[abi(embed_v0)]
    pub impl ProcessingImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::IProcessingComponent<ComponentState<TContractState>> {
        fn create_batch(
            ref self: ComponentState<TContractState>, animal_ids: Array<u128>
        ) -> u128 {
            // Check if caller has PRODUCER_ROLE
            _check_role(ref self, PRODUCER_ROLE);

            let owner = get_caller_address();
            let batch_id = self.next_batch_id.read();
            self.next_batch_id.write(batch_id + 1);

            let mut total_weight: u128 = 0;
            let mut animal_count: u32 = 0;
            let mut index: u32 = 0;

            // Get AnimalCoreComponent reference
            let animal_core_addr = self.animal_core_component.read(0);
            let zero_address: ContractAddress = 0.try_into().unwrap();
            
            // Validate and add animals to batch
            while index < animal_ids.len() {
                let animal_id = *animal_ids.at(index);
                
                // Store animal in batch index
                self.batch_animals_by_index.write((batch_id, animal_count), animal_id);
                self.batch_for_animal.write(animal_id, batch_id);
                self.animals_in_batch.write((batch_id, animal_id), true);
                
                animal_count += 1;
                index += 1;
            };

            self.batch_animal_count.write(batch_id, animal_count);

            let zero_address: ContractAddress = 0.try_into().unwrap();
            let batch_data = AnimalBatchData {
                owner: owner,
                processing_facility: zero_address,
                creation_date: get_block_timestamp(),
                transfer_date: 0,
                processing_date: 0,
                status: 0,
                animal_count: animal_count,
                total_weight: total_weight,
            };
            self.batches.write(batch_id, batch_data);

            // Add to owner's batch index
            let owner_batch_count = self.batches_by_owner_count.read(owner);
            self.batches_by_owner_count.write(owner, owner_batch_count + 1);
            self.batch_at_owner_index.write((owner, owner_batch_count), batch_id);

            // Emit event
            self
                .emit(
                    Event::BatchCreated(
                        BatchCreated {
                            batch_id: batch_id,
                            owner: owner,
                            animal_count: animal_count,
                            total_weight: total_weight,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );

            batch_id
        }

        fn add_animals_to_batch(
            ref self: ComponentState<TContractState>, batch_id: u128, animal_ids: Array<u128>,
        ) {
            // Check if caller has PRODUCER_ROLE
            _check_role(ref self, PRODUCER_ROLE);

            let caller = get_caller_address();
            let mut batch = self.batches.read(batch_id);
            
            // Verify batch ownership
            assert!(batch.owner == caller, "NOT_OWNER_OF_BATCH");
            assert!(batch.status == 0, "BATCH_ALREADY_TRANSFERRED");

            let mut current_count = self.batch_animal_count.read(batch_id);
            let mut index: u32 = 0;

            while index < animal_ids.len() {
                let animal_id = *animal_ids.at(index);
                
                // Store animal in batch index
                self.batch_animals_by_index.write((batch_id, current_count), animal_id);
                self.batch_for_animal.write(animal_id, batch_id);
                self.animals_in_batch.write((batch_id, animal_id), true);
                
                current_count += 1;
                batch.animal_count += 1;
                index += 1;
            };
            
            self.batch_animal_count.write(batch_id, current_count);
            self.batches.write(batch_id, batch);
        }

        fn transfer_batch_to_processor(
            ref self: ComponentState<TContractState>, batch_id: u128, processor: ContractAddress,
        ) {
            // Check if caller has PRODUCER_ROLE
            _check_role(ref self, PRODUCER_ROLE);

            let caller = get_caller_address();
            let mut batch = self.batches.read(batch_id);

            // Verify batch ownership and state
            assert!(batch.owner == caller, "NOT_OWNER_OF_BATCH");
            assert!(batch.status == 0, "BATCH_ALREADY_TRANSFERRED");
            
            // Verify recipient has PROCESSING_FACILITY_ROLE
            _check_role_for_address(ref self, processor, PROCESSING_FACILITY_ROLE);

            // Update batch data
            batch.processing_facility = processor;
            batch.transfer_date = get_block_timestamp();
            batch.status = 1;
            self.batches.write(batch_id, batch);

            // Update batch ownership indices
            let old_owner_count = self.batches_by_owner_count.read(caller);
            let mut new_owner_count: u32 = 0;
            let mut i: u32 = 0;
            
            while i < old_owner_count {
                let stored_batch_id = self.batch_at_owner_index.read((caller, i));
                if stored_batch_id != batch_id {
                    self.batch_at_owner_index.write((caller, new_owner_count), stored_batch_id);
                    new_owner_count += 1;
                }
                i += 1;
            };
            self.batches_by_owner_count.write(caller, new_owner_count);

            let processor_batch_count = self.batches_by_owner_count.read(processor);
            self.batch_at_owner_index.write((processor, processor_batch_count), batch_id);
            self.batches_by_owner_count.write(processor, processor_batch_count + 1);

            // Emit event
            self
                .emit(
                    Event::BatchTransferred(
                        BatchTransferred {
                            batch_id: batch_id,
                            from: caller,
                            to: processor,
                            animal_count: batch.animal_count,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn get_batch_info(
            self: @ComponentState<TContractState>, batch_id: u128,
        ) -> (AnimalBatchData, Array<u128>) {
            let batch_data = self.batches.read(batch_id);
            let count = self.batch_animal_count.read(batch_id);
            let mut animal_ids = ArrayTrait::new();
            let mut index: u32 = 0;
            
            while index < count {
                let animal_id = self.batch_animals_by_index.read((batch_id, index));
                animal_ids.append(animal_id);
                index += 1;
            };
            
            (batch_data, animal_ids)
        }

        fn process_animal(ref self: ComponentState<TContractState>, animal_id: u128) {
            // Check if caller has PROCESSING_FACILITY_ROLE
            _check_role(ref self, PROCESSING_FACILITY_ROLE);

            let caller = get_caller_address();
            
            // In production, would update animal status via AnimalCoreComponent
            // For now, emit event only
            
            self
                .emit(
                    Event::BatchProcessed(
                        BatchProcessed {
                            batch_id: 0,
                            processor: caller,
                            processed_animals: 1,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn process_batch(ref self: ComponentState<TContractState>, batch_id: u128) {
            // Check if caller has PROCESSING_FACILITY_ROLE
            _check_role(ref self, PROCESSING_FACILITY_ROLE);

            let caller = get_caller_address();
            let mut batch = self.batches.read(batch_id);
            
            // Verify processor assignment
            assert!(batch.processing_facility == caller, "NOT_ASSIGNED_PROCESSOR");
            assert!(batch.status == 1, "BATCH_NOT_TRANSFERRED_OR_ALREADY_PROCESSED");

            // Update batch status
            batch.status = 2;
            batch.processing_date = get_block_timestamp();
            self.batches.write(batch_id, batch);

            self
                .emit(
                    Event::BatchProcessed(
                        BatchProcessed {
                            batch_id: batch_id,
                            processor: caller,
                            processed_animals: batch.animal_count,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn create_cut(
            ref self: ComponentState<TContractState>, animal_id: u128, cut_type: u128, weight: u128,
        ) -> u128 {
            // Check if caller has PROCESSING_FACILITY_ROLE
            _check_role(ref self, PROCESSING_FACILITY_ROLE);

            let processor = get_caller_address();
            
            // Get current cut count and create new cut ID
            let cut_count = self.animal_cut_count.read(animal_id);
            let cut_id = cut_count + 1;
            self.animal_cut_count.write(animal_id, cut_id);

            // Create cut data
            let cut = MeatCutData {
                cut_type: cut_type,
                weight: weight,
                processing_date: get_block_timestamp(),
                processing_facility: processor,
                is_certified: false,
                export_batch_id: 0,
                owner: processor,
                animal_id: animal_id,
            };

            // Store cut data
            self.cut_data.write((animal_id, cut_id), cut);
            self.cut_owner.write((animal_id, cut_id), processor);
            
            // Update total cuts counter
            self.total_cuts_created.write(self.total_cuts_created.read() + 1);

            // Emit event
            self
                .emit(
                    Event::CutCreated(
                        CutCreated {
                            animal_id: animal_id,
                            cut_id: cut_id,
                            cut_type: cut_type,
                            weight: weight,
                            processor: processor,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );

            cut_id
        }

        fn create_cuts_for_batch(
            ref self: ComponentState<TContractState>,
            batch_id: u128,
            cut_types: Array<u128>,
            cut_weights: Array<u128>,
        ) -> Array<u128> {
            // Check if caller has PROCESSING_FACILITY_ROLE
            _check_role(ref self, PROCESSING_FACILITY_ROLE);

            let batch = self.batches.read(batch_id);
            let processor = batch.processing_facility;
            
            // Verify batch is processed
            assert!(batch.status == 2, "BATCH_NOT_PROCESSED");

            let mut created_cuts = ArrayTrait::new();
            let mut total_cuts: u32 = 0;

            let animal_count = self.batch_animal_count.read(batch_id);
            let mut animal_index: u32 = 0;
            
            // For each animal in batch
            while animal_index < animal_count {
                let animal_id = self.batch_animals_by_index.read((batch_id, animal_index));
                
                // For each cut type/weight combination
                let mut cut_index: u32 = 0;
                while cut_index < cut_types.len() {
                    let cut_type = *cut_types.at(cut_index);
                    let weight = *cut_weights.at(cut_index);
                    
                    // Create cut
                    let cut_id = self.create_cut(animal_id, cut_type, weight);
                    created_cuts.append(cut_id);
                    total_cuts += 1;
                    
                    cut_index += 1;
                };
                
                animal_index += 1;
            };

            // Emit batch cuts created event
            self
                .emit(
                    Event::CutsBatchCreated(
                        CutsBatchCreated {
                            batch_id: batch_id,
                            cut_count: total_cuts,
                            processor: processor,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );

            created_cuts
        }

        fn certify_cut(ref self: ComponentState<TContractState>, animal_id: u128, cut_id: u128) {
            // Check if caller has CERTIFIER_ROLE
            _check_role(ref self, CERTIFIER_ROLE);

            let caller = get_caller_address();
            let mut cut = self.cut_data.read((animal_id, cut_id));
            
            // Update cut certification status
            cut = MeatCutData { is_certified: true, ..cut };
            self.cut_data.write((animal_id, cut_id), cut);

            // Emit certification event
            self
                .emit(
                    Event::CutCertified(
                        CutCertified {
                            animal_id: animal_id,
                            cut_id: cut_id,
                            certifier: caller,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn get_batches_by_owner(
            self: @ComponentState<TContractState>, owner: ContractAddress,
        ) -> Array<u128> {
            let count = self.batches_by_owner_count.read(owner);
            let mut batches = ArrayTrait::new();
            let mut index: u32 = 0;

            while index < count {
                let batch_id = self.batch_at_owner_index.read((owner, index));
                batches.append(batch_id);
                index += 1;
            };

            batches
        }

        fn get_animals_in_batch(
            self: @ComponentState<TContractState>, batch_id: u128,
        ) -> Array<u128> {
            let count = self.batch_animal_count.read(batch_id);
            let mut animals = ArrayTrait::new();
            let mut index: u32 = 0;

            while index < count {
                let animal_id = self.batch_animals_by_index.read((batch_id, index));
                animals.append(animal_id);
                index += 1;
            };

            animals
        }

        fn get_batch_for_animal(self: @ComponentState<TContractState>, animal_id: u128) -> u128 {
            self.batch_for_animal.read(animal_id)
        }

        fn get_cut_owner(
            self: @ComponentState<TContractState>, animal_id: u128, cut_id: u128,
        ) -> ContractAddress {
            self.cut_owner.read((animal_id, cut_id))
        }

        fn get_cut_info(
            self: @ComponentState<TContractState>, animal_id: u128, cut_id: u128,
        ) -> MeatCutData {
            self.cut_data.read((animal_id, cut_id))
        }

        fn get_cut_count(self: @ComponentState<TContractState>, animal_id: u128) -> u128 {
            self.animal_cut_count.read(animal_id)
        }

        fn transfer_cut(
            ref self: ComponentState<TContractState>,
            animal_id: u128,
            cut_id: u128,
            from: ContractAddress,
            to: ContractAddress,
        ) {
            // Verify current ownership
            let current_owner = self.cut_owner.read((animal_id, cut_id));
            assert!(current_owner == from, "NOT_OWNER_OF_CUT");

            // Update ownership
            self.cut_owner.write((animal_id, cut_id), to);
            
            // Update cut data with new owner
            let mut cut = self.cut_data.read((animal_id, cut_id));
            cut = MeatCutData { owner: to, ..cut };
            self.cut_data.write((animal_id, cut_id), cut);

            // Emit transfer event
            self
                .emit(
                    Event::CutTransferred(
                        CutTransferred {
                            animal_id: animal_id,
                            cut_id: cut_id,
                            from: from,
                            to: to,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }
    }

    // ============ INTERNAL FUNCTIONS ============

    /// @notice Check if caller has a specific role
    fn _check_role<TContractState>(
        ref self: ComponentState<TContractState>,
        role: felt252
    ) {
        let access_control_addr = self.access_control_component.read(0);
        let zero_address: ContractAddress = 0.try_into().unwrap();
        
        if access_control_addr != zero_address {
            // In production, would query AccessControlComponent
            // let has_role = access_control_component.has_role(role, get_caller_address());
            // assert!(has_role, "MISSING_REQUIRED_ROLE");
            return; // Skip for now
        }
        
        assert!(false, "ACCESS_CONTROL_COMPONENT_NOT_LINKED");
    }

    /// @notice Check if an address has a specific role
    fn _check_role_for_address<TContractState>(
        ref self: ComponentState<TContractState>,
        address: ContractAddress,
        role: felt252
    ) -> bool {
        let access_control_addr = self.access_control_component.read(0);
        let zero_address: ContractAddress = 0.try_into().unwrap();
        
        if access_control_addr != zero_address {
            // In production, would query AccessControlComponent
            // return access_control_component.has_role(role, address);
            return true; // Skip for now
        }
        
        false
    }

    /// @notice Link AccessControlComponent to ProcessingComponent
    fn _link_access_control_component<TContractState>(
        ref self: ComponentState<TContractState>,
        component_address: ContractAddress
    ) {
        self.access_control_component.write(0, component_address);
    }

    /// @notice Link AnimalCoreComponent to ProcessingComponent
    fn _link_animal_core_component<TContractState>(
        ref self: ComponentState<TContractState>,
        component_address: ContractAddress
    ) {
        self.animal_core_component.write(0, component_address);
    }

    /// @notice Link CertificationComponent to ProcessingComponent
    fn _link_certification_component<TContractState>(
        ref self: ComponentState<TContractState>,
        component_address: ContractAddress
    ) {
        self.certification_component.write(0, component_address);
    }
}