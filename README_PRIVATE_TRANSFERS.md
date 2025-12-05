# Private Animal Transfers with Zero-Knowledge Proofs

This document explains the Zero-Knowledge proof system implemented for private animal transfers in BeefChain, deployed on both **StarkNet Sepolia** and **ZtarkNet**.

## 🎯 Overview

The private transfer system allows selling and transferring animals with **privacy-preserving price verification**. Using ZK proofs, sellers can prove:
- The sale price meets a minimum threshold
- The transaction is valid
- Without revealing the exact price on-chain

## 🏗️ Architecture

### Components

1. **Noir Circuit** ([circuits/private_transfer/src/main.nr](circuits/private_transfer/src/main.nr))
   - Implements the ZK proof logic
   - Uses Poseidon2 hash for commitments
   - Proves price constraints without revealing actual price

2. **Barretenberg Prover** (bb CLI)
   - Generates ZK proofs from circuit witnesses
   - Two proof systems supported:
     - `ultra_keccak_honk` - For StarkNet Sepolia
     - `ultra_honk --zk --oracle_hash starknet` - For ZtarkNet

3. **Garaga Verifier** (Cairo contracts)
   - On-chain proof verification
   - Converts Barretenberg proofs to Cairo-compatible format
   - Deployed on both networks

4. **Animal Contract** ([starknet/src/animal.cairo](starknet/src/animal.cairo))
   - Main contract with privacy-enabled transfers
   - Integrates with Garaga verifier
   - Manages animal ownership and transfers

### Data Flow

```
┌─────────────┐
│   Seller    │
│  (off-chain)│
└──────┬──────┘
       │
       │ 1. Inputs: price, seller_secret, buyer_secret
       ▼
┌─────────────────┐
│  Noir Circuit   │  Proves: price >= threshold
│  (Poseidon2)    │         price > 0
└────────┬────────┘         animal_id valid
         │
         │ 2. Generate witness
         ▼
┌──────────────────┐
│  Barretenberg    │  Creates ZK proof
│  (bb prove)      │
└────────┬─────────┘
         │
         │ 3. Binary proof + VK
         ▼
┌──────────────────┐
│     Garaga       │  Converts to felt252[]
│  (calldata)      │
└────────┬─────────┘
         │
         │ 4. Submit to StarkNet
         ▼
┌──────────────────┐
│ Garaga Verifier  │  Verifies proof on-chain
│   (Cairo)        │
└────────┬─────────┘
         │
         │ 5. Verification result
         ▼
┌──────────────────┐
│ Animal Contract  │  Executes private transfer
│                  │  if proof is valid
└──────────────────┘
```

## 🌐 Deployed Contracts

### StarkNet Sepolia (Testnet)

