fn main(
    price: u64,
    min_price: u64,
    max_price: u64
) -> pub u64 {
    // Range verification using non-constant operations
    let is_above_min = price >= min_price;
    let is_below_max = price <= max_price;
    
    // Convert booleans to u64 (0 or 1)
    let above_min_num = if (is_above_min) { 1 } else { 0 };
    let below_max_num = if (is_below_max) { 1 } else { 0 };
    
    // Multiply to get 1 only if both conditions are true
    let result = above_min_num * below_max_num;
    
    result
}