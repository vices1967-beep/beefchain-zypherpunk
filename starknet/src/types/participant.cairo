/// @title Participant and QR Data Types
/// @notice Data structures for participant registration and QR code tracking
/// @dev Contains participant info and public consumer data structures

use starknet::ContractAddress;

/// @notice Participant information in the supply chain
/// @dev Stores metadata for producers, processors, certifiers, exporters, etc.
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct ParticipantInfo {
    /// Display name of participant
    pub name: felt252,
    /// Contract address of participant
    pub address: ContractAddress,
    /// When participant registered
    pub registration_date: u64,
    /// Whether account is active
    pub is_active: bool,
    /// Additional metadata (JSON or custom format)
    pub metadata: felt252,
}

/// @notice QR code data for product tracking
/// @dev Links QR codes to animals/cuts for consumer verification
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct QRCodeData {
    /// Hash of QR code
    pub qr_hash: felt252,
    /// Associated animal ID (0 if not animal-specific)
    pub animal_id: u128,
    /// Associated meat cut ID (0 if not cut-specific)
    pub meat_cut_id: u128,
    /// When QR code was created
    pub timestamp: u64,
    /// Type: 'ANIMAL', 'CUT', or 'BATCH'
    pub data_type: felt252,
    /// Additional metadata
    pub metadata: felt252,
}

/// @notice Public consumer-facing data from animals
/// @dev Anonymized data that consumers can verify via QR codes
/// This data is carefully curated to show supply chain without revealing sensitive info
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct PublicConsumerData {
    /// Animal breed
    pub breed: u128,
    /// Birth date
    pub birth_date: u64,
    /// Date processed
    pub processing_date: u64,
    /// Processing facility name
    pub processing_facility_name: felt252,
    /// Certifier name
    pub certifier_name: felt252,
    /// Type of cut
    pub cut_type: u128,
    /// Weight of cut
    pub cut_weight: u128,
    /// Certifications obtained
    pub certifications: felt252,
    /// Country of origin
    pub country_of_origin: felt252,
}
