/// @title CertificationComponent
/// @notice Tracks certifications for animals, cuts, and batches
/// @dev Stores certification metadata independent of other flows

use core::array::Array;
use starknet::ContractAddress;
use starknet::storage::Map;
use crate::types::animal::CertificationData;

/// @title ICertificationComponent
/// @notice Interface for recording certification documents
#[starknet::interface]
pub trait ICertificationComponent<TContractState> {
    fn certify_animal(
        ref self: TContractState, animal_id: u128, certification_data: CertificationData,
    );

    fn certify_cut(ref self: TContractState, animal_id: u128, cut_id: u128);

    fn certify_batch(
        ref self: TContractState,
        batch_id: u128,
        animal_ids: Array<u128>,
        certification_data: CertificationData,
    );

    fn is_animal_certified(self: @TContractState, animal_id: u128) -> bool;

    fn revoke_certification(ref self: TContractState, animal_id: u128, reason: felt252);

    fn get_certification_data(self: @TContractState, animal_id: u128) -> CertificationData;
}

#[starknet::component]
pub mod CertificationComponent {
    use super::*;

    #[storage]
    pub struct Storage {
        certification_records: Map<u128, CertificationData>,
        certified_animals: Map<u128, bool>,
        certified_cuts: Map<(u128, u128), bool>,
        // TODO: persist revocation reason and history for certifications.
        revocation_reasons: Map<u128, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AnimalCertified: AnimalCertified,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AnimalCertified {
        pub animal_id: u128,
        pub certification_type: felt252,
        pub certifier: ContractAddress,
        pub timestamp: u64,
    }

    #[abi(embed_v0)]
    pub impl CertificationImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::ICertificationComponent<ComponentState<TContractState>> {
        fn certify_animal(
            ref self: ComponentState<TContractState>,
            animal_id: u128,
            certification_data: CertificationData,
        ) {
            self.certification_records.write(animal_id, certification_data);
            self.certified_animals.write(animal_id, true);
            self
                .emit(
                    Event::AnimalCertified(
                        AnimalCertified {
                            animal_id,
                            certification_type: certification_data.certification_type,
                            certifier: certification_data.certifier,
                            timestamp: certification_data.certification_date,
                        },
                    ),
                );
        }

        fn certify_cut(ref self: ComponentState<TContractState>, animal_id: u128, cut_id: u128) {
            self.certified_cuts.write((animal_id, cut_id), true);
            let certification_data = self.certification_records.read(animal_id);
            self
                .emit(
                    Event::AnimalCertified(
                        AnimalCertified {
                            animal_id,
                            certification_type: certification_data.certification_type,
                            certifier: certification_data.certifier,
                            timestamp: certification_data.certification_date,
                        },
                    ),
                );
        }

        fn certify_batch(
            ref self: ComponentState<TContractState>,
            batch_id: u128,
            animal_ids: Array<u128>,
            certification_data: CertificationData,
        ) {
            let _ = batch_id;
            let mut index: u32 = 0;
            while index < animal_ids.len() {
                let animal_id = *animal_ids.at(index);
                self.certification_records.write(animal_id, certification_data);
                self.certified_animals.write(animal_id, true);
                self
                    .emit(
                        Event::AnimalCertified(
                            AnimalCertified {
                                animal_id,
                                certification_type: certification_data.certification_type,
                                certifier: certification_data.certifier,
                                timestamp: certification_data.certification_date,
                            },
                        ),
                    );
                index += 1;
            }
        }

        fn is_animal_certified(self: @ComponentState<TContractState>, animal_id: u128) -> bool {
            self.certified_animals.read(animal_id)
        }

        fn revoke_certification(
            ref self: ComponentState<TContractState>, animal_id: u128, reason: felt252,
        ) {
            // TODO: enforce CERTIFIER_ROLE at contract layer and/or here if we later
            // inject access control into the component.
            self.certified_animals.write(animal_id, false);
            self.revocation_reasons.write(animal_id, reason);
        }

        fn get_certification_data(
            self: @ComponentState<TContractState>, animal_id: u128,
        ) -> CertificationData {
            self.certification_records.read(animal_id)
        }
    }
}
