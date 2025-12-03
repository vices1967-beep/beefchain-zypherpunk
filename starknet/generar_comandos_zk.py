#!/usr/bin/env python3

print("=== COMANDOS ZK PARA EJECUTAR CON SNCAST ===")
print("")

# Animal ID 5 (que ya creaste)
animal_id = 5

print("1. VERIFICACIÓN DE PRECIO ZK:")
print(f"sncast invoke \\")
print(f"  --url https://ztarknet-madara.d.karnot.xyz \\")
print(f"  --contract-address 0x016da7fb1e6d2e2df4bbd332e533b0581c52e920b39a6e199bc6f21ac3227820 \\")
print(f"  --function verify_price_with_proof \\")
print(f"  --arguments \"{animal_id},1,1,3,50000,100000,12345\" \\")
print(f"  --max-fee 2000000000000000")
print("")

print("2. VERIFICACIÓN DE VENTA ZEC:")
print(f"sncast invoke \\")
print(f"  --url https://ztarknet-madara.d.karnot.xyz \\")
print(f"  --contract-address 0x016da7fb1e6d2e2df4bbd332e533b0581c52e920b39a6e199bc6f21ac3227820 \\")
print(f"  --function verify_zec_sale_with_proof \\")
print(f"  --arguments \"{animal_id},1,1,4,111,222,500,1\" \\")
print(f"  --max-fee 2000000000000000")
print("")

print("3. TRANSFERENCIA PRIVADA ZK:")
print(f"sncast invoke \\")
print(f"  --url https://ztarknet-madara.d.karnot.xyz \\")
print(f"  --contract-address 0x016da7fb1e6d2e2df4bbd332e533b0581c52e920b39a6e199bc6f21ac3227820 \\")
print(f"  --function execute_private_transfer_with_proof \\")
print(f"  --arguments \"{animal_id},1,1,4,111,333,{animal_id},123456\" \\")
print(f"  --max-fee 2000000000000000")
