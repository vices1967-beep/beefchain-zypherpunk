/// @title HealthComponent
/// @notice Manages animal health records, quarantine, and veterinarian authorization
/// @dev Keeps health-specific storage distinct and exposes helpers for the main contract

use starknet::ContractAddress;

/// @title IHealthComponent
/// @notice Trait that encapsulates health operations
#[starknet::interface]
pub trait IHealthComponent<TContractState> {
    fn authorize_veterinarian_for_animal(
        ref self: TContractState, veterinarian: ContractAddress, animal_id: u128,
    );

    fn revoke_veterinarian_authorization(
        ref self: TContractState, veterinarian: ContractAddress, animal_id: u128,
    );

    fn add_health_record(
        ref self: TContractState,
        animal_id: u128,
        diagnosis: felt252,
        treatment: felt252,
        vaccination: felt252,
    );

    fn quarantine_animal(ref self: TContractState, animal_id: u128, reason: felt252);

    fn clear_quarantine(ref self: TContractState, animal_id: u128);

    fn is_quarantined(self: @TContractState, animal_id: u128) -> bool;

    fn is_authorized_veterinarian(
        self: @TContractState, animal_id: u128, veterinarian: ContractAddress,
    ) -> bool;
}

#[starknet::component]
pub mod HealthComponent {
    use starknet::storage::Map;
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

    // ============ STORAGE ============

    #[storage]
    pub struct Storage {
        quarantined_animals: Map<u128, bool>,
        quarantine_reason: Map<u128, felt252>,
        health_records_count: Map<u128, u32>,
        authorized_veterinarians: Map<(u128, ContractAddress), bool>,
    }

    // ============ EVENTS ============

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        VeterinarianAuthorized: VeterinarianAuthorized,
        AnimalQuarantined: AnimalQuarantined,
    }

    #[derive(Drop, starknet::Event)]
    pub struct VeterinarianAuthorized {
        pub animal_id: u128,
        pub veterinarian: ContractAddress,
        pub authorizer: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AnimalQuarantined {
        pub animal_id: u128,
        pub reason: felt252,
        pub vet: ContractAddress,
        pub timestamp: u64,
    }

    // ============ EXTERNAL FUNCTIONS ============

    #[abi(embed_v0)]
    pub impl HealthImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::IHealthComponent<ComponentState<TContractState>> {
        fn authorize_veterinarian_for_animal(
            ref self: ComponentState<TContractState>,
            veterinarian: ContractAddress,
            animal_id: u128,
        ) {
            let caller = get_caller_address();
            self.authorized_veterinarians.write((animal_id, veterinarian), true);
            self
                .emit(
                    Event::VeterinarianAuthorized(
                        VeterinarianAuthorized {
                            animal_id,
                            veterinarian,
                            authorizer: caller,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn revoke_veterinarian_authorization(
            ref self: ComponentState<TContractState>,
            veterinarian: ContractAddress,
            animal_id: u128,
        ) {
            self.authorized_veterinarians.write((animal_id, veterinarian), false);
        }

        fn add_health_record(
            ref self: ComponentState<TContractState>,
            animal_id: u128,
            diagnosis: felt252,
            treatment: felt252,
            vaccination: felt252,
        ) {
            let count = self.health_records_count.read(animal_id);
            self.health_records_count.write(animal_id, count + 1);
            let _ = (diagnosis, treatment, vaccination);
        }

        fn quarantine_animal(
            ref self: ComponentState<TContractState>, animal_id: u128, reason: felt252,
        ) {
            let caller = get_caller_address();
            self.quarantined_animals.write(animal_id, true);
            self.quarantine_reason.write(animal_id, reason);

            self
                .emit(
                    Event::AnimalQuarantined(
                        AnimalQuarantined {
                            animal_id, reason, vet: caller, timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn clear_quarantine(ref self: ComponentState<TContractState>, animal_id: u128) {
            self.quarantined_animals.write(animal_id, false);
            self.quarantine_reason.write(animal_id, 0);
        }

        fn is_quarantined(self: @ComponentState<TContractState>, animal_id: u128) -> bool {
            self.quarantined_animals.read(animal_id)
        }

        fn is_authorized_veterinarian(
            self: @ComponentState<TContractState>, animal_id: u128, veterinarian: ContractAddress,
        ) -> bool {
            self.authorized_veterinarians.read((animal_id, veterinarian))
        }
    }
}
