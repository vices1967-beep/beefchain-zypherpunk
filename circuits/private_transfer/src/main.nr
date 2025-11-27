fn main(
    owner_secret: Field,
    animal_id: Field, 
    expected_result: Field
) -> pub Field {
    // Simple verification: owner_secret * animal_id should equal expected_result
    let computed = owner_secret * animal_id;
    assert(computed == expected_result);
    
    // Return success (1)
    1
}