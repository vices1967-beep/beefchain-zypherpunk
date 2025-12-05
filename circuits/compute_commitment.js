#!/usr/bin/env node

/**
 * Compute Poseidon commitment for private transfer
 * Usage: node compute_commitment.js <price> <seller_secret> <buyer_secret>
 *
 * This script computes: Poseidon2::hash([price, seller_secret, buyer_secret])
 * to generate the commitment that will be used as a public input in the circuit.
 */

const { poseidon2Hash } = require('@noir-lang/barretenberg/dest/crypto/poseidon');

function computeCommitment(price, sellerSecret, buyerSecret) {
    // Convert inputs to BigInt
    const priceField = BigInt(price);
    const sellerSecretField = BigInt(sellerSecret);
    const buyerSecretField = BigInt(buyerSecret);

    // Compute Poseidon hash
    const commitment = poseidon2Hash([priceField, sellerSecretField, buyerSecretField]);

    return commitment.toString();
}

// Parse command line arguments
if (process.argv.length < 5) {
    console.error('Usage: node compute_commitment.js <price> <seller_secret> <buyer_secret>');
    console.error('Example: node compute_commitment.js 150000 0x1234... 0xfedcba...');
    process.exit(1);
}

const price = process.argv[2];
const sellerSecret = process.argv[3];
const buyerSecret = process.argv[4];

try {
    const commitment = computeCommitment(price, sellerSecret, buyerSecret);
    console.log('Commitment:', commitment);
    process.exit(0);
} catch (error) {
    console.error('Error computing commitment:', error.message);
    process.exit(1);
}
