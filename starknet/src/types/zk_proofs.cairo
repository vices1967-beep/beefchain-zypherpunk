/// @title Zero-Knowledge Proof Types
/// @notice Data structures for ZK proof verification via Garaga
/// @dev Contains all structs related to ZEC sales, price verification, and private transfers

use starknet::ContractAddress;
use crate::types::animal::PriceRange;

/// @notice ZEC sale proof from external verification
/// @dev Stores verified ZEC sale transaction data
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct ZecSaleProof {
    /// Unique hash identifying this proof
    pub proof_hash: felt252,
    /// Zero-knowledge identity of seller
    pub seller_zk: felt252,
    /// Zero-knowledge identity of buyer
    pub buyer_zk: felt252,
    /// Sale amount in smallest units
    pub amount: u128,
    /// ZEC token ID associated with sale
    pub token_id: u128,
    /// When proof was verified
    pub timestamp: u64,
    /// Whether proof has been verified
    pub verified: bool,
}

/// @notice Price verification proof from external verification
/// @dev Validates that price falls within acceptable market range
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct PriceVerificationProof {
    /// Unique hash identifying this proof
    pub proof_hash: felt252,
    /// Min and max acceptable price range
    pub price_range: PriceRange,
    /// Hash of market data used for verification
    pub market_data_hash: felt252,
    /// When proof was verified
    pub timestamp: u64,
    /// Whether proof has been verified
    pub verified: bool,
}

/// @notice Private transfer proof from external verification
/// @dev Authorizes ZK-verified transfer between parties
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct PrivateTransferProof {
    /// Unique hash identifying this proof
    pub proof_hash: felt252,
    /// Zero-knowledge identity of sender
    pub from_zk: felt252,
    /// Zero-knowledge identity of receiver
    pub to_zk: felt252,
    /// Animal ID being transferred
    pub animal_id: u128,
    /// Associated price verification proof
    pub price_proof: felt252,
    /// When proof was verified
    pub timestamp: u64,
    /// Whether proof has been verified
    pub verified: bool,
}
