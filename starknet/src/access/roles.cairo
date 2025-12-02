/// @title Role Definitions
/// @notice Defines all roles and permissions in the Animal supply chain
/// @dev Each role represents a specific function in the supply chain workflow

/// @notice Default admin role - has all permissions
/// Used to grant and revoke other roles
pub const DEFAULT_ADMIN_ROLE: felt252 = 0;

/// @notice Producer role
/// Permissions:
/// - Create animals
/// - Create batches
/// - Transfer animals to processing facilities
/// - Register as participant
pub const PRODUCER_ROLE: felt252 = 'PRODUCER_ROLE';

/// @notice Processing facility role
/// Permissions:
/// - Process animals
/// - Create meat cuts
/// - Transfer batches
/// - Process batches
/// - Generate QR codes for cuts
pub const PROCESSING_FACILITY_ROLE: felt252 = 'PROCESSING_FACILITY_ROLE';

/// @notice Veterinarian role
/// Permissions:
/// - Add health records
/// - Quarantine animals
/// - Clear quarantine status
/// - Authorize other veterinarians for specific animals
pub const VETERINARIAN_ROLE: felt252 = 'VETERINARIAN_ROLE';

/// @notice IoT device role
/// Permissions:
/// - Record sensor readings (temperature, humidity, location)
/// - Update device metadata
pub const IOT_ROLE: felt252 = 'IOT_ROLE';

/// @notice Certifier role
/// Permissions:
/// - Certify animals
/// - Certify meat cuts
/// - Certify batches
/// - Revoke certifications
pub const CERTIFIER_ROLE: felt252 = 'CERTIFIER_ROLE';

/// @notice Exporter role
/// Permissions:
/// - Prepare export batches
/// - Confirm exports
/// - Update temperature during transport
/// - Transfer meat cuts to exporters
pub const EXPORTER_ROLE: felt252 = 'EXPORTER_ROLE';

/// @notice Auditor role
/// Permissions:
/// - View full history
/// - View audit trails
/// - Generate reports
/// - No write permissions (read-only)
pub const AUDITOR_ROLE: felt252 = 'AUDITOR_ROLE';


/// @notice Helper function to get role description
/// @param role The role constant
/// @return Role name as felt252
pub fn get_role_name(role: felt252) -> felt252 {
    if role == DEFAULT_ADMIN_ROLE {
        'ADMIN'
    } else if role == PRODUCER_ROLE {
        'PRODUCER'
    } else if role == PROCESSING_FACILITY_ROLE {
        'PROCESSING_FACILITY'
    } else if role == VETERINARIAN_ROLE {
        'VETERINARIAN'
    } else if role == IOT_ROLE {
        'IOT'
    } else if role == CERTIFIER_ROLE {
        'CERTIFIER'
    } else if role == EXPORTER_ROLE {
        'EXPORTER'
    } else if role == AUDITOR_ROLE {
        'AUDITOR'
    } else {
        'UNKNOWN'
    }
}
