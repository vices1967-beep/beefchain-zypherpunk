---
title: On-chain Proof Verification Demo (UltraKeccakHonk Verifier)
---

This demo shows the full flow from an already-generated Noir/Honk proof to a successful on-chain call to the deployed verifier on Starknet Sepolia.

## Artifacts Used
- Proof: `circuits/private_transfer/target/proof`
- Verifying key: `circuits/private_transfer/target/vk.bin`
- Deployed verifier: `0x028db9f84d24f2f3831d4733f152905212be0e732287cbab0f5a4244299d2a9b`
- RPC: `https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10/4_UTzxRAhIKqMUUVIAQ3o`

## Steps

1) Generate verifier calldata (array format for sncast):
```bash
cd garaga_verifiers/private_transfer_verifier_fix
garaga calldata \
  --system ultra_keccak_honk \
  --proof /Users/gianfranco/projects/beefchain-zypherpunk/circuits/private_transfer/target/proof \
  --vk /Users/gianfranco/projects/beefchain-zypherpunk/circuits/private_transfer/target/vk.bin \
  --format array > full_proof.json

# Prepare calldata: prepend length to the array of felts
CALldata=$(jq -r '[(length|tostring)] + (.[0:]|map(tostring)) | join(" ")' full_proof.json)
```

2) Call the on-chain verifier with sncast:
```bash
sncast call \
  --contract-address 0x028db9f84d24f2f3831d4733f152905212be0e732287cbab0f5a4244299d2a9b \
  --function verify_ultra_keccak_honk_proof \
  --calldata $CALldata \
  --url https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10/4_UTzxRAhIKqMUUVIAQ3o
```

## Call Result
```
Success: Call completed
Response:
[0x0, 0x3, 0x186a0, 0x0, 0x3039, 0x0,
 0x3d67e45af084af8d090df7113ceb0fa1,
 0x286a42f83a42548f622f9f1446d90a60]
```

Interpretation (public inputs returned):
- `0x0` (padding from noir/honk layout)
- `0x3` → number of public inputs
- `0x186a0` → `price_threshold` (100_000 decimal)
- `0x0` → separator/offset
- `0x3039` → `animal_id` (12_345 decimal)
- `0x0` → separator/offset
- `0x3d67e45af084af8d090df7113ceb0fa1` → Poseidon commitment
- `0x286a42f83a42548f622f9f1446d90a60` → second value of the commitment/output (per generated layout)

This confirms the Sepolia verifier accepts the locally generated proof and returns the expected public inputs.
