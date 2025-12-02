use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
/// @title PrivacyComponent
/// @notice Encapsulates privacy mode toggling, ZK identities, and private transfer proofs
/// @dev Separates privacy storage so the main contract can focus on cross-component orchestration

use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
use crate::types::animal::PriceRange;
use crate::types::privacy::{PrivacyDashboard, PrivacyData};

/// @title IPrivacyComponent
/// @notice Trait wrapping the privacy-specific storage helpers
#[starknet::interface]
pub trait IPrivacyComponent<TContractState> {
    fn initialize_privacy_data(ref self: TContractState, animal_id: u128, owner: ContractAddress);

    fn enable_private_mode(ref self: TContractState, animal_id: u128);

    fn disable_private_mode(ref self: TContractState, animal_id: u128);

    fn record_private_transfer(
        ref self: TContractState,
        animal_id: u128,
        to_address: ContractAddress,
        from_zk_hash: felt252,
        to_zk_hash: felt252,
        price_proof: felt252,
        min_price: u128,
        max_price: u128,
    ) -> felt252;

    fn get_privacy_dashboard(self: @TContractState, animal_id: u128) -> PrivacyDashboard;

    fn get_zk_identity(self: @TContractState, account: ContractAddress) -> felt252;

    fn register_zk_identity(ref self: TContractState, zk_hash: felt252);

    fn verify_proof_status(self: @TContractState, proof_hash: felt252) -> (bool, PriceRange);

    fn get_privacy_data(self: @TContractState, animal_id: u128) -> PrivacyData;

    fn resolve_account_from_zk_hash(self: @TContractState, zk_hash: felt252) -> ContractAddress;
}

#[starknet::component]
pub mod PrivacyComponent {
    use super::*;

