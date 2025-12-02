/// @title Animal Data Types
/// @notice Core data structures for animal NFT tracking
/// @dev Contains all structs related to individual animal management and metadata

use starknet::ContractAddress;

/// @notice Core animal metadata and state
/// @dev Stores essential information about each animal in the supply chain.
/// The animal progresses through states: Created (0) -> Processed (1) -> Certified (2) -> Exported
/// (3)
///
/// Fields explanation:
/// - breed: Breed identifier (e.g., Angus = 1, Hereford = 2)
/// - birth_date: Birth date as Unix timestamp
/// - weight: Current weight in kilograms
/// - status: Current state in supply chain (0-3)
/// - owner: Current owner address
/// - processing_facility: Processing facility address (zero if not yet transferred)
/// - certifier: Certifier address (zero if not yet certified)
/// - exporter: Export handler address (zero if not exported)
/// - batch_id: Associated batch ID (zero if not in batch)
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct AnimalData {
    /// Animal breed/race identifier
    pub breed: u128,
    /// Birth timestamp (Unix)
    pub birth_date: u64,
    /// Current weight in kg
    pub weight: u128,
    /// Status: 0=Created, 1=Processed, 2=Certified, 3=Exported
    pub status: u8,
    /// Current owner address
    pub owner: ContractAddress,
    /// Processing facility address
    pub processing_facility: ContractAddress,
    /// Certifier address
    pub certifier: ContractAddress,
    /// Exporter address
    pub exporter: ContractAddress,
    /// Associated batch/lot ID
    pub batch_id: u128,
}

/// @notice Represents a meat cut from a processed animal
/// @dev Created when processing facility processes an animal into cuts
/// Each animal can have multiple cuts for different market purposes
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct MeatCutData {
    /// Type of cut (e.g., ribeye=1, sirloin=2)
    pub cut_type: u128,
    /// Weight of this cut in kg
    pub weight: u128,
    /// When this cut was created
    pub processing_date: u64,
    /// Which processing facility created this cut
    pub processing_facility: ContractAddress,
    /// Whether this cut has been certified
    pub is_certified: bool,
    /// Associated export batch ID
    pub export_batch_id: u128,
    /// Current owner of this cut
    pub owner: ContractAddress,
    /// Original animal this cut came from
    pub animal_id: u128,
}

/// @notice Represents a batch of animals from producer to processing facility
/// @dev Batch allows efficient transfer of multiple animals together
/// Tracks movement from producer -> processing_facility -> processing
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct AnimalBatchData {
    /// Original owner (producer)
    pub owner: ContractAddress,
    /// Processing facility destination
    pub processing_facility: ContractAddress,
    /// When batch was created
    pub creation_date: u64,
    /// When batch was transferred to processing facility
    pub transfer_date: u64,
    /// When batch processing was completed
    pub processing_date: u64,
    /// Status: 0=Created, 1=Transferred, 2=Processed
    pub status: u8,
    /// Number of animals in batch
    pub animal_count: u32,
    /// Total weight of all animals in batch
    pub total_weight: u128,
}

/// @notice IoT sensor readings for environmental monitoring
/// @dev Records conditions (temperature, humidity, location) during transport/storage
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct IoTSensorReading {
    /// Timestamp of reading
    pub timestamp: u64,
    /// Temperature in Celsius (can be negative, hence i32)
    pub temperature: i32,
    /// Humidity percentage (0-100)
    pub humidity: u32,
    /// GPS latitude coordinate
    pub latitude: i64,
    /// GPS longitude coordinate
    pub longitude: i64,
    /// Identifier of IoT device
    pub device_id: felt252,
    /// Type of reading (temperature, humidity, location, etc)
    pub reading_type: felt252,
}

/// @notice Certification document for quality assurance
/// @dev Created by certifier when animal/product meets quality standards
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct CertificationData {
    /// When certification was issued
    pub certification_date: u64,
    /// Type of certification (organic, grass-fed, etc)
    pub certification_type: felt252,
    /// Who issued the certification
    pub certifier: ContractAddress,
    /// When certification expires (0 = never)
    pub expiry_date: u64,
    /// Hash of certification document
    pub certificate_hash: felt252,
}

/// @notice Represents an export shipment of meat products
/// @dev Tracks international shipments with container and temperature info
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct ExportData {
    /// When export was initiated
    pub export_date: u64,
    /// Destination country code (e.g., 'CHINA', 'JAPAN')
    pub destination_country: felt252,
    /// Export permit/license number
    pub export_permit: felt252,
    /// Container/shipping ID
    pub container_id: felt252,
    /// (min_temp, max_temp) observed during transit
    pub temperature_range: (i32, i32),
    /// Exporter/shipper address
    pub exporter: ContractAddress,
}

/// @notice Price range for value verification
/// @dev Used in ZK proofs to verify price fell within expected bounds
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct PriceRange {
    /// Minimum acceptable price
    pub min_price: u128,
    /// Maximum acceptable price
    pub max_price: u128,
}
