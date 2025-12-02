# Legacy Function Mapping

This table tracks which functions from `AnimalNFT.cairo` have already been migrated into the component-based architecture, along with the component that now owns each behavior. Keep this file updated as we port more functions so it’s always clear what remains to migrate.

| Legacy Function (AnimalNFT) | Status | Component | New Function | Notes |
| --- | --- | --- | --- | --- |
| `create_animal` | ✅ | AnimalCoreComponent | `AnimalCoreImpl::create_animal` | Emits `AnimalCreated`. |
| `create_animal_simple` | ✅ | AnimalCoreComponent | `AnimalCoreImpl::create_animal_simple` | |
| `update_animal_weight` | ✅ | AnimalCoreComponent | `AnimalCoreImpl::update_animal_weight` | |
| `transfer_animal` | ✅ | AnimalCoreComponent | `AnimalCoreImpl::transfer_animal` | |
| `transfer_animal_to_processing_facility` | ✅ | AnimalCoreComponent | `AnimalCoreImpl::transfer_animal_to_processing_facility` | |
| `get_animal_data` | ✅ | AnimalCoreComponent | `AnimalCoreImpl::get_animal_data` | |
| `owner_of` | ✅ | AnimalCoreComponent | `AnimalCoreImpl::get_owner_of` | |
| `token_uri` | ✅ | AnimalCoreComponent | `AnimalCoreImpl::get_token_uri` | |
| `get_num_cortes` (stub) | ✅ (placeholder) | AnimalCoreComponent | `AnimalCoreImpl::get_num_meat_cuts` | still returns 0 until ProcessingComponent exists. |
| `is_quarantined` | ✅ | HealthComponent | `HealthImpl::is_quarantined` | Routed via `IHealthComponent` from `animal.cairo`. |
| `get_animals_by_producer` | ✅ | AnimalCoreComponent | `AnimalCoreImpl::get_animals_by_owner` | |
| `get_producer_stats` | ✅ | AnimalCoreComponent | `AnimalCoreImpl::get_owner_statistics` | TODO: replace tuple with struct later. |
| `get_system_stats` | ✅ | AnimalCoreComponent | `AnimalCoreImpl::get_system_statistics` | TODO: wrap tuple. |
| `get_role_stats` | ✅ | AnimalCoreComponent | `AnimalCoreImpl::get_role_statistics` | TODO: wrap tuple. |
| `authorize_veterinarian_for_animal` | ✅ | HealthComponent | `HealthImpl::authorize_veterinarian_for_animal` | Exposed through `IAnimal`. |
| `revoke_veterinarian_authorization` | ✅ | HealthComponent | `HealthImpl::revoke_veterinarian_authorization` | |
| `add_health_record` | ✅ | HealthComponent | `HealthImpl::add_health_record` | |
| `quarantine_animal` | ✅ | HealthComponent | `HealthImpl::quarantine_animal` | |
| `clear_quarantine` | ✅ | HealthComponent | `HealthImpl::clear_quarantine` | |
| `is_authorized_veterinarian` | ✅ | HealthComponent | `HealthImpl::is_authorized_veterinarian` | |
| `create_animal_batch` | ✅ | ProcessingComponent | `ProcessingImpl::create_batch` | |
| `add_animals_to_batch` | ✅ | ProcessingComponent | `ProcessingImpl::add_animals_to_batch` | |
| `transfer_batch_to_frigorifico` | ✅ | ProcessingComponent | `ProcessingImpl::transfer_batch_to_processor` | |
| `get_batch_info` | ✅ | ProcessingComponent | `ProcessingImpl::get_batch_info` | |
| `procesar_animal` | ✅ | ProcessingComponent | `ProcessingImpl::process_animal` | |
| `procesar_batch` | ✅ | ProcessingComponent | `ProcessingImpl::process_batch` | |
| `crear_corte` | ✅ | ProcessingComponent | `ProcessingImpl::create_cut` | |
| `crear_cortes_para_batch` | ✅ | ProcessingComponent | `ProcessingImpl::create_cuts_for_batch` | |
| `certify_animal` | ✅ | CertificationComponent | `CertificationImpl::certify_animal` | |
| `certify_cut` | ✅ | CertificationComponent + ProcessingComponent | `ProcessingImpl::certify_cut`, `CertificationImpl::certify_cut` | |
| `certify_batch` | ✅ | CertificationComponent | `CertificationImpl::certify_batch` | |
| `prepare_export_batch` | ✅ | ExportComponent | `ExportImpl::prepare_export_batch` | Validates certification before enqueueing animals. |
| `confirm_export` | ✅ | ExportComponent | `ExportImpl::confirm_export` | Records exporter permit and emits confirmation event. |
| `update_export_temperature` | ✅ | ExportComponent | `ExportImpl::update_export_temperature` | Tracks min/max shipment temperatures. |
| `get_export_data` | ✅ | ExportComponent | `ExportImpl::get_export_data` | Returns export metadata for batches. |
| `register_participant` | ✅ | AccessControlComponent | `AccessControlComponent::register_participant` | Ensures caller is registered before assign roles. |
| `update_participant_info` | ✅ | AccessControlComponent | `AccessControlComponent::update_participant_info` | Updates metadata for the caller’s participant entry. |
| `get_participant_info` | ✅ | AccessControlComponent | `AccessControlComponent::get_participant_info` | Returns `ParticipantInfo` struct from shared types. |
| `grant_role` | ✅ | AccessControlComponent | `AccessControlComponent::grant_role` | Adds account to role member list, emits events, auto-registers participant. |
| `revoke_role` | ✅ | AccessControlComponent | `AccessControlComponent::revoke_role` | Removes account from role membership & emits event. |
| `renounce_role` | ✅ | AccessControlComponent | `AccessControlComponent::renounce_role` | Allows caller to abandon a role. |
| `has_role` | ✅ | AccessControlComponent | `AccessControlComponent::has_role` | Direct lookup of `(role, account)` map. |
| `get_role_admin` | ✅ | AccessControlComponent | `AccessControlComponent::get_role_admin` | Reads admin role for a given role. |
| `set_role_admin` | ✅ | AccessControlComponent | `AccessControlComponent::set_role_admin` | Requires current admin to change admin role. |
| `get_role_member_count` | ✅ | AccessControlComponent | `AccessControlComponent::get_role_member_count` | Counts members via map. |
| `get_role_member_at_index` | ✅ | AccessControlComponent | `AccessControlComponent::get_role_member_at_index` | Reads indexed member array. |
| `get_all_role_members` | ✅ | AccessControlComponent | `AccessControlComponent::get_all_role_members` | Iterates member array and filters active members. |
| `record_iot_reading` | ✅ | TelemetryComponent | `TelemetryComponent::record_iot_reading` | Stores IoTReading + latest-by-type map. |
| `get_latest_iot_reading` | ✅ | TelemetryComponent | `TelemetryComponent::get_latest_iot_reading` | Reads latest per-type entry. |
| `get_iot_history_count` | ✅ | TelemetryComponent | `TelemetryComponent::get_iot_history_count` | Returns per-animal counter. |
| `generate_qr_for_corte` | ✅ | TelemetryComponent | `TelemetryComponent::generate_qr_for_cut` | Renamed to green english name `generate_qr_for_cut`. |
| `generate_qr_for_animal` | ✅ | TelemetryComponent | `TelemetryComponent::generate_qr_for_animal` | |
| `generate_qr_for_batch` | ✅ | TelemetryComponent | `TelemetryComponent::generate_qr_for_batch` | |
| `verify_qr_authenticity` | ✅ | TelemetryComponent | `TelemetryComponent::verify_qr_authenticity` | |
| `get_qr_data` | ✅ | TelemetryComponent | `TelemetryComponent::get_qr_data` | |
| `generate_authenticity_proof` | ✅ | TelemetryComponent | `TelemetryComponent::generate_authenticity_proof` | |
| `get_public_consumer_data` | ✅ | TelemetryComponent | `TelemetryComponent::get_public_consumer_data` | |
| `get_verified_consumer_data` | ✅ | TelemetryComponent | `TelemetryComponent::get_verified_consumer_data` | |
| `get_batches_by_producer` | ✅ | ProcessingComponent | `ProcessingImpl::get_batches_by_owner` | Exposed via `AnimalImpl::get_batches_by_owner`. |
| `get_animals_in_batch` | ✅ | ProcessingComponent | `ProcessingImpl::get_animals_in_batch` | Also available through `AnimalImpl::get_animals_in_batch`. |
| `get_batch_for_animal` | ✅ | ProcessingComponent | `ProcessingImpl::get_batch_for_animal` | Exposed via `AnimalImpl::get_batch_for_animal`. |
| `get_corte_owner` | ✅ | ProcessingComponent | `ProcessingImpl::get_cut_owner` | Renamed to `get_cut_owner`, exposed via `AnimalImpl::get_cut_owner`. |
| `get_info_corte` | ✅ | ProcessingComponent | `ProcessingImpl::get_cut_info` | Renamed to `get_cut_info`, exposed via `AnimalImpl::get_cut_info`. |
| `get_info_animal` | ✅ (qr placeholder) | AnimalCoreComponent + TelemetryComponent | `AnimalImpl::get_animal_overview` | Returns `(AnimalData, num_cuts, qr_hash)`; `qr_hash` is `0` until a direct animal→QR index is added. |
| `enable_private_mode` | ✅ | PrivacyComponent | `PrivacyImpl::enable_private_mode` | Guarded in `AnimalImpl::enable_private_mode` by owner check. |
| `disable_private_mode` | ✅ | PrivacyComponent | `PrivacyImpl::disable_private_mode` | Guarded in `AnimalImpl::disable_private_mode` by owner check. |
| `private_transfer_animal` | ✅ | PrivacyComponent + AnimalCoreComponent | `AnimalImpl::private_transfer_animal`, `PrivacyImpl::record_private_transfer` | Uses ZK identities from Privacy and `AnimalCoreImpl::transfer_animal` for ownership. |
| `get_privacy_dashboard` | ✅ | PrivacyComponent | `PrivacyImpl::get_privacy_dashboard` | |
| `get_zk_identity` | ✅ | PrivacyComponent | `PrivacyImpl::get_zk_identity` | |
| `register_zk_identity` | ✅ | PrivacyComponent | `PrivacyImpl::register_zk_identity` | Emits `ZKIdentityGenerated`. |
| `verify_proof_status` | ✅ | PrivacyComponent | `PrivacyImpl::verify_proof_status` | Reads `verified_proofs` and `PriceRange` from privacy storage. |
| `verify_zec_sale_with_proof` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::verify_zec_sale_with_proof` | Wrapped by `AnimalImpl::verify_zec_sale_with_proof` with PRODUCER_ROLE + owner checks. |
| `verify_price_with_proof` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::verify_price_with_proof` | Wrapped by `AnimalImpl::verify_price_with_proof` with PRODUCER_ROLE + owner checks. |
| `execute_private_transfer_with_proof` | ✅ | GaragaProofsComponent + PrivacyComponent | `GaragaProofsImpl::execute_private_transfer_with_proof`, `AnimalImpl::execute_private_transfer_with_proof` | Garaga verifies & stores proof; `AnimalImpl` then calls `private_transfer_animal` to move ownership and update privacy. |
| `get_zec_sale_proof` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::get_zec_sale_proof` | Exposed via `AnimalImpl::get_zec_sale_proof`. |
| `get_price_verification_proof` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::get_price_verification_proof` | |
| `get_private_transfer_proof` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::get_private_transfer_proof` | |
| `link_animal_to_zec_sale` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::link_animal_to_zec_sale` | Wrapped by `AnimalImpl::link_animal_to_zec_sale` with PRODUCER_ROLE + owner checks. |
| `is_animal_zec_verified` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::is_animal_zec_verified` | |
| `get_animal_zec_proof` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::get_animal_zec_proof` | |
| `get_animal_full_history` | ✅ | AuditAnalyticsComponent | `AnimalImpl::get_animal_full_history` | Reads history arrays from `audit_analytics` storage node. |
| `get_corte_full_history` | ✅ | AuditAnalyticsComponent | `AnimalImpl::get_cut_full_history` | |
| `get_batch_audit_trail` | ✅ | AuditAnalyticsComponent | `AnimalImpl::get_batch_audit_trail` | |
| `generate_sustainability_report` | ✅ | Animal (or AuditAnalytics future) | `AnimalImpl::generate_sustainability_report` | Uses AnimalCore + Telemetry; TODO: move into component and/or refine metrics. |
| `get_carbon_footprint_estimate` | ✅ | Animal (or AuditAnalytics future) | `AnimalImpl::get_carbon_footprint_estimate` | Reuses legacy formula; TODO: move into component. |
| `get_supply_chain_efficiency` | ✅ | Animal (or AuditAnalytics future) | `AnimalImpl::get_supply_chain_efficiency` | Uses AnimalCore + timestamps; TODO: tune metric and move into component. |
| `revoke_certification` | ✅ | CertificationComponent | `CertificationImpl::revoke_certification` | Exposed via `AnimalImpl::revoke_certification`; TODO: store richer revocation history. |
| `get_certification_data` | ✅ | CertificationComponent | `CertificationImpl::get_certification_data` | |
| `transfer_corte_to_exportador` | ✅ | ProcessingComponent | `ProcessingImpl::transfer_cut` | Exposed via `AnimalImpl::transfer_cut_to_exporter`; TODO: add explicit role checks (frigorifico/exporter). |
| `batch_transfer_cortes` | ✅ | ProcessingComponent | `ProcessingImpl::transfer_cut` | Batch wrapper in `AnimalImpl::batch_transfer_cuts`. |
| `batch_transfer_cortes_para_lote` | ✅ | ProcessingComponent | `ProcessingImpl::transfer_cut` | Batch-per-batch wrapper in `AnimalImpl::batch_transfer_cuts_for_batch`. |
| `get_batches_by_producer` | ✅ | ProcessingComponent | `ProcessingImpl::get_batches_by_owner` | Exposed via `AnimalImpl::get_batches_by_owner`. |
| `get_animals_in_batch` | ✅ | ProcessingComponent | `ProcessingImpl::get_animals_in_batch` | Also available through `AnimalImpl::get_animals_in_batch`. |
| `get_batch_for_animal` | ✅ | ProcessingComponent | `ProcessingImpl::get_batch_for_animal` | Exposed via `AnimalImpl::get_batch_for_animal`. |
| `get_corte_owner` | ✅ | ProcessingComponent | `ProcessingImpl::get_cut_owner` | Renamed to `get_cut_owner`, exposed via `AnimalImpl::get_cut_owner`. |
| `get_info_corte` | ✅ | ProcessingComponent | `ProcessingImpl::get_cut_info` | Renamed to `get_cut_info`, exposed via `AnimalImpl::get_cut_info`. |
| `get_info_animal` | ✅ (qr placeholder) | AnimalCoreComponent + TelemetryComponent | `AnimalImpl::get_animal_overview` | Returns `(AnimalData, num_cuts, qr_hash)`; `qr_hash` is `0` until a direct animal→QR index is added. |
| `enable_private_mode` | ✅ | PrivacyComponent | `PrivacyImpl::enable_private_mode` | Guarded in `AnimalImpl::enable_private_mode` by owner check. |
| `disable_private_mode` | ✅ | PrivacyComponent | `PrivacyImpl::disable_private_mode` | Guarded in `AnimalImpl::disable_private_mode` by owner check. |
| `private_transfer_animal` | ✅ | PrivacyComponent + AnimalCoreComponent | `AnimalImpl::private_transfer_animal`, `PrivacyImpl::record_private_transfer` | Uses ZK identities from Privacy and `AnimalCoreImpl::transfer_animal` for ownership. |
| `get_privacy_dashboard` | ✅ | PrivacyComponent | `PrivacyImpl::get_privacy_dashboard` | |
| `get_zk_identity` | ✅ | PrivacyComponent | `PrivacyImpl::get_zk_identity` | |
| `register_zk_identity` | ✅ | PrivacyComponent | `PrivacyImpl::register_zk_identity` | Emits `ZKIdentityGenerated`. |
| `verify_proof_status` | ✅ | PrivacyComponent | `PrivacyImpl::verify_proof_status` | Reads `verified_proofs` and `PriceRange` from privacy storage. |
| `verify_zec_sale_with_proof` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::verify_zec_sale_with_proof` | Wrapped by `AnimalImpl::verify_zec_sale_with_proof` with PRODUCER_ROLE + owner checks. |
| `verify_price_with_proof` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::verify_price_with_proof` | Wrapped by `AnimalImpl::verify_price_with_proof` with PRODUCER_ROLE + owner checks. |
| `execute_private_transfer_with_proof` | ✅ | GaragaProofsComponent + PrivacyComponent | `GaragaProofsImpl::execute_private_transfer_with_proof`, `AnimalImpl::execute_private_transfer_with_proof` | Garaga verifies & stores proof; `AnimalImpl` then calls `private_transfer_animal` to move ownership and update privacy. |
| `get_zec_sale_proof` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::get_zec_sale_proof` | Exposed via `AnimalImpl::get_zec_sale_proof`. |
| `get_price_verification_proof` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::get_price_verification_proof` | |
| `get_private_transfer_proof` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::get_private_transfer_proof` | |
| `link_animal_to_zec_sale` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::link_animal_to_zec_sale` | Wrapped by `AnimalImpl::link_animal_to_zec_sale` with PRODUCER_ROLE + owner checks. |
| `is_animal_zec_verified` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::is_animal_zec_verified` | |
| `get_animal_zec_proof` | ✅ | GaragaProofsComponent | `GaragaProofsImpl::get_animal_zec_proof` | |

_Status key:_ ✅ = implemented in components and exposed through `animal.cairo`.
