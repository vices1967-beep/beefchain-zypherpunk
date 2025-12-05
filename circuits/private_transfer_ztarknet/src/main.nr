use std::hash::poseidon2::Poseidon2;

fn main(
    // Private inputs (never revealed on-chain)
    price: u64,             // Actual price of the animal (in cents)
    seller_secret: Field,   // Secret known only by seller
    buyer_secret: Field,    // Secret known only by buyer

    // Public inputs (visible on-chain)
    price_threshold: pub u64,       // Minimum price requirement (in cents)
    animal_id: pub u64              // The animal being transferred
) -> pub Field {
    // Convert price to Field for hashing
    let price_field = price as Field;

    // 1. Compute commitment: Poseidon(price, seller_secret, buyer_secret)
    // This will be returned as a public output
    let commitment = Poseidon2::hash([price_field, seller_secret, buyer_secret], 3);

    // 2. Verify price threshold: price >= price_threshold
    // This proves the price is above the minimum without revealing the exact amount
    assert(price >= price_threshold, "Price below threshold");

    // 3. Verify price is positive (sanity check)
    assert(price > 0, "Price must be positive");

    // 4. Verify animal_id exists (prevents zero ID transfers)
    assert(animal_id > 0, "Invalid animal ID");

    // Return the commitment as public output
    commitment
}