| Contract | Address | Explorer |
|----------|---------|----------|
| **Verifier** | `0x028db9f84d24f2f3831d4733f152905212be0e732287cbab0f5a4244299d2a9b` | [View](https://sepolia.voyager.online/contract/0x028db9f84d24f2f3831d4733f152905212be0e732287cbab0f5a4244299d2a9b) |
| **Animal** | `0x02F285FdC38549ecFeBCf284ca73fC23b1AB42130C4D3F70Acf1521Af550dBdD` | [View](https://sepolia.voyager.online/contract/0x02F285FdC38549ecFeBCf284ca73fC23b1AB42130C4D3F70Acf1521Af550dBdD) |

**Network Details:**
- RPC: `https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10/<API_KEY>`
- Proof System: `ultra_keccak_honk`
- Proof verified: ✅ See [PROOF_VERIFICATION_DEMO.md](PROOF_VERIFICATION_DEMO.md)

### ZtarkNet (Hackathon Network)

| Contract | Address | Explorer |
|----------|---------|----------|
| **Verifier** | `0x018d69d9593358013894e73336f701f85e8cb1ea474c310792f9be18d365821b` | [View](https://explorer.ztarknet.cash/contract/0x018d69d9593358013894e73336f701f85e8cb1ea474c310792f9be18d365821b) |
| **Animal** | `0x065f738557b85fdf7520e3ee6145853e67c3a5d2702bc1c7ce77cb18f9b3cb8b` | [View](https://explorer.ztarknet.cash/contract/0x065f738557b85fdf7520e3ee6145853e67c3a5d2702bc1c7ce77cb18f9b3cb8b) |

**Network Details:**
- RPC: `https://ztarknet-madara.d.karnot.xyz`
- Proof System: `ultra_honk --zk --oracle_hash starknet`
- Faucet: https://faucet.ztarknet.cash/

### ZtarkNet E2E script (demo)
- Configure `scripts/.env.ztarknet` with your RPC, `ACCOUNT_NAME`, `ACCOUNTS_FILE`, `ANIMAL_ADDR`, `VERIFIER_ADDR`, and optional `ANIMAL_ID` (leave empty to use the freshly created one).
- Run `cd scripts && no_proxy="*" ./ztarknet_e2e.sh` to:
  1) Call the verifier with `full_proof_ztarknet.json`
  2) Create an animal, update weight, enable private mode
  3) Perform a demo `private_transfer_animal` using the `VALID_PROOF_DEMO` felt
- The script will generate `full_proof_ztarknet.json` if missing (via `garaga calldata`) and uses the account stored in `scripts/ztarknet_accounts.json` (ignored by git).

## 🚀 Quick Start

### Prerequisites

Install required tools:

```bash
# Noir (circuit compiler)
curl -L https://install.nargo.dev | bash
noirup -v 1.0.0-beta.1

# Barretenberg (proof generator)
# Download from: https://github.com/AztecProtocol/barretenberg/releases/tag/barretenberg-v0.67.0

# Garaga (Cairo verifier generator)
pip install garaga==0.15.5

# Starknet Foundry (deployment tool)
curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | bash
```

### Generate a Proof

#### For StarkNet Sepolia:

```bash
cd circuits/private_transfer

# Edit Prover.toml with your values or use CLI arguments
./generate-proof.sh 150000 \  # price ($1500.00)
  123456789...30 \              # seller_secret (random)
  987654321...10 \              # buyer_secret (random)
  100000 \                      # price_threshold ($1000.00)
  12345                         # animal_id
```

#### For ZtarkNet:

```bash
cd circuits/private_transfer_ztarknet

./generate-proof-ztarknet.sh 150000 \
  123456789...30 \
  987654321...10 \
  100000 \
  12345
```

### Verify Proof On-Chain

```bash
cd garaga_verifiers/private_transfer_verifier_fix

# Generate calldata
garaga calldata \
  --system ultra_keccak_honk \
  --proof ../../circuits/private_transfer/target/proof \
  --vk ../../circuits/private_transfer/target/vk.bin \
  --format array > full_proof.json

# Format for sncast
CALLDATA=$(jq -r '[(length|tostring)] + (.[0:]|map(tostring)) | join(" ")' full_proof.json)

# Call verifier
sncast call \
  --contract-address 0x028db9f84d24f2f3831d4733f152905212be0e732287cbab0f5a4244299d2a9b \
  --function verify_ultra_keccak_honk_proof \
  --calldata $CALLDATA \
  --url https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10/<API_KEY>
```

See [PROOF_VERIFICATION_DEMO.md](PROOF_VERIFICATION_DEMO.md) for a complete example.

## 🔐 Privacy Guarantees

See [PRIVACY_ARCHITECTURE.md](PRIVACY_ARCHITECTURE.md) for detailed privacy analysis.

**What's Private:**
- ✅ Exact sale price (only seller and buyer know)
- ✅ Seller identity (hidden via zero-knowledge)
- ✅ Buyer identity (hidden via zero-knowledge)

**What's Public:**
- ⚠️ Price threshold (minimum price constraint)
- ⚠️ Animal ID (which animal was transferred)
- ⚠️ Commitment hash (binds price + secrets, reveals nothing)

**Security Properties:**
- **Zero-Knowledge**: Verifier learns nothing beyond "price >= threshold"
- **Soundness**: Impossible to prove false statements
- **Completeness**: Valid proofs always verify

## 📚 Documentation

- [PRIVACY_ARCHITECTURE.md](PRIVACY_ARCHITECTURE.md) - Privacy model explained
- [DEPLOYMENT.md](DEPLOYMENT.md) - How to deploy to new networks
- [PROOF_VERIFICATION_DEMO.md](PROOF_VERIFICATION_DEMO.md) - Live proof verification example
- [circuits/private_transfer/README.md](circuits/private_transfer/README.md) - Circuit documentation

## 🧪 Testing

### End-to-End Test on ZtarkNet

```bash
# Configure environment
cp scripts/.env.ztarknet.sample scripts/.env.ztarknet
# Edit .env.ztarknet with your values

# Run E2E test
./scripts/ztarknet_e2e.sh
```

This will:
1. Create an animal
2. Update its weight
3. Enable private mode
4. Register ZK identity
5. Execute a private transfer
6. Verify the proof on-chain

## 🛠️ Development

### Circuit Structure

The Noir circuit ([circuits/private_transfer/src/main.nr](circuits/private_transfer/src/main.nr)):

```noir
fn main(
    price: u64,              // Private: actual sale price
    seller_secret: Field,    // Private: seller's secret
    buyer_secret: Field,     // Private: buyer's secret
    price_threshold: pub u64,  // Public: minimum price
    animal_id: pub u64       // Public: animal identifier
) -> pub Field {
    // Compute commitment
    let price_field = price as Field;
    let commitment = Poseidon2::hash([price_field, seller_secret, buyer_secret], 3);

    // Assert constraints
    assert(price >= price_threshold, "Price below threshold");
    assert(price > 0, "Price must be positive");
    assert(animal_id > 0, "Invalid animal ID");

    commitment
}
```

### Adding New Proof Types

To add a new proof type:

1. Create a new circuit in `circuits/<proof_name>/`
2. Generate VK with Barretenberg
3. Use Garaga to generate Cairo verifier
4. Add to `GaragaProofsComponent`
5. Integrate with Animal contract

## 🤝 Contributing

When contributing privacy features:

1. **Never log or expose private inputs**
2. **Document what data is public vs private**
3. **Add tests for both valid and invalid proofs**
4. **Update privacy documentation**

## 📖 References

- [Noir Language](https://noir-lang.org/)
- [Barretenberg](https://github.com/AztecProtocol/barretenberg)
- [Garaga](https://github.com/keep-starknet-strange/garaga)
- [ZtarkNet](https://github.com/ztarknet)
- [StarkNet](https://www.starknet.io/)

## 📄 License

See repository root for license information.
