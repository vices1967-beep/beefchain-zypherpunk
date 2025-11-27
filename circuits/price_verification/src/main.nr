fn main(
    price: Field,
    commitment: Field
) -> pub Field {
    // Simple verification: price * 2 = commitment
    let computed = price * 2;
    assert(computed == commitment);
    
    // Return success
    1
}