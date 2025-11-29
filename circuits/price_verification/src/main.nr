fn main(
    price: u64,
    min_price: u64,
    max_price: u64
) -> pub u64 {
    // Verificación de rango usando operaciones que no son constantes
    let is_above_min = price >= min_price;
    let is_below_max = price <= max_price;
    
    // Convertir booleanos a u64 (0 o 1)
    let above_min_num = if (is_above_min) { 1 } else { 0 };
    let below_max_num = if (is_below_max) { 1 } else { 0 };
    
    // Multiplicar para obtener 1 solo si ambas condiciones son verdaderas
    let result = above_min_num * below_max_num;
    
    result
}