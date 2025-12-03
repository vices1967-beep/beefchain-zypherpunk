import os

seller = 0x123    # 291
buyer = 0x456     # 1110
amount = 0x64     # 100
token = 0x1       # 1
nonce = 0x789     # 1929

seller_sig = seller + buyer + amount + token + nonce  # 291+1110+100+1+1929 = 3431
sale_hash = seller + buyer + token                    # 291+1110+1 = 1402

print(f'seller_sig calculado: {seller_sig} (0x{seller_sig:X})')
print(f'sale_hash calculado: {sale_hash} (0x{sale_hash:X})')

# Reemplazar en el archivo
with open('src/main.nr', 'r') as f:
    content = f.read()

# Reemplazar valores incorrectos
content = content.replace('seller_sig = 0xECC;', f'seller_sig = 0x{seller_sig:X};')
content = content.replace('expected_sale_hash = 0x57A;', f'expected_sale_hash = 0x{sale_hash:X};')

with open('src/main.nr', 'w') as f:
    f.write(content)

print('✅ Test corregido')
print('🔢 Nuevos valores:')
print(f'  seller_sig = 0x{seller_sig:X}')
print(f'  expected_sale_hash = 0x{sale_hash:X}')
