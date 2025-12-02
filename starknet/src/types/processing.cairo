/// @title Processing and Health Data Types
/// @notice Data structures for health monitoring and veterinary operations
/// @dev Contains structs for quarantine, health records, and veterinarian authorization

use starknet::ContractAddress;

/// @notice Health record for an animal
/// @dev Tracks veterinary care, treatments, and vaccinations
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct HealthRecord {
    /// Veterinarian's diagnosis
    pub diagnosis: felt252,
    /// Treatment administered
    pub treatment: felt252,
    /// Vaccination information
    pub vaccination: felt252,
    /// When record was created
    pub timestamp: u64,
    /// Veterinarian who recorded this
    pub veterinarian: ContractAddress,
}

/// @notice Quarantine status tracking
/// @dev Records why an animal was quarantined and when
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct QuarantineStatus {
    /// Whether animal is currently quarantined
    pub is_active: bool,
    /// Reason for quarantine
    pub reason: felt252,
    /// When quarantine started
    pub start_date: u64,
    /// Veterinarian who ordered quarantine
    pub authorized_by: ContractAddress,
}
