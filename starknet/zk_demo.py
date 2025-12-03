from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.account.account import Account
from starknet_py.net.models import StarknetChainId
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.contract import Contract
import asyncio

async def main():
    print("=== BEEFCHAIN ZK HACKATON DEMO ===")
    
    # Configuración
    RPC_URL = "https://ztarknet-madara.d.karnot.xyz"
    ANIMAL_CONTRACT = 0x016da7fb1e6d2e2df4bbd332e533b0581c52e920b39a6e199bc6f21ac3227820
    
    # Tu cuenta
    ACCOUNT_ADDRESS = 0x3550921cd7b4b84e960151111260980e6ffdc61d55226e1dd1fd2d7b659f89d
    PRIVATE_KEY = 0x5280542b9caf85771ebf6730d88610d49de4a6e811b20662b940557d6d16931
    
    try:
        print("1. Conectando a Starknet Madara...")
        client = FullNodeClient(RPC_URL)
        
        print("2. Configurando cuenta...")
        key_pair = KeyPair.from_private_key(PRIVATE_KEY)
        account = Account(
            client=client,
            address=ACCOUNT_ADDRESS,
            key_pair=key_pair,
            chain=StarknetChainId.SEPOLIA,
        )
        
        print("3. Cargando contrato Animal...")
        animal_contract = await Contract.from_address(
            address=ANIMAL_CONTRACT,
            provider=account,
        )
        
        print("4. Creando animal para pruebas...")
        create_tx = await animal_contract.functions["create_animal_simple"].invoke(
            breed=999,
            max_fee=2000000000000000
        )
        await create_tx.wait_for_acceptance()
        print(f"   ✅ Animal creado: TX {hex(create_tx.hash)}")
        
        print("\n5. EJECUTANDO PRUEBAS ZK:")
        
        # a) verify_price_with_proof
        print("   a) verify_price_with_proof...")
        try:
            price_proof_tx = await animal_contract.functions["verify_price_with_proof"].invoke(
                animal_id=999,
                proof_data=[0x1],
                public_inputs=[50000, 100000, 0x12345],
                max_fee=2000000000000000
            )
            await price_proof_tx.wait_for_acceptance()
            print(f"      ✅ Success: TX {hex(price_proof_tx.hash)}")
        except Exception as e:
            print(f"      ❌ Error: {e}")
        
        # b) verify_zec_sale_with_proof  
        print("   b) verify_zec_sale_with_proof...")
        try:
            zec_proof_tx = await animal_contract.functions["verify_zec_sale_with_proof"].invoke(
                animal_id=999,
                proof_data=[0x1],
                public_inputs=[0x111, 0x222, 500, 1],
                max_fee=2000000000000000
            )
            await zec_proof_tx.wait_for_acceptance()
            print(f"      ✅ Success: TX {hex(zec_proof_tx.hash)}")
        except Exception as e:
            print(f"      ❌ Error: {e}")
        
        print("\n6. Verificando resultados...")
        zec_count = await animal_contract.functions["get_zec_sales_verified_count"].call()
        price_count = await animal_contract.functions["get_price_verifications_count"].call()
        
        print(f"   ✅ ZEC Sales: {zec_count.count}")
        print(f"   ✅ Price Verifications: {price_count.count}")
        
        print("\n🏆 ¡DEMO COMPLETADA!")
        
    except Exception as e:
        print(f"\n❌ Error general: {e}")
        print("\n⚠️  Solución: Ejecuta primero:")
        print("sncast invoke --url https://ztarknet-madara.d.karnot.xyz \\")
        print("  --contract-address 0x016da7fb1e6d2e2df4bbd332e533b0581c52e920b39a6e199bc6f21ac3227820 \\")
        print("  --function grant_role --arguments \"'PRODUCER_ROLE',0x3550921cd7b4b84e960151111260980e6ffdc61d55226e1dd1fd2d7b659f89d\" \\")
        print("  --max-fee 2000000000000000")

if __name__ == "__main__":
    asyncio.run(main())
