# AnimalNFT → Animal (Components) Migration Status

This document summarizes the differences between the legacy monolithic contract
`AnimalNFT.cairo` and the new modular `animal.cairo` + components. It also points
out remaining gaps and placeholders.

---

## 1. Interface Coverage (IAnimalNFT vs IAnimal)

Most legacy functions from `IAnimalNFT` are now covered in `IAnimal` and
implemented via components:

- Participant & roles: `register_participant`, `update_participant_info`,
  `get_participant_info`, `grant_role`, `revoke_role`, `renounce_role`,
  `has_role`, `get_role_admin`, `set_role_admin`,
  `get_role_member_count`, `get_role_member_at_index`,
  `get_all_role_members` → **AccessControlComponent** +
  `AnimalImpl` wrappers.

- Producer core: `create_animal`, `create_animal_simple`,
  `update_animal_weight`, `transfer_animal`,
  `transfer_animal_to_frigorifico` (now
  `transfer_animal_to_processing_facility`) → **AnimalCoreComponent** +
  `AnimalImpl`.

- Batch management: `create_animal_batch`, `add_animals_to_batch`,
  `transfer_batch_to_frigorifico` → **ProcessingComponent** (batch APIs)
  + `AnimalImpl` wrappers.

- Producer queries:
  - `get_animals_by_producer` → `get_animals_by_owner` via
    **AnimalCoreComponent**.
  - `get_batches_by_producer` → `get_batches_by_owner` via
    **ProcessingComponent** (same semantics, English name).
  - `get_producer_stats` → `get_owner_statistics` via **AnimalCoreComponent**
    (TODO: replace tuple with a struct).

- Frigorífico: `procesar_animal`, `procesar_batch`, `crear_corte`,
  `crear_cortes_para_batch` → **ProcessingComponent** + `AnimalImpl`.

- IoT & QR: `record_iot_reading`, `get_latest_iot_reading`,
  `get_iot_history_count`, `generate_qr_for_corte`, `generate_qr_for_animal`,
  `generate_qr_for_batch`, `verify_qr_authenticity`, `get_qr_data`,
  `generate_authenticity_proof`, `get_public_consumer_data`,
  `get_verified_consumer_data` → **TelemetryComponent** +
  `AnimalImpl` wrappers.

- Veterinarian:
  `add_health_record`, `quarantine_animal`, `clear_quarantine`,
  `authorize_veterinarian_for_animal`,
  `revoke_veterinarian_authorization`,
  `is_authorized_veterinarian` → **HealthComponent** + `AnimalImpl`
  with caller/owner checks.

- Certifier:
  - `certify_animal`, `certify_corte`, `certify_batch` → **CertificationComponent**
    (records + flags) and **ProcessingComponent** (cut-level flag) +
    `AnimalImpl`.
  - `revoke_certification` → `CertificationImpl::revoke_certification` +
    `AnimalImpl::revoke_certification` (marks animal as not certified and stores
    a revocation reason).

- Exporter:
  - `prepare_export_batch`, `confirm_export`, `update_export_temperature`
    → **ExportComponent** + `AnimalImpl`.
  - `transfer_corte_to_exportador` →
    `AnimalImpl::transfer_cut_to_exporter` +
    `ProcessingImpl::transfer_cut`.
  - `batch_transfer_cortes` →
    `AnimalImpl::batch_transfer_cuts` + `ProcessingImpl::transfer_cut`.
  - `batch_transfer_cortes_para_lote` →
    `AnimalImpl::batch_transfer_cuts_for_batch` +
    `ProcessingImpl::transfer_cut`.

- General views:
  - `get_export_data` → **ExportComponent::get_export_data**.
  - `owner_of`, `token_uri`, `get_animal_data` →
    **AnimalCoreComponent**.
  - `get_num_cortes` → `get_num_meat_cuts` in **AnimalCoreComponent**
    (**TODO**: currently a stub returning `0`; should be wired to
    ProcessingComponent’s cut count).
  - `is_quarantined` → **HealthComponent::is_quarantined**.
  - `get_corte_owner` → `get_cut_owner` in **ProcessingComponent**.
  - `get_animals_in_batch` → **ProcessingComponent::get_animals_in_batch**.
  - `get_batch_for_animal` → **ProcessingComponent::get_batch_for_animal**.
  - `get_info_corte` →
    `AnimalImpl::get_cut_info` reading `MeatCutData` from **ProcessingComponent**.
  - `get_info_animal` →
    `AnimalImpl::get_animal_overview` returning
    `(AnimalData, num_cuts, qr_hash_placeholder)`.
    - **TODO**: use a real `qr_hash` from Telemetry (add `animal_id → qr` index).

