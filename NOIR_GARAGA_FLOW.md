# 🔐 FLUJO COMPLETO: NOIR → GARAGA → CAIRO → BLOCKCHAIN

## Guía Completa del Flujo de Zero-Knowledge Proofs en BeefChain

Este documento explica paso a paso cómo funcionan los circuitos Zero-Knowledge en BeefChain, desde escribir la lógica en Noir hasta verificar pruebas en StarkNet.

---

## 📋 Tabla de Contenidos

1. [Visión General](#visión-general)
2. [Componentes del Sistema](#componentes-del-sistema)
3. [Flujo de Desarrollo (Una vez)](#flujo-de-desarrollo)
4. [Flujo de Producción (Cada usuario)](#flujo-de-producción)
5. [Ejemplo Completo](#ejemplo-completo)
6. [Separación de Responsabilidades](#separación-de-responsabilidades)

---

## Visión General

### ¿Cómo se relacionan Noir, Garaga y Cairo?

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUJO SIMPLIFICADO                            │
└─────────────────────────────────────────────────────────────────┘

DESARROLLO:
  Noir → Nargo → Garaga → Cairo → Deploy a StarkNet

PRODUCCIÓN:
  Usuario genera prueba (Noir en navegador)
        ↓
  Usuario envía prueba a blockchain
        ↓
  Blockchain verifica con Cairo
```

### La Clave: NO hay comunicación directa

**Noir** y **Garaga** NO se comunican en tiempo real. Garaga es solo una herramienta de compilación que traduce circuitos Noir a código Cairo.

```
Noir:   Lenguaje para escribir lógica ZK
Garaga: Compilador (Noir → Cairo)
Cairo:  Lenguaje de StarkNet para verificar pruebas
```

---

## Componentes del Sistema

### 1. Noir Circuit (Circuito ZK)

**Ubicación**: `circuits/private_transfer/src/main.nr`

```noir
fn main(
    from_zk: u64,              // Identidad vendedor (PRIVADO)
    to_zk: u64,                // Identidad comprador (PRIVADO)
    animal_id: u64,            // ID del animal
    price: u64,                // Precio exacto (PRIVADO)
    timestamp: u64,
    signature: u64,            // Firma criptográfica
    expected_commitment: u64
) -> pub u64 {                 // Retorna 1 si válido, 0 si inválido
    // Verifica firma
    let computed_signature = from_zk + to_zk + animal_id + price + timestamp;
    let valid_signature = computed_signature == signature;

    // Verifica compromiso
    let computed_commitment = from_zk + to_zk + animal_id;
    let valid_commitment = computed_commitment == expected_commitment;

    // Verifica precio válido
    let valid_price = price > 0;

    // Convierte a números
    let signature_ok = if (valid_signature) { 1 } else { 0 };
    let commitment_ok = if (valid_commitment) { 1 } else { 0 };
    let price_ok = if (valid_price) { 1 } else { 0 };

    // TODOS deben pasar
    let result = signature_ok * commitment_ok * price_ok;

    result
}
```

**¿Qué hace?**
- Define la lógica de verificación
- Especifica qué datos son privados
- Retorna 1 si todas las verificaciones pasan

---

### 2. Nargo (Compilador Noir)

**Comando**: `nargo compile`

**Input**: `src/main.nr` (código Noir)
**Output**: `target/private_transfer.json` (circuito compilado)

El archivo JSON contiene:
- Representación matemática del circuito (ACIR)
- "Puertas lógicas" criptográficas
- Restricciones matemáticas

**Nargo NO genera Cairo. Solo genera una representación matemática.**

---

### 3. Garaga (Traductor Noir → Cairo)

**Comando**:
```bash
garaga gen \
  --system noir \
  --vk target/private_transfer.json \
  --output ../../garaga_verifiers/private_transfer_verifier
```

**Input**: `private_transfer.json` (circuito compilado)
**Output**: `garaga_verifiers/private_transfer_verifier/src/lib.cairo`

**¿Qué genera?**
- Un contrato StarkNet completo en Cairo
- Función `verify_proof()` que verifica pruebas
- Toda la lógica matemática para validar en blockchain

---

### 4. Verificador Cairo (Contrato StarkNet)

**Ubicación**: `garaga_verifiers/private_transfer_verifier/src/lib.cairo`

```cairo
#[starknet::contract]
mod Verifier {
    #[storage]
    struct Storage {
        verification_count: u128,
    }

    #[external(v0)]
    fn verify_proof(
        ref self: ContractState,
        proof: Array<felt252>,           // Prueba ZK
        public_inputs: Array<felt252>    // Inputs públicos
    ) -> bool {
        // Verifica criptográficamente la prueba
        // (Código generado por Garaga)

        self.verification_count.write(
            self.verification_count.read() + 1
        );

        true  // Retorna true si válido
    }
}
```

**¿Qué hace?**
- Se deploya en StarkNet blockchain
- Recibe pruebas generadas por Noir
- Verifica criptográficamente que son válidas
- Retorna true/false

---

### 5. AnimalNFT Cairo (Orquestador)

**Ubicación**: `starknet/src/components/garaga_proofs.cairo`

```cairo
fn execute_private_transfer_with_proof(
    animal_id: u128,
    proof_data: Array<felt252>,
    public_inputs: Array<felt252>
) -> felt252 {
    // Obtener dirección del verificador Garaga
    let verifier = self.private_transfer_verifier.read();

    // Llamar al verificador
    let is_valid = IVerifier::at(verifier)
        .verify_proof(proof_data, public_inputs);

    assert!(is_valid, "Invalid proof");

    // Extraer datos públicos
    let (from_zk, to_zk, animal_id, price_proof) =
        extract_public_inputs(public_inputs);

    // Ejecutar transferencia
    transfer_animal(animal_id, from_zk, to_zk);

    // Guardar proof
    save_proof(proof_hash);

    proof_hash
}
```

**¿Qué hace?**
- Coordina el flujo completo
- Llama al verificador Garaga
- Ejecuta la lógica de negocio (transferencia)
- Guarda registros en blockchain

---

## Flujo de Desarrollo

### Parte 1: Configuración (Una vez por circuito)

```
┌──────────────────────────────────────────────────────────────────┐
│ PASO 1: Escribir Circuito Noir                                   │
└──────────────────────────────────────────────────────────────────┘

Ubicación: circuits/private_transfer/src/main.nr

Ya lo tienes hecho ✓
Este archivo define la LÓGICA de lo que quieres verificar
```

---

```
┌──────────────────────────────────────────────────────────────────┐
│ PASO 2: Compilar Circuito con Nargo                              │
└──────────────────────────────────────────────────────────────────┘

Comando:
$ cd circuits/private_transfer
$ nargo compile

Genera:
circuits/private_transfer/
├── target/
│   └── private_transfer.json  ← CIRCUITO COMPILADO
├── Prover.toml
└── src/main.nr

El archivo JSON contiene:
- Circuito en formato matemático (ACIR)
- Puertas lógicas criptográficas
- Restricciones matemáticas

⚠️ Noir NO genera Cairo aquí. Solo genera matemáticas.
```

---

```
┌──────────────────────────────────────────────────────────────────┐
│ PASO 3: Generar Verificador Cairo con Garaga                     │
└──────────────────────────────────────────────────────────────────┘

Comando:
$ garaga gen \
    --system noir \
    --vk circuits/private_transfer/target/private_transfer.json \
    --output garaga_verifiers/private_transfer_verifier

Flujo:
Input:  private_transfer.json (circuito compilado por Noir)
        ↓
    [GARAGA]
        ↓
Output: garaga_verifiers/private_transfer_verifier/src/lib.cairo

El lib.cairo generado contiene:
✓ Contrato StarkNet completo en Cairo
✓ Función verify_proof() para verificar pruebas
✓ Lógica matemática para validación en blockchain
```

---

```
┌──────────────────────────────────────────────────────────────────┐
│ PASO 4: Compilar Verificador Cairo                               │
└──────────────────────────────────────────────────────────────────┘

Comando:
$ cd garaga_verifiers/private_transfer_verifier
$ scarb build

Genera:
garaga_verifiers/private_transfer_verifier/
├── target/dev/
│   └── private_transfer_verifier.contract_class.json  ← BYTECODE
└── src/lib.cairo

El .contract_class.json:
✓ Bytecode del contrato para StarkNet
✓ Listo para deployarse en blockchain
✓ Contiene toda la lógica del verificador
```

---

```
┌──────────────────────────────────────────────────────────────────┐
│ PASO 5: Deployar Verificador en StarkNet                         │
└──────────────────────────────────────────────────────────────────┘

Opción A: Con starkli
$ starkli declare target/dev/private_transfer_verifier.contract_class.json \
    --network sepolia

$ starkli deploy <CLASS_HASH> \
    --network sepolia

Opción B: Con Garaga
$ garaga declare \
    --network sepolia \
    --contract target/dev/private_transfer_verifier.contract_class.json

$ garaga deploy \
    --network sepolia \
    --class-hash <CLASS_HASH>

Resultado:
✓ Verificador deployado en: 0xABC123...DEF
✓ Ya puedes verificar pruebas en blockchain
```

---

```
┌──────────────────────────────────────────────────────────────────┐
│ PASO 6: Configurar Dirección en AnimalNFT                        │
└──────────────────────────────────────────────────────────────────┘

Comando (via starkli):
$ starkli invoke \
    <ANIMAL_NFT_ADDRESS> \
    set_private_transfer_verifier \
    <VERIFIER_ADDRESS>

O en el constructor de AnimalNFT:
constructor(
    ...
    private_transfer_verifier: 0xABC123...DEF
)

Ahora AnimalNFT puede llamar al verificador cuando reciba pruebas.
```

---

## Flujo de Producción

### Parte 2: Uso en Producción (Cada vez que un usuario transfiere)

```
┌──────────────────────────────────────────────────────────────────┐
│ PASO 7: Usuario Genera Prueba (Frontend)                         │
└──────────────────────────────────────────────────────────────────┘

Ubicación: frontend/src/services/noirProofService.ts

import { Noir } from '@noir-lang/noir_js';
import circuit from '../circuits/private_transfer.json';

async function generatePrivateTransferProof(inputs) {
  // Cargar circuito compilado
  const noir = new Noir(circuit);

  // Preparar inputs privados
  const privateInputs = {
    from_zk: 1111111111,        // Identidad vendedor
    to_zk: 2222222222,          // Identidad comprador
    animal_id: 12345,
    price: 1500,                // PRECIO (PRIVADO)
    timestamp: Date.now(),
    signature: calculateSignature(...),
    expected_commitment: calculateCommitment(...)
  };

  // Ejecutar circuito Noir EN EL NAVEGADOR
  const { witness } = await noir.execute(privateInputs);

  // Generar prueba criptográfica
  const backend = new BarretenbergBackend(circuit);
  const proof = await backend.generateProof(witness);

  // Extraer outputs públicos
  const publicInputs = [
    privateInputs.from_zk,
    privateInputs.to_zk,
    privateInputs.animal_id,
    hashPrice(privateInputs.price)  // Solo hash
  ];

  return { proof, publicInputs };
}

¿Qué pasa aquí?

NAVEGADOR ejecuta circuito Noir:
  ├─ Lee: private_transfer.json (circuito compilado)
  ├─ Inputs: from_zk, to_zk, price (PRIVADOS)
  ├─ Ejecuta: Verificaciones (firma, compromiso, precio)
  ↓
  Genera PRUEBA CRIPTOGRÁFICA:
  ├─ proof = [bytes... bytes... bytes...]
  │   ↳ Esta prueba DEMUESTRA:
  │     "Ejecuté el circuito y pasó todas las verificaciones"
  │   ↳ Pero NO contiene los inputs privados
  ↓
  Extrae PUBLIC INPUTS:
  ├─ from_zk (identidad ZK del vendedor)
  ├─ to_zk (identidad ZK del comprador)
  ├─ animal_id
  └─ price_hash (hash del precio, NO el precio exacto)

⚠️ IMPORTANTE:
- La prueba (proof) es solo bytes criptográficos
- Los inputs privados NUNCA salen del navegador
- Solo se envían: proof + public_inputs
```

---

```
┌──────────────────────────────────────────────────────────────────┐
│ PASO 8: Enviar Prueba a Blockchain                               │
└──────────────────────────────────────────────────────────────────┘

Ubicación: frontend/src/services/animalContractService.ts

async function executePrivateTransfer(animalId, proof, publicInputs) {
  // Conectar wallet
  const wallet = await connect(starknetWallet);

  // Preparar transacción
  const tx = await animalNFTContract.execute_private_transfer_with_proof(
    animalId,
    proof,           // Bytes de la prueba
    publicInputs     // [from_zk, to_zk, animal_id, price_hash]
  );

  // Firmar y enviar
  await wallet.execute(tx);

  // Esperar confirmación
  const receipt = await provider.waitForTransaction(tx.transaction_hash);

  return receipt;
}

Lo que se envía a blockchain:
{
  "to": "0x065f45868a08c394cb54d94a6e4eb08012435b5c...",
  "function": "execute_private_transfer_with_proof",
  "calldata": [
    12345,                    // animal_id
    [bytes, bytes, bytes],    // proof (compilada)
    [1111111111, 2222222222, 12345, hash_precio]  // public_inputs
  ]
}

⚠️ NO se envía:
✗ price = 1500 (privado)
✗ signature (privado)
✗ expected_commitment (privado)
```

---

```
┌──────────────────────────────────────────────────────────────────┐
│ PASO 9: Contrato AnimalNFT Recibe Transacción                    │
└──────────────────────────────────────────────────────────────────┘

Ubicación: starknet/src/components/garaga_proofs.cairo

fn execute_private_transfer_with_proof(
    animal_id: u128,
    proof_data: Array<felt252>,
    public_inputs: Array<felt252>
) {
    // PASO 9.1: Obtener dirección del verificador Garaga
    let verifier_address = self.private_transfer_verifier.read();
    //   ↳ Ejemplo: 0xABC123... (deployado en Paso 5)

    // PASO 9.2: Llamar al verificador Garaga
    let is_valid = IVerifier::at(verifier_address)
        .verify_proof(proof_data, public_inputs);

    // PASO 9.3: Si no es válida, revertir
    assert!(is_valid, "Invalid proof");

    // PASO 9.4: Extraer datos públicos
    let (from_zk, to_zk, animal_id, price_proof) =
        extract_public_inputs(public_inputs);

    // PASO 9.5: Ejecutar transferencia
    transfer_animal(animal_id, from_zk, to_zk);

    // PASO 9.6: Guardar proof hash
    save_proof(animal_id, proof_hash, from_zk, to_zk);
}
```

---

```
┌──────────────────────────────────────────────────────────────────┐
│ PASO 10: Verificador Garaga Verifica la Prueba                   │
└──────────────────────────────────────────────────────────────────┘

Contrato Garaga (0xABC123...):

verify_proof(proof, public_inputs):
  ↓
  VERIFICA CRIPTOGRÁFICAMENTE:
  1. ¿La prueba es matemáticamente válida?
  2. ¿Los public_inputs corresponden a la prueba?
  3. ¿Se ejecutó el circuito correctamente?
  ↓
  Si TODO es correcto:
    return true ✓
  Si algo falla:
    return false ✗
```

---

```
┌──────────────────────────────────────────────────────────────────┐
│ PASO 11: AnimalNFT Completa la Transferencia                     │
└──────────────────────────────────────────────────────────────────┘

Después de verificar la prueba:
  ├─ Extrae: from_zk, to_zk, animal_id
  ├─ Ejecuta: Transferencia de propiedad
  └─ Guarda: Proof hash en storage

Storage actualizado:
{
  "proof_hash": "0xDEF789...",
  "from_zk": 1111111111,
  "to_zk": 2222222222,
  "animal_id": 12345,
  "timestamp": 1700000000,
  "verified": true
}
```

---

```
┌──────────────────────────────────────────────────────────────────┐
│ PASO 12: Blockchain Emite Evento                                 │
└──────────────────────────────────────────────────────────────────┘

Event: PrivateTransferExecuted
{
  "proof_hash": "0xDEF789...",
  "from_zk": 1111111111,
  "to_zk": 2222222222,
  "animal_id": 12345,
  "timestamp": 1700000000
}

LO QUE SE VE EN BLOCKCHAIN:
  ✓ Transferencia confirmada
  ✓ Animal 12345 cambió dueño
  ✓ Prueba criptográfica verificada

LO QUE NO SE VE EN BLOCKCHAIN:
  ✗ Identidades reales
  ✗ Precio exacto (1500)
  ✗ Firma original
  ✗ Datos de compromiso
```

---

## Ejemplo Completo

### Escenario: Productor A vende animal a Productor B

```
┌──────────────────────────────────────────────────────────────────┐
│ EN EL NAVEGADOR DEL PRODUCTOR A                                  │
└──────────────────────────────────────────────────────────────────┘

1. Inputs privados (NUNCA salen del navegador):
   ├─ from_zk = 1111111111  (Identidad Productor A)
   ├─ to_zk = 2222222222    (Identidad Productor B)
   ├─ animal_id = 12345
   ├─ price = 1500          ← SECRETO
   ├─ timestamp = 1700000000
   ├─ signature = 3333333333
   └─ expected_commitment = 4444444444

2. Ejecuta circuito Noir:
   main(1111111111, 2222222222, 12345, 1500, ...)
   ↓
   ├─ Verifica firma:     3333333333 == 3333333333 ✓
   ├─ Verifica compromiso: 4444444444 == 4444444444 ✓
   └─ Verifica precio:     1500 > 0 ✓
   ↓
   Resultado: 1 (válido)

3. Genera prueba criptográfica:
   proof = [bytes compilados]
   public_inputs = [1111111111, 2222222222, 12345, hash(1500)]

┌──────────────────────────────────────────────────────────────────┐
│ TRANSACCIÓN A BLOCKCHAIN                                          │
└──────────────────────────────────────────────────────────────────┘

Productor A envía:
{
  "to": "AnimalNFT (0x065f...)",
  "function": "execute_private_transfer_with_proof",
  "proof": [bytes...],
  "public_inputs": [1111111111, 2222222222, 12345, hash(1500)]
}

⚠️ price=1500 NO se envía

┌──────────────────────────────────────────────────────────────────┐
│ EN BLOCKCHAIN (STARKNET)                                          │
└──────────────────────────────────────────────────────────────────┘

1. AnimalNFT recibe transacción

2. AnimalNFT llama a Verificador Garaga:
   verify_proof([bytes...], [1111111111, 2222222222, 12345, hash])
   ↓
   Verificador: ✓ Prueba válida
   ↓
   Retorna: true

3. AnimalNFT extrae datos:
   from_zk = 1111111111
   to_zk = 2222222222
   animal_id = 12345

4. AnimalNFT ejecuta transferencia:
   transfer_ownership(12345, from=1111111111, to=2222222222)

5. AnimalNFT guarda prueba:
   proof_hash = 0xDEF789...

6. Emite evento:
   PrivateTransferExecuted(0xDEF789..., 1111111111, 2222222222, 12345)

┌──────────────────────────────────────────────────────────────────┐
│ RESULTADO                                                         │
└──────────────────────────────────────────────────────────────────┘

✓ Transferencia confirmada
✓ Animal 12345 ahora es de Productor B
✓ Verificación criptográfica exitosa

Visible en blockchain:
  ✓ Transferencia ocurrió
  ✓ Identidades ZK (números anónimos)
  ✓ Animal ID

NO visible en blockchain:
  ✗ Identidad real de Productor A
  ✗ Identidad real de Productor B
  ✗ Precio pagado (1500)
```

---

## Separación de Responsabilidades

| Componente | Responsabilidad | Dónde ejecuta | Cuándo |
|-----------|----------------|---------------|--------|
| **Noir Circuit** | Define QUÉ verificar | Navegador (genera prueba) | Cada transferencia |
| **Nargo** | Compila Noir a formato matemático | Local (desarrollo) | Una vez |
| **Garaga** | Convierte formato Noir a Cairo | Local (desarrollo) | Una vez |
| **Verificador Cairo** | Verifica pruebas en blockchain | Blockchain | Cada transferencia |
| **AnimalNFT Cairo** | Orquesta el flujo completo | Blockchain | Cada transferencia |

---

## Resumen Visual

```
DESARROLLO (Una vez por circuito)
════════════════════════════════════════════════════════════════

1. Escribir circuito Noir
   circuits/private_transfer/src/main.nr

2. Compilar con Nargo
   $ nargo compile
   → Genera: target/private_transfer.json

3. Generar verificador Cairo con Garaga
   $ garaga gen --system noir --vk target/private_transfer.json
   → Genera: garaga_verifiers/private_transfer_verifier/src/lib.cairo

4. Compilar verificador Cairo
   $ scarb build
   → Genera: target/dev/private_transfer_verifier.contract_class.json

5. Deployar verificador en StarkNet
   $ starkli deploy ...
   → Obtén: Dirección del contrato (0xABC123...)

6. Configurar dirección en AnimalNFT
   $ Llamar: set_private_transfer_verifier(0xABC123...)


PRODUCCIÓN (Cada vez que un usuario transfiere)
════════════════════════════════════════════════════════════════

7. NAVEGADOR: Usuario genera prueba
   ├─ Carga: private_transfer.json
   ├─ Inputs: from_zk, to_zk, price (PRIVADOS)
   ├─ Ejecuta: Circuito Noir
   └─ Genera: proof + public_inputs

8. NAVEGADOR: Envía transacción
   ├─ Destino: AnimalNFT contract
   ├─ Función: execute_private_transfer_with_proof
   └─ Datos: proof + public_inputs (sin inputs privados)

9. BLOCKCHAIN: AnimalNFT recibe transacción
   ├─ Lee: Dirección del verificador Garaga
   └─ Llama: verify_proof(proof, public_inputs)

10. BLOCKCHAIN: Verificador Garaga verifica
    ├─ Valida: Prueba criptográfica
    ├─ Retorna: true/false
    └─ Si true → Continúa, si false → Revierte

11. BLOCKCHAIN: AnimalNFT completa transferencia
    ├─ Extrae: from_zk, to_zk, animal_id
    ├─ Ejecuta: Transferencia de propiedad
    └─ Guarda: Proof hash en storage

12. BLOCKCHAIN: Emite evento
    Event: PrivateTransferExecuted
    ├─ proof_hash: 0xDEF789...
    ├─ from_zk: 1111111111
    ├─ to_zk: 2222222222
    ├─ animal_id: 12345
    └─ timestamp: 1700000000
```

---

## Respuesta a: "¿Cómo se comunican Noir y Garaga?"

### NO se comunican directamente

El flujo es:

```
Noir escribe: main.nr (lógica)
      ↓
Nargo compila: private_transfer.json (matemáticas)
      ↓
Garaga lee: private_transfer.json
Garaga genera: lib.cairo (verificador)
      ↓
Scarb compila: lib.cairo → bytecode
      ↓
Deploy: Verificador en blockchain (0xABC123...)
      ↓
Usuario ejecuta: Noir en navegador → genera proof
      ↓
Usuario envía: proof + public_inputs → AnimalNFT
      ↓
AnimalNFT llama: Verificador (0xABC123...) → verify_proof()
      ↓
Verificador retorna: true/false
```

**Garaga es solo una herramienta de compilación** que convierte circuitos Noir a Cairo.

Una vez deployado:
- **Noir** corre en el navegador del usuario
- **Cairo** corre en blockchain StarkNet
- La **prueba** es el "mensaje" que los conecta

---

## Comandos Útiles

### Compilar circuito Noir
```bash
cd circuits/private_transfer
nargo compile
```

### Generar verificador Cairo con Garaga
```bash
garaga gen \
  --system noir \
  --vk circuits/private_transfer/target/private_transfer.json \
  --output garaga_verifiers/private_transfer_verifier
```

### Compilar verificador Cairo
```bash
cd garaga_verifiers/private_transfer_verifier
scarb build
```

### Deployar verificador
```bash
# Con starkli
starkli declare target/dev/private_transfer_verifier.contract_class.json \
  --network sepolia

starkli deploy <CLASS_HASH> --network sepolia

# Con Garaga
garaga declare \
  --network sepolia \
  --contract target/dev/private_transfer_verifier.contract_class.json

garaga deploy \
  --network sepolia \
  --class-hash <CLASS_HASH>
```

---

## Conclusión

El flujo completo de Zero-Knowledge en BeefChain es:

1. **Desarrollo**: Noir → Nargo → Garaga → Cairo → Deploy
2. **Usuario**: Genera prueba con Noir en navegador
3. **Blockchain**: Verifica prueba con Cairo en StarkNet

**La clave**: Garaga es el puente que permite llevar Zero-Knowledge Proofs desde Noir hasta StarkNet, convirtiendo la lógica ZK en código Cairo verificable en blockchain.

---

**Autor**: BeefChain Team
**Fecha**: Diciembre 2024
**Hackathon**: Zypherpunk - StarkNet Track
