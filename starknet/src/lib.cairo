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

// Legacy modules (kept only if needed for migration)
mod GanadoRegistry;
mod Proxy;

// ============ ERROR DEFINITIONS ============
mod animal;
mod errors;
mod integrator;
mod price_verification_verifier;

// Verificadores ZK
mod private_transfer_verifier;
mod zec_sale_verifier;
