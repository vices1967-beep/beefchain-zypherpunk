#[starknet::contract]
mod integrator {
    use starknet::ContractAddress;
    
    #[storage]
    struct Storage {
        animal_nft: ContractAddress,
        private_transfer_verifier: ContractAddress,
        zec_sale_verifier: ContractAddress, 
        price_verification_verifier: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        nft: ContractAddress,
        private_verifier: ContractAddress,
        zec_verifier: ContractAddress,
        price_verifier: ContractAddress
    ) {
        self.animal_nft.write(nft);
        self.private_transfer_verifier.write(private_verifier);
        self.zec_sale_verifier.write(zec_verifier);
        self.price_verification_verifier.write(price_verifier);
    }

    #[external(v0)]
    fn verify_all(self: @ContractState) -> bool {
        true
    }

    #[external(v0)]
    fn get_animal_nft(self: @ContractState) -> ContractAddress {
        self.animal_nft.read()
    }
}
