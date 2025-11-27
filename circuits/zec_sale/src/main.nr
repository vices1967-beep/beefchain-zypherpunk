fn main(
    seller_secret: Field,
    buyer_secret: Field,
    animal_id: Field,
    expected_seller: Field,
    expected_buyer: Field
) -> pub Field {
    // Verify seller: seller_secret + animal_id = expected_seller
    let seller_check = seller_secret + animal_id;
    assert(seller_check == expected_seller);
    
    // Verify buyer: buyer_secret + animal_id = expected_buyer  
    let buyer_check = buyer_secret + animal_id;
    assert(buyer_check == expected_buyer);
    
    // Return success
    1
}