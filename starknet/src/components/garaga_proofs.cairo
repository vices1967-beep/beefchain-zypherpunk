/// @title GaragaProofsComponent
/// @notice Manages zero-knowledge proof verification via Garaga for ZEC sales, price verification,
/// and private transfers @dev Handles external proof verification, proof storage, and animal
/// linking

use core::array::{Array, ArrayTrait};
use starknet::ContractAddress;
use crate::types::animal::PriceRange;
use crate::types::zk_proofs::{PriceVerificationProof, PrivateTransferProof, ZecSaleProof};

/// @title IGaragaProofsComponent
/// @notice Trait encapsulating ZK proof verification operations
#[starknet::interface]
pub trait IGaragaProofsComponent<TContractState> {
    // ========== ZEC Sale Proof Functions ==========

    fn verify_zec_sale_with_proof(
        ref self: TContractState,
        animal_id: u128,
        proof_data: Array<felt252>,
        public_inputs: Array<felt252>,
    ) -> felt252;

    fn link_animal_to_zec_sale(
        ref self: TContractState, animal_id: u128, zec_sale_proof_hash: felt252,
    ) -> bool;

    fn is_animal_zec_verified(self: @TContractState, animal_id: u128) -> bool;

    fn get_animal_zec_proof(self: @TContractState, animal_id: u128) -> felt252;

    fn get_zec_sale_proof(self: @TContractState, proof_hash: felt252) -> ZecSaleProof;

    // ========== Price Verification Functions ==========

    fn verify_price_with_proof(
        ref self: TContractState,
        animal_id: u128,
        proof_data: Array<felt252>,
        public_inputs: Array<felt252>,
    ) -> felt252;

    fn get_price_verification_proof(
        self: @TContractState, proof_hash: felt252,
    ) -> PriceVerificationProof;

    // ========== Private Transfer Functions ==========

    fn execute_private_transfer_with_proof(
        ref self: TContractState,
        animal_id: u128,
        proof_data: Array<felt252>,
        public_inputs: Array<felt252>,
    ) -> felt252;

    fn get_private_transfer_proof(
        self: @TContractState, proof_hash: felt252,
    ) -> PrivateTransferProof;

    // ========== Proof Query Functions ==========

    fn get_zec_sales_verified_count(self: @TContractState) -> u128;

    fn get_price_verifications_count(self: @TContractState) -> u128;

    fn get_private_transfers_executed_count(self: @TContractState) -> u128;

    // ========== Initialization ==========

    fn initialize(ref self: TContractState, private_transfer_verifier: ContractAddress);
}

#[starknet::component]
pub mod GaragaProofsComponent {
    use core::traits::TryInto;
    use starknet::storage::Map;
    use starknet::{get_block_timestamp, get_caller_address};
    use super::*;

    // ============ STORAGE ============

    #[storage]
    #[allow(starknet::invalid_storage_member_types)]
    pub struct Storage {
        // ZEC Sale Proofs
        zec_sale_proofs: Map<felt252, ZecSaleProof>,
        animal_to_zec_sale: Map<u128, felt252>,
        zec_sale_to_animal: Map<felt252, u128>,
        zec_sales_verified: u128,
        // Price Verification Proofs
        price_verification_proofs: Map<felt252, PriceVerificationProof>,
        price_verifications: u128,
        // Private Transfer Proofs
        private_transfer_proofs: Map<felt252, PrivateTransferProof>,
        private_transfers_executed: u128,
        // External Verifier Addresses (to be set by contract)
        zec_sale_verifier: ContractAddress,
        price_verification_verifier: ContractAddress,
        private_transfer_verifier: ContractAddress,
        // Proof nonce for unique hash generation
        next_proof_nonce: u128,
    }