- System stats:
  - `get_system_stats` → **AnimalCoreComponent::get_system_statistics`.
  - `get_role_stats` → **AnimalCoreComponent::get_role_statistics`.
  - Both return long tuples.
    - **TODO**: define `SystemStatistics`/`RoleStatistics` structs and switch to
      struct-based returns.

- Audit & analytics:
  - `get_animal_full_history`, `get_corte_full_history`,
    `get_batch_audit_trail` → `AnimalImpl` reading from
    **AuditAnalyticsComponent** storage.
  - `generate_sustainability_report`,
    `get_carbon_footprint_estimate`,
    `get_supply_chain_efficiency` → implemented in `AnimalImpl` using
    AnimalCore + Telemetry + AccessControl.
    - **TODO**: move these analytics into `AuditAnalyticsComponent` or a
      dedicated metrics component.
    - **TODO**: analytics return raw `Array<felt252>` / `u128`.
      Consider defining typed report structs.

- Privacy:
  - `enable_private_mode`, `disable_private_mode`,
    `private_transfer_animal`, `get_privacy_dashboard`,
    `get_zk_identity`, `register_zk_identity`, `verify_proof_status` →
    **PrivacyComponent** + `AnimalImpl` wrappers with owner checks.
  - `private_transfer_animal` ensures:
    - Animal exists and is not quarantined.
    - Caller’s ZK identity matches current owner ZK.
    - Animal is in private mode.
    - Price proof is equal to the demo constant `VALID_PROOF_DEMO`.
    - Transfers real ownership using **AnimalCoreComponent** and updates
      privacy counters/history.
    - **TODO**: long-term, accept real ZK proofs instead of the hackathon
      placeholder.

- Garaga:
  - `verify_zec_sale_with_proof`, `verify_price_with_proof`,
    `execute_private_transfer_with_proof`,
    `get_zec_sale_proof`, `get_price_verification_proof`,
    `get_private_transfer_proof`, `link_animal_to_zec_sale`,
    `is_animal_zec_verified`, `get_animal_zec_proof` → `GaragaProofsComponent`
    + `AnimalImpl` wrappers.
  - `execute_private_transfer_with_proof`:
    - Uses GaragaProofs to verify and store the proof.
    - Then calls `private_transfer_animal` to move ownership and update privacy.
  - Internal helpers `_verify_with_external_verifier` and
    `_extract_*_public_inputs` reproduce the legacy “demo” semantics but do not
    call a real external verifier.
    - **TODO**: replace with real Garaga verifier calls when available.

---

## 2. Key Behavioral Differences and Placeholders

### 2.1. `get_info_animal`

- Legacy: `get_info_animal` returned `(AnimalData, num_cortes, qr_hash)`, where
  `qr_hash` came from a `qr_data: Map<u128, felt252>` (animal → qr).
- New: `get_animal_overview` returns:
  - `AnimalData` via AnimalCore.
  - `num_cuts` via `get_num_meat_cuts` (currently stubbed).
  - `qr_hash = 0` as a placeholder.

**TODO**:
- Add an index in `TelemetryComponent` to map `animal_id` to a “primary”
  QR hash and return it instead of `0`.
- Wire `get_num_meat_cuts` to ProcessingComponent’s `animal_cut_count`.

### 2.2. Tuples vs Structs for Stats

- `get_owner_statistics`, `get_system_statistics`, `get_role_statistics` all
  return long tuples, mirroring the legacy API.
- This is kept intentionally for backward compatibility.

**TODO**:
- Introduce typed structs (`OwnerStatistics`, `SystemStatistics`,
  `RoleStatistics`) and progressively migrate callers to the struct-based
  view, while keeping tuple helpers for ABI compatibility.

### 2.3. Privacy Proofs (`VALID_PROOF_DEMO`)

- Legacy `_verify_price_proof` accepted a hard-coded `VALID_PROOF_DEMO` proof.
- New code preserves this pattern via `PRICE_PROOF_MAGIC` constant in
  PrivacyComponent and uses the same magic value when calling
  `private_transfer_animal` from Garaga entrypoints.

