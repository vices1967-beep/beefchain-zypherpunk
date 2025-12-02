/// @title Error Constants
/// @notice Centralized error message definitions
/// @dev All error messages used throughout the contract for consistent error handling

// Access Control Errors
/// User does not have the required role
pub const ERROR_UNAUTHORIZED: felt252 = 'UNAUTHORIZED';

/// Account is not the owner of the resource
pub const ERROR_NOT_OWNER: felt252 = 'NOT_OWNER';

/// Account does not have admin privileges
pub const ERROR_NOT_ADMIN: felt252 = 'NOT_ADMIN';

// Animal State Errors
/// Animal does not exist
pub const ERROR_ANIMAL_NOT_FOUND: felt252 = 'ANIMAL_NOT_FOUND';

/// Animal is in quarantine and cannot be transferred
pub const ERROR_ANIMAL_QUARANTINED: felt252 = 'ANIMAL_QUARANTINED';

/// Animal has already been processed
pub const ERROR_ALREADY_PROCESSED: felt252 = 'ALREADY_PROCESSED';

/// Animal has not been processed yet
pub const ERROR_NOT_PROCESSED: felt252 = 'NOT_PROCESSED';

/// Animal status does not allow the requested operation
pub const ERROR_INVALID_STATUS: felt252 = 'INVALID_STATUS';

// Batch Errors
/// Batch does not exist
pub const ERROR_BATCH_NOT_FOUND: felt252 = 'BATCH_NOT_FOUND';

/// Batch has already been transferred
pub const ERROR_BATCH_TRANSFERRED: felt252 = 'BATCH_TRANSFERRED';

/// Batch status invalid for operation
pub const ERROR_INVALID_BATCH_STATUS: felt252 = 'INVALID_BATCH_STATUS';

// Meat Cut Errors
/// Meat cut does not exist
pub const ERROR_CUT_NOT_FOUND: felt252 = 'CUT_NOT_FOUND';

/// Meat cut has not been certified
pub const ERROR_CUT_NOT_CERTIFIED: felt252 = 'CUT_NOT_CERTIFIED';

// Certification Errors
/// Animal has not been certified
pub const ERROR_NOT_CERTIFIED: felt252 = 'NOT_CERTIFIED';

/// Certification has expired
pub const ERROR_CERTIFICATION_EXPIRED: felt252 = 'CERT_EXPIRED';

// Transfer Errors
/// Transfer operation blocked for unknown reason
pub const ERROR_TRANSFER_BLOCKED: felt252 = 'TRANSFER_BLOCKED';

/// Recipient is invalid or zero address
pub const ERROR_INVALID_RECIPIENT: felt252 = 'INVALID_RECIPIENT';

// Veterinarian Errors
/// Veterinarian is not authorized for this animal
pub const ERROR_NOT_AUTHORIZED_VET: felt252 = 'NOT_AUTHORIZED_VET';

// Health & Quarantine Errors
/// Invalid health record
pub const ERROR_INVALID_HEALTH_RECORD: felt252 = 'INVALID_HEALTH_REC';

/// Quarantine reason is empty
pub const ERROR_EMPTY_QUARANTINE_REASON: felt252 = 'EMPTY_REASON';

// Privacy Errors
/// Animal not in private mode
pub const ERROR_NOT_PRIVATE: felt252 = 'NOT_PRIVATE';

/// ZK identity not found
pub const ERROR_ZK_IDENTITY_NOT_FOUND: felt252 = 'ZK_NOT_FOUND';

/// Privacy proof is invalid
pub const ERROR_INVALID_PRIVACY_PROOF: felt252 = 'INVALID_PROOF';

// Price Verification Errors
/// Price proof is invalid
pub const ERROR_INVALID_PRICE_PROOF: felt252 = 'INVALID_PRICE';

/// Price is out of acceptable range
pub const ERROR_PRICE_OUT_OF_RANGE: felt252 = 'PRICE_RANGE';

// Export Errors
/// Export batch does not exist
pub const ERROR_EXPORT_NOT_FOUND: felt252 = 'EXPORT_NOT_FOUND';

/// Cannot export unverified animals
pub const ERROR_CANNOT_EXPORT_UNVERIFIED: felt252 = 'CANNOT_EXPORT';

// Input Validation Errors
/// Parameter is zero or invalid
pub const ERROR_INVALID_INPUT: felt252 = 'INVALID_INPUT';

/// Array is empty
pub const ERROR_EMPTY_ARRAY: felt252 = 'EMPTY_ARRAY';

/// Array length mismatch
pub const ERROR_ARRAY_LENGTH_MISMATCH: felt252 = 'LENGTH_MISMATCH';

// Storage Errors
/// Animal already in batch
pub const ERROR_ALREADY_IN_BATCH: felt252 = 'ALREADY_IN_BATCH';

/// Role already granted
pub const ERROR_ROLE_ALREADY_GRANTED: felt252 = 'ROLE_GRANTED';

// General Errors
/// Operation failed (generic)
pub const ERROR_OPERATION_FAILED: felt252 = 'OPERATION_FAILED';

/// Invalid state transition
pub const ERROR_INVALID_TRANSITION: felt252 = 'INVALID_TRANSITION';
