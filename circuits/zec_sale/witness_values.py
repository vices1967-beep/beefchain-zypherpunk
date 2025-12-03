import json

# Valores del test que pasa
witness = {
    "seller_zk": 0x123,
    "buyer_zk": 0x456,
    "amount": 0x64,
    "token_id": 0x1,
    "sale_nonce": 0x789,
    "seller_sig": 0xD67,  # Calculado correctamente
    "expected_sale_hash": 0x57A
}

with open('witness.json', 'w') as f:
    json.dump(witness, f, indent=2)

print("✅ Witness creado: witness.json")
