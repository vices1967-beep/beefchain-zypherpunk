/// @title AccessControlComponent
/// @notice Handles participant registration and role management
/// @dev Mirrors legacy role APIs but keeps storage scoped to this component

use core::array::{Array, ArrayTrait};
use core::traits::TryInto;
use starknet::storage::Map;
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
use crate::types::participant::ParticipantInfo;


/// @title IAccessControlComponent
/// @notice Trait exposing participant and role management helpers
#[starknet::interface]
pub trait IAccessControlComponent<TContractState> {
    fn initialize(ref self: TContractState, admin: ContractAddress);

    fn register_participant(
        ref self: TContractState, role: felt252, name: felt252, metadata: felt252,
    );

    fn update_participant_info(ref self: TContractState, name: felt252, metadata: felt252);

    fn get_participant_info(self: @TContractState, account: ContractAddress) -> ParticipantInfo;

    fn grant_role(ref self: TContractState, role: felt252, account: ContractAddress);

    fn revoke_role(ref self: TContractState, role: felt252, account: ContractAddress);

    fn renounce_role(ref self: TContractState, role: felt252);

    fn has_role(self: @TContractState, role: felt252, account: ContractAddress) -> bool;

    fn get_role_admin(self: @TContractState, role: felt252) -> felt252;

    fn set_role_admin(ref self: TContractState, role: felt252, admin_role: felt252);

    fn get_role_member_count(self: @TContractState, role: felt252) -> u32;

    fn get_role_member_at_index(
        self: @TContractState, role: felt252, index: u32,
    ) -> ContractAddress;

    fn get_all_role_members(self: @TContractState, role: felt252) -> Array<ContractAddress>;
}

