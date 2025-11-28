#[starknet::contract]
pub mod ZECBridge {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use core::array::ArrayTrait;
    
    #[storage]
    pub struct Storage {
        zec_balances: LegacyMap<ContractAddress, u128>,
        total_supply: u128,
        bridge_admin: ContractAddress,
        deposited_events: LegacyMap<felt252, bool>,
        next_deposit_id: u128,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ZECDeposited: ZECDeposited,
        ZECWithdrawn: ZECWithdrawn,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ZECDeposited {
        pub deposit_id: felt252,
        pub from_zcash_address: felt252,
        pub amount: u128,
        pub starknet_recipient: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ZECWithdrawn {
        pub to_zcash_address: felt252,
        pub amount: u128,
        pub starknet_sender: ContractAddress,
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.bridge_admin.write(admin);
        self.next_deposit_id.write(1);
    }

    #[abi(embed_v0)]
    impl ZECBridgeImpl of IZECBridge<ContractState> {
        // Función que llama el oráculo cuando detecta depósito en Zcash
        fn deposit_zec(
            ref self: ContractState,
            zcash_tx_hash: felt252,
            zcash_address: felt252, 
            amount: u128,
            starknet_recipient: ContractAddress
        ) {
            // Solo el admin (oráculo) puede llamar esto
            assert(get_caller_address() == self.bridge_admin.read(), "Only bridge admin");
            
            // Evitar double spending
            assert(!self.deposited_events.read(zcash_tx_hash), "Already processed");
            self.deposited_events.write(zcash_tx_hash, true);
            
            // Mint equivalent tokens en Starknet
            let current_balance = self.zec_balances.read(starknet_recipient);
            self.zec_balances.write(starknet_recipient, current_balance + amount);
            self.total_supply.write(self.total_supply.read() + amount);
            
            let deposit_id = self.next_deposit_id.read();
            self.next_deposit_id.write(deposit_id + 1);
            
            self.emit(Event::ZECDeposited(ZECDeposited {
                deposit_id: deposit_id.into(),
                from_zcash_address: zcash_address,
                amount: amount,
                starknet_recipient: starknet_recipient,
                timestamp: get_block_timestamp(),
            }));
        }

        // Retirar ZEC de vuelta a Zcash
        fn withdraw_zec(
            ref self: ContractState,
            to_zcash_address: felt252,
            amount: u128
        ) {
            let caller = get_caller_address();
            let balance = self.zec_balances.read(caller);
            
            assert(balance >= amount, "Insufficient balance");
            
            // Burn tokens
            self.zec_balances.write(caller, balance - amount);
            self.total_supply.write(self.total_supply.read() - amount);
            
            self.emit(Event::ZECWithdrawn(ZECWithdrawn {
                to_zcash_address: to_zcash_address,
                amount: amount,
                starknet_sender: caller,
                timestamp: get_block_timestamp(),
            }));
        }

        fn get_balance(self: @ContractState, account: ContractAddress) -> u128 {
            self.zec_balances.read(account)
        }

        fn get_total_supply(self: @ContractState) -> u128 {
            self.total_supply.read()
        }
    }

    #[starknet::interface]
    pub trait IZECBridge<TContractState> {
        fn deposit_zec(
            ref self: TContractState,
            zcash_tx_hash: felt252,
            zcash_address: felt252,
            amount: u128,
            starknet_recipient: ContractAddress
        );
        
        fn withdraw_zec(
            ref self: TContractState,
            to_zcash_address: felt252,
            amount: u128
        );
        
        fn get_balance(self: @TContractState, account: ContractAddress) -> u128;
        fn get_total_supply(self: @TContractState) -> u128;
    }
}