/// @title Privacy and Zero-Knowledge Proof Types
/// @notice Data structures for privacy-preserving operations and proof verification
/// @dev Contains ZK identity, privacy metadata, and proof structures for Garaga integration

use super::animal::PriceRange;

/// @notice Privacy metadata for an animal
/// @dev Tracks which animals are in private mode and their ZK transfers
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct PrivacyData {
    /// ZK hash of current owner (anonymized)
    pub current_owner_zk_hash: felt252,
    /// Proof of last private transfer
    pub last_transfer_proof: felt252,
    /// Whether this animal is in private mode
    pub is_private_mode: bool,
    /// Count of private transfers
    pub private_transfer_count: u32,
}

/// @notice Privacy dashboard for consumers
/// @dev Summary of privacy-related information for a specific animal
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct PrivacyDashboard {
    /// The animal this dashboard represents
    pub animal_id: u128,
    /// Whether animal is in private mode
    pub is_private_mode: bool,
    /// Total private transfers completed
    pub total_private_transfers: u32,
    /// Hash of last proof
    pub last_proof_hash: felt252,
    /// Privacy score (0-100)
    pub privacy_score: u8,
}

/// @notice ZEC Sale proof structure
/// @dev Proof that a sale transaction occurred with verified parties and amount
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct ZecSaleProof {
    /// Unique proof identifier
    pub proof_hash: felt252,
    /// ZK hash of seller (anonymized)
    pub seller_zk_hash: felt252,
    /// ZK hash of buyer (anonymized)
    pub buyer_zk_hash: felt252,
    /// Transaction amount
    pub amount: u256,
    /// Token identifier
    pub token_id: felt252,
    /// When transaction occurred
    pub timestamp: u64,
    /// Whether proof has been verified
    pub verified: bool,
}

/// @notice Price verification proof
/// @dev Proof that an asset's price falls within acceptable bounds
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct PriceVerificationProof {
    /// Unique proof identifier
    pub proof_hash: felt252,
    /// Acceptable price range
    pub price_range: PriceRange,
    /// Hash of market data used
    pub market_data_hash: felt252,
    /// When verification occurred
    pub timestamp: u64,
    /// Whether proof has been verified
    pub verified: bool,
}

/// @notice Private transfer proof
/// @dev Cryptographic proof of a private transfer between ZK identities
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct PrivateTransferProof {
    /// Unique proof identifier
    pub proof_hash: felt252,
    /// ZK hash of sender
    pub from_zk_hash: felt252,
    /// ZK hash of recipient
    pub to_zk_hash: felt252,
    /// Animal being transferred
    pub animal_id: u128,
    /// Associated price proof
    pub price_proof: felt252,
    /// When transfer occurred
    pub timestamp: u64,
    /// Whether proof has been verified
    pub verified: bool,
}