    #[storage]
    #[allow(starknet::invalid_storage_member_types)]
    pub struct Storage {
        privacy_data: Map<u128, PrivacyData>,
        zk_identities: Map<ContractAddress, felt252>,
        zk_hash_to_account: Map<felt252, ContractAddress>,
        verified_proofs: Map<felt252, bool>,
        proof_min_prices: Map<felt252, u128>,
        proof_max_prices: Map<felt252, u128>,
        total_private_transfers: u128,
        privacy_active_animals: u128,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PrivacyModeEnabled: PrivacyModeEnabled,
        PrivacyModeDisabled: PrivacyModeDisabled,
        PrivateAnimalTransferred: PrivateAnimalTransferred,
        ZKIdentityGenerated: ZKIdentityGenerated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PrivacyModeEnabled {
        pub animal_id: u128,
        pub owner_zk_hash: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PrivacyModeDisabled {
        pub animal_id: u128,
        pub owner_zk_hash: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PrivateAnimalTransferred {
        pub animal_id: u128,
        pub from_zk_hash: felt252,
        pub to_zk_hash: felt252,
        pub price_range: PriceRange,
        pub proof_hash: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ZKIdentityGenerated {
        pub account: ContractAddress,
        pub zk_hash: felt252,
        pub timestamp: u64,
    }

    const PRICE_PROOF_MAGIC: felt252 = 'VALID_PROOF_DEMO';

    #[abi(embed_v0)]
    pub impl PrivacyImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::IPrivacyComponent<ComponentState<TContractState>> {
        fn initialize_privacy_data(
            ref self: ComponentState<TContractState>, animal_id: u128, owner: ContractAddress,
        ) {
            let existing_identity = self.zk_identities.read(owner);
            let identity = if existing_identity != 0 {
                existing_identity
            } else {
                let timestamp = get_block_timestamp();
                let zk_hash = 'ZK_' + owner.into() + '_' + timestamp.into();
                self.zk_identities.write(owner, zk_hash);
                self.zk_hash_to_account.write(zk_hash, owner);
                self
                    .emit(
                        Event::ZKIdentityGenerated(
                            ZKIdentityGenerated { account: owner, zk_hash, timestamp },
                        ),
                    );
                zk_hash
            };

            let privacy_data = PrivacyData {
                current_owner_zk_hash: identity,
                last_transfer_proof: 0,
                is_private_mode: false,
                private_transfer_count: 0,
            };
            self.privacy_data.write(animal_id, privacy_data);
        }

        fn enable_private_mode(ref self: ComponentState<TContractState>, animal_id: u128) {
            let data = self.privacy_data.read(animal_id);
            let updated = PrivacyData { is_private_mode: true, ..data };
            self.privacy_data.write(animal_id, updated);
            self.privacy_active_animals.write(self.privacy_active_animals.read() + 1);
            self
                .emit(
                    Event::PrivacyModeEnabled(
                        PrivacyModeEnabled {
                            animal_id,
                            owner_zk_hash: data.current_owner_zk_hash,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn disable_private_mode(ref self: ComponentState<TContractState>, animal_id: u128) {
            let data = self.privacy_data.read(animal_id);
            let updated = PrivacyData { is_private_mode: false, ..data };
            self.privacy_data.write(animal_id, updated);
            let current = self.privacy_active_animals.read();
            if current > 0 {
                self.privacy_active_animals.write(current - 1);
            }
            self
                .emit(
                    Event::PrivacyModeDisabled(
                        PrivacyModeDisabled {
                            animal_id,
                            owner_zk_hash: data.current_owner_zk_hash,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn record_private_transfer(
            ref self: ComponentState<TContractState>,
            animal_id: u128,
            to_address: ContractAddress,
            from_zk_hash: felt252,
            to_zk_hash: felt252,
            price_proof: felt252,
            min_price: u128,
            max_price: u128,
        ) -> felt252 {
            assert!(price_proof == PRICE_PROOF_MAGIC, "Invalid private price proof");

            self.proof_min_prices.write(price_proof, min_price);
            self.proof_max_prices.write(price_proof, max_price);
            self.verified_proofs.write(price_proof, true);
            self.zk_hash_to_account.write(to_zk_hash, to_address);

            let data = self.privacy_data.read(animal_id);
            let updated = PrivacyData {
                current_owner_zk_hash: to_zk_hash,
                last_transfer_proof: price_proof,
                is_private_mode: data.is_private_mode,
                private_transfer_count: data.private_transfer_count + 1,
            };
            self.privacy_data.write(animal_id, updated);

            let current_transfers = self.total_private_transfers.read();
            self.total_private_transfers.write(current_transfers + 1);

            let timestamp = get_block_timestamp();
            let proof_hash = 'TRANSFER_PROOF_'
                + animal_id.into()
                + '_'
                + to_zk_hash
                + '_'
                + price_proof
                + '_'
                + timestamp.into();

            let price_range = PriceRange { min_price, max_price };

            self
                .emit(
                    Event::PrivateAnimalTransferred(
                        PrivateAnimalTransferred {
                            animal_id, from_zk_hash, to_zk_hash, price_range, proof_hash, timestamp,
                        },
                    ),
                );

            proof_hash
        }

        fn get_privacy_dashboard(
            self: @ComponentState<TContractState>, animal_id: u128,
        ) -> PrivacyDashboard {
            let data = self.privacy_data.read(animal_id);
            let mut score: u8 = 0;
            if data.is_private_mode {
                score += 50;
            }
            if data.private_transfer_count > 0 {
                score += 25;
            }
            if data.last_transfer_proof != 0 {
                score += 25;
            }
            PrivacyDashboard {
                animal_id,
                is_private_mode: data.is_private_mode,
                total_private_transfers: data.private_transfer_count,
                last_proof_hash: data.last_transfer_proof,
                privacy_score: score,
            }
        }

        fn get_zk_identity(
            self: @ComponentState<TContractState>, account: ContractAddress,
        ) -> felt252 {
            let identity = self.zk_identities.read(account);
            if identity != 0 {
                identity
            } else {
                let fallback = 'AUTO_ZK_' + account.into();
                fallback
            }
        }

        fn register_zk_identity(ref self: ComponentState<TContractState>, zk_hash: felt252) {
            let caller = get_caller_address();
            self.zk_identities.write(caller, zk_hash);
            self.zk_hash_to_account.write(zk_hash, caller);

            self
                .emit(
                    Event::ZKIdentityGenerated(
                        ZKIdentityGenerated {
                            account: caller, zk_hash, timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn verify_proof_status(
            self: @ComponentState<TContractState>, proof_hash: felt252,
        ) -> (bool, PriceRange) {
            let is_verified = self.verified_proofs.read(proof_hash);
            let min_price = self.proof_min_prices.read(proof_hash);
            let max_price = self.proof_max_prices.read(proof_hash);
            (is_verified, PriceRange { min_price, max_price })
        }

        fn get_privacy_data(self: @ComponentState<TContractState>, animal_id: u128) -> PrivacyData {
            self.privacy_data.read(animal_id)
        }

        fn resolve_account_from_zk_hash(
            self: @ComponentState<TContractState>, zk_hash: felt252,
        ) -> ContractAddress {
            self.zk_hash_to_account.read(zk_hash)
        }
    }
}