**TODO**:
- Replace `VALID_PROOF_DEMO` with real proof verification once the true ZK
  circuits and verifier contracts are available.
- Consider storing `PriceVerificationProof` hashes from Garaga directly in
  PrivacyComponent instead of reusing a magic constant.

### 2.4. Garaga Ownership Helpers

- Legacy `_validate_animal_ownership_zk` and `_execute_zk_transfer` in
  `AnimalNFT`:
  - Validated the owner’s ZK identity against `PrivacyData`.
  - Executed the actual transfer and updated privacy fields.
- New design:
  - GaragaProofsComponent validates proofs and stores ZK proof data, but
    does not itself move ownership.
  - Ownership and privacy updates are performed entirely by
    `AnimalImpl::private_transfer_animal` + `PrivacyComponent`.

This is an intentional change: components are decoupled and the main contract
orchestrates cross-cutting concerns.

**TODO**:
- Clearly document in code comments that:
  - GaragaProofsComponent is responsible for proof storage/verification.
  - Animal + Privacy components are responsible for state transitions and
    ownership changes.

### 2.5. Cut Transfers Roles

- Legacy functions (`transfer_corte_to_exportador`, `batch_transfer_cortes`,
  `batch_transfer_cortes_para_lote`) enforced:
  - Frigorífico role for the caller.
  - Exporter role for the recipient.
- New functions in `AnimalImpl`:
  - Enforce that the caller is the current `cut_owner`.
  - Do **not yet** enforce specific roles (no `FRIGORIFICO_ROLE` /
    `EXPORTER_ROLE` checks).

**TODO**:
- Use `AccessControlComponent` to enforce:
  - Caller has a frigorífico/processor role.
  - Recipient has exporter role.
  - Mirror the legacy `_check_role` behavior in a modular way.

### 2.6. Audit History Population

- `AuditAnalyticsComponent` has storage and helpers to record:
  - Per-animal history.
  - Per-cut history.
  - Per-batch audit trail.
- New `AnimalImpl` functions can read these histories, but:
  - No current code writes to `_record_animal_history`,
    `_record_cut_history`, or `_record_batch_audit`.

**TODO**:
- Hook `_record_animal_history` into:
  - Animal creation, transfers, quarantine status changes,
    certification, export.
- Hook `_record_cut_history` into:
  - Cut creation, certification, cut transfers.
- Hook `_record_batch_audit` into:
  - Batch creation, transfer to processor, batch processing, batch export.

---

## 3. Missing or Intentionally Deferred Behaviors

### 3.1. Legacy-only Helpers Not Yet Recreated

- Some internal helpers in `AnimalNFT` have not been directly ported as
  standalone functions, because their logic is now handled by components:
  - `_check_role` → replaced by AccessControlComponent + explicit asserts
    in `AnimalImpl` (for PRODUCER_ROLE, etc.).
  - `_transfer_animal_internal` → replaced by `AnimalCoreComponent`’s
    transfer helpers.
  - `_anonymize_sensitive_data` → replaced by TelemetryComponent’s
    public consumer data helpers (still returning generic felts).

**TODO**:
- Ensure that any legacy helper semantics that mattered for business logic
  (especially around access control) are fully represented via
  `AccessControlComponent` and the new components.

### 3.2. Stronger Type-Safety in Analytics

- Legacy analytics APIs return `Array<felt252>` to keep reports simple.
- New implementation keeps this for compatibility, but the code uses more
  typed storage (AnimalData, ParticipantInfo, etc.).

**TODO**:
- Consider defining explicit report structs and dedicated view functions for
  consumers that can handle typed data (e.g., off-chain indexer, GraphQL APIs),
  keeping the `Array<felt252>` helpers as a thin legacy layer.

---

## 4. Summary

- All major public functions from `AnimalNFT.cairo` are now represented in
  `animal.cairo` and routed through dedicated components.
- The semantics for ownership, quarantine, role checks, and core workflows are
  preserved or improved via clearer separation of concerns.
- Remaining differences are mostly:
  - Places where we still use demo proofs or simplified verifiers (privacy,
    Garaga).
  - Tuple-based return types where structs would be cleaner.
  - Missing wiring of audit history writers.
  - Role checks for some of the new wrapper functions (cut transfers).

All these are marked with `TODO` comments in the code or in this document so
we can iterate on them without losing track of what remains to be improved.