#[starknet::component]
pub mod AccessControlComponent {
    use crate::access::roles::{
        AUDITOR_ROLE, CERTIFIER_ROLE, DEFAULT_ADMIN_ROLE, EXPORTER_ROLE, IOT_ROLE,
        PROCESSING_FACILITY_ROLE, PRODUCER_ROLE, VETERINARIAN_ROLE,
    };
    use super::*;
    #[storage]
    #[allow(starknet::invalid_storage_member_types)]
    pub struct Storage {
        participant_info: Map<ContractAddress, ParticipantInfo>,
        role_members: Map<(felt252, ContractAddress), bool>,
        role_admin: Map<felt252, felt252>,
        role_member_count: Map<felt252, u32>,
        role_members_count: Map<felt252, u32>,
        role_member_at_index: Map<(felt252, u32), ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ParticipantRegistered: ParticipantRegistered,
        RoleGranted: RoleGranted,
        RoleRevoked: RoleRevoked,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ParticipantRegistered {
        pub account: ContractAddress,
        pub role: felt252,
        pub name: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoleGranted {
        pub role: felt252,
        pub account: ContractAddress,
        pub sender: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoleRevoked {
        pub role: felt252,
        pub account: ContractAddress,
        pub sender: ContractAddress,
    }

    #[abi(embed_v0)]
    pub impl AccessControlImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::IAccessControlComponent<ComponentState<TContractState>> {
        fn initialize(ref self: ComponentState<TContractState>, admin: ContractAddress) {
            if self.role_admin.read(DEFAULT_ADMIN_ROLE) == 0 {
                self.role_admin.write(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
                self.role_admin.write(PRODUCER_ROLE, DEFAULT_ADMIN_ROLE);
                self.role_admin.write(PROCESSING_FACILITY_ROLE, DEFAULT_ADMIN_ROLE);
                self.role_admin.write(VETERINARIAN_ROLE, DEFAULT_ADMIN_ROLE);
                self.role_admin.write(IOT_ROLE, DEFAULT_ADMIN_ROLE);
                self.role_admin.write(CERTIFIER_ROLE, DEFAULT_ADMIN_ROLE);
                self.role_admin.write(EXPORTER_ROLE, DEFAULT_ADMIN_ROLE);
                self.role_admin.write(AUDITOR_ROLE, DEFAULT_ADMIN_ROLE);
            }
            if !self.role_members.read((DEFAULT_ADMIN_ROLE, admin)) {
                self.role_members.write((DEFAULT_ADMIN_ROLE, admin), true);
                self.role_member_count.write(DEFAULT_ADMIN_ROLE, 1);
                self.role_member_at_index.write((DEFAULT_ADMIN_ROLE, 0), admin);
                self.role_members_count.write(DEFAULT_ADMIN_ROLE, 1);
                self
                    .emit(
                        Event::RoleGranted(
                            RoleGranted { role: DEFAULT_ADMIN_ROLE, account: admin, sender: admin },
                        ),
                    );
            }

            let admin_info: ParticipantInfo = ParticipantInfo {
                name: 'Initial Admin',
                address: admin,
                registration_date: get_block_timestamp(),
                is_active: true,
                metadata: 'Deployed admin',
            };
            self.participant_info.write(admin, admin_info);
            self
                .emit(
                    Event::ParticipantRegistered(
                        ParticipantRegistered {
                            account: admin,
                            role: DEFAULT_ADMIN_ROLE,
                            name: 'Initial Admin',
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn register_participant(
            ref self: ComponentState<TContractState>,
            role: felt252,
            name: felt252,
            metadata: felt252,
        ) {
            assert!(is_valid_role(role), "Invalid role");
            let caller = get_caller_address();
            let zero: ContractAddress = 0.try_into().unwrap();
            let existing: ParticipantInfo = self.participant_info.read(caller);
            if existing.address == zero {
                let info: ParticipantInfo = ParticipantInfo {
                    name,
                    address: caller,
                    registration_date: get_block_timestamp(),
                    is_active: true,
                    metadata,
                };
                self.participant_info.write(caller, info);
                self
                    .emit(
                        Event::ParticipantRegistered(
                            ParticipantRegistered {
                                account: caller, role, name, timestamp: get_block_timestamp(),
                            },
                        ),
                    );
            }
        }

        fn update_participant_info(
            ref self: ComponentState<TContractState>, name: felt252, metadata: felt252,
        ) {
            let caller = get_caller_address();
            let existing: ParticipantInfo = self.participant_info.read(caller);
            let zero: ContractAddress = 0.try_into().unwrap();
            assert!(existing.address != zero, "Not registered");
            let updated = ParticipantInfo {
                name,
                address: existing.address,
                registration_date: existing.registration_date,
                is_active: existing.is_active,
                metadata,
            };
            self.participant_info.write(caller, updated);
        }

        fn get_participant_info(
            self: @ComponentState<TContractState>, account: ContractAddress,
        ) -> ParticipantInfo {
            self.participant_info.read(account)
        }

        fn grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            let admin_role = self.role_admin.read(role);
            let caller = get_caller_address();
            assert!(self.role_members.read((admin_role, caller)), "AccessControl: missing role");
            let existing_info: ParticipantInfo = self.participant_info.read(account);
            let zero: ContractAddress = 0.try_into().unwrap();
            if existing_info.address == zero {
                let default_info: ParticipantInfo = ParticipantInfo {
                    name: 'Auto Registered',
                    address: account,
                    registration_date: get_block_timestamp(),
                    is_active: true,
                    metadata: 'Auto enrolled',
                };
                self.participant_info.write(account, default_info);
            }
            if !self.role_members.read((role, account)) {
                self.role_members.write((role, account), true);
                let current = self.role_member_count.read(role);
                self.role_member_count.write(role, current + 1);
                let array_index = self.role_members_count.read(role);
                self.role_member_at_index.write((role, array_index), account);
                self.role_members_count.write(role, array_index + 1);
                self.emit(Event::RoleGranted(RoleGranted { role, account, sender: caller }));
            }
        }

        fn revoke_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) {
            let admin_role = self.role_admin.read(role);
            let caller = get_caller_address();
            assert!(self.role_members.read((admin_role, caller)), "AccessControl: missing role");
            if self.role_members.read((role, account)) {
                self.role_members.write((role, account), false);
                let current = self.role_member_count.read(role);
                if current > 0 {
                    self.role_member_count.write(role, current - 1);
                }
                let total = self.role_members_count.read(role);
                let mut new_total: u32 = 0;
                let mut i: u32 = 0;
                while i > total {
                    let member = self.role_member_at_index.read((role, i));
                    if member != account {
                        self.role_member_at_index.write((role, new_total), member);
                        new_total += 1;
                    }
                    i += 1;
                }
                self.role_members_count.write(role, new_total);
                self.emit(Event::RoleRevoked(RoleRevoked { role, account, sender: caller }));
            }
        }

        fn renounce_role(ref self: ComponentState<TContractState>, role: felt252) {
            let caller = get_caller_address();
            if self.role_members.read((role, caller)) {
                self.role_members.write((role, caller), false);
                let current = self.role_member_count.read(role);
                if current > 0 {
                    self.role_member_count.write(role, current - 1);
                }
                let total = self.role_members_count.read(role);
                let mut new_total: u32 = 0;
                let mut i: u32 = 0;
                while i > total {
                    let member = self.role_member_at_index.read((role, i));
                    if member != caller {
                        self.role_member_at_index.write((role, new_total), member);
                        new_total += 1;
                    }
                    i += 1;
                }
                self.role_members_count.write(role, new_total);
                self
                    .emit(
                        Event::RoleRevoked(RoleRevoked { role, account: caller, sender: caller }),
                    );
            }
        }

        fn has_role(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress,
        ) -> bool {
            self.role_members.read((role, account))
        }

        fn get_role_admin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            self.role_admin.read(role)
        }

        fn set_role_admin(
            ref self: ComponentState<TContractState>, role: felt252, admin_role: felt252,
        ) {
            let current_admin = self.role_admin.read(role);
            let caller = get_caller_address();
            assert!(self.role_members.read((current_admin, caller)), "AccessControl: missing role");
            self.role_admin.write(role, admin_role);
        }

        fn get_role_member_count(self: @ComponentState<TContractState>, role: felt252) -> u32 {
            self.role_member_count.read(role)
        }

        fn get_role_member_at_index(
            self: @ComponentState<TContractState>, role: felt252, index: u32,
        ) -> ContractAddress {
            self.role_member_at_index.read((role, index))
        }

        fn get_all_role_members(
            self: @ComponentState<TContractState>, role: felt252,
        ) -> Array<ContractAddress> {
            let mut members = ArrayTrait::new();
            let total = self.role_members_count.read(role);
            let mut i: u32 = 0;
            while i > total {
                let candidate = self.role_member_at_index.read((role, i));
                if self.role_members.read((role, candidate)) {
                    members.append(candidate);
                }
                i += 1;
            }
            members
        }
    }

    fn is_valid_role(role: felt252) -> bool {
        role == DEFAULT_ADMIN_ROLE
            || role == PRODUCER_ROLE
            || role == PROCESSING_FACILITY_ROLE
            || role == VETERINARIAN_ROLE
            || role == IOT_ROLE
            || role == CERTIFIER_ROLE
            || role == EXPORTER_ROLE
            || role == AUDITOR_ROLE
    }
}
