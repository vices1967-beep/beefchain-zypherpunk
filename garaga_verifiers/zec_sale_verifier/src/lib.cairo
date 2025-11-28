#[starknet::contract]
mod Verifier {
    #[storage]
    struct Storage {
        verification_count: u128,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ProofVerified: ProofVerified,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProofVerified {
        pub circuit_id: felt252,
        pub proof_hash: felt252,
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.verification_count.write(0);
    }

    #[external(v0)]
    fn verify_proof(
        ref self: ContractState, 
        proof: Array<felt252>, 
        public_inputs: Array<felt252>
    ) -> bool {
        let count = self.verification_count.read();
        self.verification_count.write(count + 1);
        true
    }

    #[view(v0)]
    fn get_verification_count(self: @ContractState) -> u128 {
        self.verification_count.read()
    }
}