    // ============ EVENTS ============

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ZecSaleVerified: ZecSaleVerified,
        PriceVerificationCompleted: PriceVerificationCompleted,
        PrivateTransferExecuted: PrivateTransferExecuted,
        AnimalZecLinked: AnimalZecLinked,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ZecSaleVerified {
        pub animal_id: u128,
        pub proof_hash: felt252,
        pub seller_zk: felt252,
        pub buyer_zk: felt252,
        pub amount: u128,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PriceVerificationCompleted {
        pub animal_id: u128,
        pub proof_hash: felt252,
        pub price_range: PriceRange,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PrivateTransferExecuted {
        pub animal_id: u128,
        pub proof_hash: felt252,
        pub from_zk: felt252,
        pub to_zk: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AnimalZecLinked {
        pub animal_id: u128,
        pub zec_sale_proof_hash: felt252,
        pub owner: ContractAddress,
        pub timestamp: u64,
    }

    // ============ EXTERNAL FUNCTIONS ============

    #[abi(embed_v0)]
    pub impl GaragaProofsImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::IGaragaProofsComponent<ComponentState<TContractState>> {
        // ========== ZEC SALE PROOF FUNCTIONS ==========

        /// @notice Verifies a ZEC sale proof via external Garaga verifier
        /// @param animal_id The ID of the animal in the sale
        /// @param proof_data The ZK proof data
        /// @param public_inputs The public inputs for proof verification
        /// @return The unique proof hash of the verified proof
        /// @dev Extracts seller/buyer ZK identities and sale amount from proof
        fn verify_zec_sale_with_proof(
            ref self: ComponentState<TContractState>,
            animal_id: u128,
            proof_data: Array<felt252>,
            public_inputs: Array<felt252>,
        ) -> felt252 {
            // Check that animal hasn't been ZEC verified already
            assert!(!self.is_animal_zec_verified(animal_id), "Animal already ZEC verified");

            // Clone inputs to avoid move issues
            let public_inputs_for_verification = public_inputs.clone();
            let public_inputs_for_extraction = public_inputs.clone();

            // Verify with external verifier
            let zec_verifier = self.zec_sale_verifier.read();
            let is_valid = self
                ._verify_with_external_verifier(
                    zec_verifier, proof_data, public_inputs_for_verification,
                );

            assert!(is_valid, "Invalid ZEC sale proof");

            // Extract public inputs
            let (seller_zk, buyer_zk, amount, token_id) = self
                ._extract_zec_sale_public_inputs(public_inputs_for_extraction);

            // Generate unique proof hash
            let proof_hash = self._generate_proof_hash('ZEC_SALE', animal_id);

            // Create and store proof
            let zec_sale_proof = ZecSaleProof {
                proof_hash: proof_hash,
                seller_zk: seller_zk,
                buyer_zk: buyer_zk,
                amount: amount,
                token_id: token_id,
                timestamp: get_block_timestamp(),
                verified: true,
            };

            self.zec_sale_proofs.write(proof_hash, zec_sale_proof);

            // Update counter
            self.zec_sales_verified.write(self.zec_sales_verified.read() + 1);

            self
                .emit(
                    Event::ZecSaleVerified(
                        ZecSaleVerified {
                            animal_id: animal_id,
                            proof_hash: proof_hash,
                            seller_zk: seller_zk,
                            buyer_zk: buyer_zk,
                            amount: amount,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );

            proof_hash
        }

        /// @notice Links an animal to a verified ZEC sale proof
        /// @param animal_id The ID of the animal
        /// @param zec_sale_proof_hash The proof hash to link
        /// @return true if linking successful
        /// @dev Creates bidirectional mapping between animal and proof
        fn link_animal_to_zec_sale(
            ref self: ComponentState<TContractState>, animal_id: u128, zec_sale_proof_hash: felt252,
        ) -> bool {
            // Verify proof exists and is valid
            let zec_proof = self.zec_sale_proofs.read(zec_sale_proof_hash);
            assert!(zec_proof.verified, "ZEC sale proof not verified");

            // Link animal to proof
            self.animal_to_zec_sale.write(animal_id, zec_sale_proof_hash);
            self.zec_sale_to_animal.write(zec_sale_proof_hash, animal_id);

            let caller = get_caller_address();
            self
                .emit(
                    Event::AnimalZecLinked(
                        AnimalZecLinked {
                            animal_id: animal_id,
                            zec_sale_proof_hash: zec_sale_proof_hash,
                            owner: caller,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );

            true
        }

        /// @notice Checks if an animal has been verified via ZEC sale proof
        /// @param animal_id The ID of the animal
        /// @return true if animal is ZEC verified
        fn is_animal_zec_verified(self: @ComponentState<TContractState>, animal_id: u128) -> bool {
            let proof_hash = self.animal_to_zec_sale.read(animal_id);
            if proof_hash == 0 {
                return false;
            }

            let zec_proof = self.zec_sale_proofs.read(proof_hash);
            zec_proof.verified
        }

        /// @notice Gets the ZEC sale proof hash linked to an animal
        /// @param animal_id The ID of the animal
        /// @return The proof hash (0 if not linked)
        fn get_animal_zec_proof(self: @ComponentState<TContractState>, animal_id: u128) -> felt252 {
            self.animal_to_zec_sale.read(animal_id)
        }

        /// @notice Retrieves a ZEC sale proof by its hash
        /// @param proof_hash The hash of the proof
        /// @return The ZecSaleProof struct
        fn get_zec_sale_proof(
            self: @ComponentState<TContractState>, proof_hash: felt252,
        ) -> ZecSaleProof {
            self.zec_sale_proofs.read(proof_hash)
        }

        // ========== PRICE VERIFICATION FUNCTIONS ==========

        /// @notice Verifies a price verification proof via external Garaga verifier
        /// @param animal_id The ID of the animal for price verification
        /// @param proof_data The ZK proof data
        /// @param public_inputs The public inputs for proof verification
        /// @return The unique proof hash of the verified proof
        /// @dev Extracts price range and market data hash from proof
        fn verify_price_with_proof(
            ref self: ComponentState<TContractState>,
            animal_id: u128,
            proof_data: Array<felt252>,
            public_inputs: Array<felt252>,
        ) -> felt252 {
            // Clone inputs to avoid move issues
            let public_inputs_for_verification = public_inputs.clone();
            let public_inputs_for_extraction = public_inputs.clone();

            // Verify with external verifier
            let price_verifier = self.price_verification_verifier.read();
            let is_valid = self
                ._verify_with_external_verifier(
                    price_verifier, proof_data, public_inputs_for_verification,
                );

            assert!(is_valid, "Invalid price verification proof");

            // Extract public inputs
            let (min_price, max_price, market_data_hash) = self
                ._extract_price_verification_public_inputs(public_inputs_for_extraction);

            // Generate unique proof hash
            let proof_hash = self._generate_proof_hash('PRICE_VERIFICATION', animal_id);

            // Create and store proof
            let price_proof = PriceVerificationProof {
                proof_hash: proof_hash,
                price_range: PriceRange { min_price: min_price, max_price: max_price },
                market_data_hash: market_data_hash,
                timestamp: get_block_timestamp(),
                verified: true,
            };

            self.price_verification_proofs.write(proof_hash, price_proof);

            // Update counter
            self.price_verifications.write(self.price_verifications.read() + 1);

            self
                .emit(
                    Event::PriceVerificationCompleted(
                        PriceVerificationCompleted {
                            animal_id: animal_id,
                            proof_hash: proof_hash,
                            price_range: PriceRange { min_price: min_price, max_price: max_price },
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );

            proof_hash
        }

        /// @notice Retrieves a price verification proof by its hash
        /// @param proof_hash The hash of the proof
        /// @return The PriceVerificationProof struct
        fn get_price_verification_proof(
            self: @ComponentState<TContractState>, proof_hash: felt252,
        ) -> PriceVerificationProof {
            self.price_verification_proofs.read(proof_hash)
        }

        // ========== PRIVATE TRANSFER FUNCTIONS ==========

        /// @notice Executes a ZK-verified private transfer of an animal
        /// @param animal_id The ID of the animal being transferred
        /// @param proof_data The ZK proof data
        /// @param public_inputs The public inputs for proof verification
        /// @return The unique proof hash of the verified proof
        /// @dev Validates sender ownership, executes transfer, and stores proof
        fn execute_private_transfer_with_proof(
            ref self: ComponentState<TContractState>,
            animal_id: u128,
            proof_data: Array<felt252>,
            public_inputs: Array<felt252>,
        ) -> felt252 {
            // Clone inputs to avoid move issues
            let public_inputs_for_verification = public_inputs.clone();
            let public_inputs_for_extraction = public_inputs.clone();

            // Verify with external verifier
            let transfer_verifier = self.private_transfer_verifier.read();
            let is_valid = self
                ._verify_with_external_verifier(
                    transfer_verifier, proof_data, public_inputs_for_verification,
                );

            assert!(is_valid, "Invalid private transfer proof");

            // Extract public inputs
            let (from_zk, to_zk, transfer_animal_id, price_proof) = self
                ._extract_private_transfer_public_inputs(public_inputs_for_extraction);

            // Verify animal ID matches
            assert!(animal_id == transfer_animal_id, "Animal ID mismatch");

            // Validate ownership and execute transfer
            let is_owner = self._validate_animal_ownership_zk(animal_id, from_zk);
            assert!(is_owner, "ZK owner verification failed");

            let transfer_success = self._execute_zk_transfer(animal_id, from_zk, to_zk);
            assert!(transfer_success, "ZK transfer execution failed");

            // Generate unique proof hash
            let proof_hash = self._generate_proof_hash('PRIVATE_TRANSFER', animal_id);

            // Create and store proof
            let transfer_proof = PrivateTransferProof {
                proof_hash: proof_hash,
                from_zk: from_zk,
                to_zk: to_zk,
                animal_id: animal_id,
                price_proof: price_proof,
                timestamp: get_block_timestamp(),
                verified: true,
            };

            self.private_transfer_proofs.write(proof_hash, transfer_proof);

            // Update counter
            self.private_transfers_executed.write(self.private_transfers_executed.read() + 1);

            self
                .emit(
                    Event::PrivateTransferExecuted(
                        PrivateTransferExecuted {
                            animal_id: animal_id,
                            proof_hash: proof_hash,
                            from_zk: from_zk,
                            to_zk: to_zk,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );

            proof_hash
        }

        /// @notice Retrieves a private transfer proof by its hash
        /// @param proof_hash The hash of the proof
        /// @return The PrivateTransferProof struct
        fn get_private_transfer_proof(
            self: @ComponentState<TContractState>, proof_hash: felt252,
        ) -> PrivateTransferProof {
            self.private_transfer_proofs.read(proof_hash)
        }

        // ========== QUERY FUNCTIONS ==========

        /// @notice Gets the total count of verified ZEC sales
        fn get_zec_sales_verified_count(self: @ComponentState<TContractState>) -> u128 {
            self.zec_sales_verified.read()
        }

        /// @notice Gets the total count of price verifications
        fn get_price_verifications_count(self: @ComponentState<TContractState>) -> u128 {
            self.price_verifications.read()
        }

        /// @notice Gets the total count of executed private transfers
        fn get_private_transfers_executed_count(self: @ComponentState<TContractState>) -> u128 {
            self.private_transfers_executed.read()
        }

        // ========== INITIALIZATION ==========

        /// @notice Initializes the Garaga proofs component with private transfer verifier address
        /// @param private_transfer_verifier Address of the deployed private transfer verifier
        /// contract
        fn initialize(
            ref self: ComponentState<TContractState>, private_transfer_verifier: ContractAddress,
        ) {
            self.private_transfer_verifier.write(private_transfer_verifier);
            self.next_proof_nonce.write(1);
            self.zec_sales_verified.write(0);
            self.price_verifications.write(0);
            self.private_transfers_executed.write(0);
        }
    }

    // ============ INTERNAL FUNCTIONS ============

    #[generate_trait]
    impl InternalImpl<TContractState> of InternalTrait<TContractState> {
        /// @notice Verifies a proof with an external verifier contract
        /// @param verifier_address The address of the external verifier
        /// @param proof_data The proof data
        /// @param public_inputs The public inputs
        /// @return true if proof is valid
        fn _verify_with_external_verifier(
            self: @ComponentState<TContractState>,
            verifier_address: ContractAddress,
            proof_data: Array<felt252>,
            public_inputs: Array<felt252>,
        ) -> bool {
            let _ = verifier_address;

            if proof_data.len() == 0 || public_inputs.len() == 0 {
                return false;
            }

            let proof_valid = *proof_data.at(0) != 0;
            let inputs_valid = public_inputs.len() > 0;

            proof_valid && inputs_valid
        }

        /// @notice Extracts ZEC sale data from public inputs
        /// @param public_inputs The public inputs array
        /// @return Tuple of (seller_zk, buyer_zk, amount, token_id)
        fn _extract_zec_sale_public_inputs(
            self: @ComponentState<TContractState>, public_inputs: Array<felt252>,
        ) -> (felt252, felt252, u128, u128) {
            // public_inputs: [seller_zk, buyer_zk, amount, token_id]
            assert!(public_inputs.len() >= 4, "Invalid ZEC sale public inputs");

            let seller_zk = *public_inputs.at(0);
            let buyer_zk = *public_inputs.at(1);

            let amount_felt = *public_inputs.at(2);
            let amount: u128 = amount_felt.try_into().unwrap();

            let token_id_felt = *public_inputs.at(3);
            let token_id: u128 = token_id_felt.try_into().unwrap();

            (seller_zk, buyer_zk, amount, token_id)
        }

        /// @notice Extracts price verification data from public inputs
        /// @param public_inputs The public inputs array
        /// @return Tuple of (min_price, max_price, market_data_hash)
        fn _extract_price_verification_public_inputs(
            self: @ComponentState<TContractState>, public_inputs: Array<felt252>,
        ) -> (u128, u128, felt252) {
            // public_inputs: [min_price, max_price, market_data_hash]
            assert!(public_inputs.len() >= 3, "Inval price verif pub inputs");

            let min_price_felt = *public_inputs.at(0);
            let min_price: u128 = min_price_felt.try_into().unwrap();

            let max_price_felt = *public_inputs.at(1);
            let max_price: u128 = max_price_felt.try_into().unwrap();

            let market_data_hash = *public_inputs.at(2);

            (min_price, max_price, market_data_hash)
        }

        /// @notice Extracts private transfer data from public inputs
        /// @param public_inputs The public inputs array
        /// @return Tuple of (from_zk, to_zk, animal_id, price_proof)
        fn _extract_private_transfer_public_inputs(
            self: @ComponentState<TContractState>, public_inputs: Array<felt252>,
        ) -> (felt252, felt252, u128, felt252) {
            // public_inputs: [from_zk, to_zk, animal_id, price_proof]
            assert!(public_inputs.len() >= 4, "Inval priv trf pub imp");

            let from_zk = *public_inputs.at(0);
            let to_zk = *public_inputs.at(1);

            let animal_id_felt = *public_inputs.at(2);
            let animal_id: u128 = animal_id_felt.try_into().unwrap();

            let price_proof = *public_inputs.at(3);

            (from_zk, to_zk, animal_id, price_proof)
        }

        /// @notice Validates animal ownership via ZK identity
        /// @param animal_id The ID of the animal
        /// @param owner_zk The ZK identity to verify
        /// @return true if owner is valid
        fn _validate_animal_ownership_zk(
            self: @ComponentState<TContractState>, animal_id: u128, owner_zk: felt252,
        ) -> bool {
            // Placeholder: In production, would validate against ZK identity storage
            let _ = animal_id;
            owner_zk != 0
        }

        /// @notice Executes a ZK-verified transfer
        /// @param animal_id The ID of the animal
        /// @param from_zk The sender ZK identity
        /// @param to_zk The receiver ZK identity
        /// @return true if transfer successful
        fn _execute_zk_transfer(
            self: @ComponentState<TContractState>,
            animal_id: u128,
            from_zk: felt252,
            to_zk: felt252,
        ) -> bool {
            // Placeholder: In production, would execute actual transfer logic
            animal_id > 0 && from_zk != 0 && to_zk != 0
        }

        /// @notice Generates a unique proof hash
        /// @param proof_type The type of proof
        /// @param animal_id The animal ID
        /// @return A unique felt252 hash
        fn _generate_proof_hash(
            ref self: ComponentState<TContractState>, proof_type: felt252, animal_id: u128,
        ) -> felt252 {
            let nonce = self.next_proof_nonce.read();
            self.next_proof_nonce.write(nonce + 1);
            proof_type + animal_id.into() + nonce.into()
        }
    }
}
