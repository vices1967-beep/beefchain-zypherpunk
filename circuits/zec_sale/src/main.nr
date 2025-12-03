fn main(
    seller_zk: u64,
    buyer_zk: u64,
    amount: u64,
    token_id: u64,
    sale_nonce: u64,
    seller_sig: u64,
    expected_sale_hash: u64
) -> pub u64 {
    // 1. Verify seller signature (simple simulation)
    let computed_seller_sig = seller_zk + buyer_zk + amount + token_id + sale_nonce;
    let valid_seller_sig = computed_seller_sig == seller_sig;
    
    // 2. Verify sale hash (simple simulation)
    let computed_sale_hash = seller_zk + buyer_zk + token_id;
    let valid_sale_hash = computed_sale_hash == expected_sale_hash;
    
    // 3. Verify that amount is valid (> 0)
    let valid_amount = amount > 0;
    
    // Convert booleans to u64
    let sig_ok = if (valid_seller_sig) { 1 } else { 0 };
    let hash_ok = if (valid_sale_hash) { 1 } else { 0 };
    let amount_ok = if (valid_amount) { 1 } else { 0 };
    
    // All conditions must be true
    let result = sig_ok * hash_ok * amount_ok;
    
    result
}
#[test]
fn test_valid_sale() {
    let seller_zk = 0x123;
    let buyer_zk = 0x456;
    let amount = 0x64;
    let token_id = 0x1;
    let sale_nonce = 0x789;
    let seller_sig = 0xD67;  // 0x123 + 0x456 + 0x64 + 0x1 + 0x789
    let expected_sale_hash = 0x57A;  // 0x123 + 0x456 + 0x1
    
    let result = main(seller_zk, buyer_zk, amount, token_id, sale_nonce, seller_sig, expected_sale_hash);
    assert(result == 1);
}

#[test]  
fn test_invalid_signature() {
    let seller_zk = 0x123;
    let buyer_zk = 0x456;
    let amount = 0x64;
    let token_id = 0x1;
    let sale_nonce = 0x789;
    let seller_sig = 0x0;  // Firma incorrecta
    let expected_sale_hash = 0x57A;
    
    let result = main(seller_zk, buyer_zk, amount, token_id, sale_nonce, seller_sig, expected_sale_hash);
    assert(result == 0);
}
