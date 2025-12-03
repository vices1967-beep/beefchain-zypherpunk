/// @title Beefchain - Livestock Supply Chain on Starknet
/// @notice Main module entry point for all components
/// @dev Exports all sub-modules, types, and the main Animal contract

// ============ TYPES ============
pub mod types {
    pub mod animal;
    pub mod participant;
    pub mod privacy;
    pub mod telemetry;
    pub mod zk_proofs;
}

// ============ ACCESS CONTROL ============
pub mod access {
    pub mod roles;
}

// ============ COMPONENTS ============
pub mod components {
    pub mod access_control;
    pub mod animal_core;
    pub mod audit_analytics;
    pub mod certification;
    pub mod export;
    pub mod garaga_proofs;
    pub mod health;
    pub mod privacy;
    pub mod processing;
    pub mod telemetry;
}

// ============ ERROR DEFINITIONS ============
mod errors;

// Verificadores ZK
mod animal;
mod private_transfer_verifier;
mod zec_sale_verifier;
mod price_verification_verifier;
mod integrator;

// NOTA: animal.cairo ahora es un contrato Starknet independiente
// con #[starknet::contract] y se compila separadamente
