/// @title Telemetry Types
/// @notice Data structures for IoT sensor readings, QR codes, and consumer data
/// @dev Contains all structs related to telemetry, traceability, and public data exposure

use starknet::ContractAddress;

/// @notice IoT sensor reading from environmental monitoring
/// @dev Records sensor data (temperature, humidity, location) during transport/storage
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct IoTReading {
    /// Timestamp of the reading
    pub timestamp: u64,
    /// Temperature in Celsius (can be negative)
    pub temperature: i32,
    /// Humidity percentage (0-100)
    pub humidity: u32,
    /// GPS latitude coordinate
    pub latitude: i64,
    /// GPS longitude coordinate
    pub longitude: i64,
    /// IoT device identifier
    pub device_id: felt252,
    /// Type of reading (e.g., 'TEMPERATURE', 'HUMIDITY', 'LOCATION')
    pub reading_type: felt252,
}

/// @notice QR code metadata and tracking information
/// @dev Stores information about generated QR codes for traceability
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct QRData {
    /// Unique hash/identifier for this QR code
    pub qr_hash: felt252,
    /// Animal ID (if applicable)
    pub animal_id: u128,
    /// Meat cut ID (if applicable)
    pub cut_id: u128,
    /// When QR was generated
    pub timestamp: u64,
    /// Type of QR: 'CUT', 'ANIMAL', 'BATCH'
    pub data_type: felt252,
    /// Additional metadata
    pub metadata: felt252,
}

/// @notice Public consumer-facing data with anonymized sensitive information
/// @dev Used when exposing traceability data to end consumers while protecting privacy
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct PublicConsumerData {
    /// Animal breed/race identifier
    pub breed: u128,
    /// Animal birth date timestamp
    pub birth_date: u64,
    /// Processing/slaughter date timestamp
    pub processing_date: u64,
    /// Processing facility name (anonymized/hashed)
    pub processing_facility_name: felt252,
    /// Certifier name (anonymized/hashed)
    pub certifier_name: felt252,
    /// Meat cut type identifier
    pub cut_type: u128,
    /// Cut weight in kilograms
    pub cut_weight: u128,
    /// Certification types/standards achieved
    pub certifications: felt252,
    /// Country of origin (e.g., 'Uruguay', 'Argentina')
    pub origin_country: felt252,
}
