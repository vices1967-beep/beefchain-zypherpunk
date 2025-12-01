#[starknet::contract]
mod zec_sale_verifier {
    #[storage]
    struct Storage {
        count: u128,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.count.write(0);
    }

    #[external(v0)]
    fn verify_proof(
        ref self: ContractState, 
        proof: Array<felt252>, 
        public_inputs: Array<felt252>
    ) -> bool {
        let current = self.count.read();
        self.count.write(current + 1);
        true
    }

    #[external(v0)]
    fn get_count(self: @ContractState) -> u128 {
        self.count.read()
    }
}
