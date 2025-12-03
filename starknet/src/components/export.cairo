/// @title ExportComponent
/// @notice Manages export batches, permits, and temperature tracking
/// @dev Captures exporter workflows so they stay isolated from other business logic

use core::array::Array;
use starknet::storage::Map;
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
use crate::types::animal::ExportData;

/// @title IExportComponent
/// @notice Interface for exporter actions
#[starknet::interface]
pub trait IExportComponent<TContractState> {
    /// @notice Prepare a batch of cuts for export
    /// @param animal_ids List of animal IDs included in the export batch
    /// @param destination_country Country code or identifier for the shipment
    /// @param container_id Reference to the export container
    /// @return batch_id Identifier assigned to the export batch
    fn prepare_export_batch(
        ref self: TContractState,
        animal_ids: Array<u128>,
        destination_country: felt252,
        container_id: felt252,
    ) -> u128;

    /// @notice Confirm the export paperwork and permit
    /// @param batch_id Export batch to confirm
    /// @param export_permit Permit reference provided by the exporter authority
    fn confirm_export(ref self: TContractState, batch_id: u128, export_permit: felt252);

    /// @notice Track temperature readings for the export
    /// @param batch_id Export batch to update
    /// @param temperature Latest recorded temperature (Celsius)
    fn update_export_temperature(ref self: TContractState, batch_id: u128, temperature: i32);

    /// @notice Retrieve metadata for an export batch
    /// @param batch_id Export batch to query
    /// @return ExportData Full export metadata
    fn get_export_data(self: @TContractState, batch_id: u128) -> ExportData;
}

#[starknet::component]
pub mod ExportComponent {
    use super::*;

    #[storage]
    pub struct Storage {
        next_export_batch_id: u128,
        export_batches: Map<u128, ExportData>,
        animal_export_batch: Map<u128, u128>,
        batch_animals_count: Map<u128, u32>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ExportBatchCreated: ExportBatchCreated,
        ExportConfirmed: ExportConfirmed,
        ExportTemperatureUpdated: ExportTemperatureUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ExportBatchCreated {
        pub batch_id: u128,
        pub destination: felt252,
        pub container_id: felt252,
        pub exporter: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ExportConfirmed {
        pub batch_id: u128,
        pub export_permit: felt252,
        pub exporter: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ExportTemperatureUpdated {
        pub batch_id: u128,
        pub min_temperature: i32,
        pub max_temperature: i32,
        pub exporter: ContractAddress,
        pub timestamp: u64,
    }

    const DEFAULT_MIN_TEMPERATURE: i32 = -18;
    const DEFAULT_MAX_TEMPERATURE: i32 = -15;

    #[abi(embed_v0)]
    pub impl ExportImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::IExportComponent<ComponentState<TContractState>> {
        fn prepare_export_batch(
            ref self: ComponentState<TContractState>,
            animal_ids: Array<u128>,
            destination_country: felt252,
            container_id: felt252,
        ) -> u128 {
            let exporter = get_caller_address();
            let batch_id = self.next_export_batch_id.read();
            self.next_export_batch_id.write(batch_id + 1);

            let mut index: u32 = 0;
            let mut count: u32 = 0;
            while index < animal_ids.len() {
                let animal_id = *animal_ids.at(index);
                self.animal_export_batch.write(animal_id, batch_id);
                count += 1;
                index += 1;
            };

            self.batch_animals_count.write(batch_id, count);

            let export_data = ExportData {
                export_date: get_block_timestamp(),
                destination_country,
                export_permit: 0,
                container_id,
                temperature_range: (DEFAULT_MIN_TEMPERATURE, DEFAULT_MAX_TEMPERATURE),
                exporter,
            };

            self.export_batches.write(batch_id, export_data);

            self
                .emit(
                    Event::ExportBatchCreated(
                        ExportBatchCreated {
                            batch_id,
                            destination: destination_country,
                            container_id,
                            exporter,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );

            batch_id
        }

        fn confirm_export(
            ref self: ComponentState<TContractState>, batch_id: u128, export_permit: felt252,
        ) {
            let caller = get_caller_address();
            let export_data = self.export_batches.read(batch_id);
            assert!(export_data.exporter == caller, "Export batch owner mismatch");

            let confirmed_export = ExportData {
                export_date: export_data.export_date,
                destination_country: export_data.destination_country,
                export_permit,
                container_id: export_data.container_id,
                temperature_range: export_data.temperature_range,
                exporter: export_data.exporter,
            };

            self.export_batches.write(batch_id, confirmed_export);

            self
                .emit(
                    Event::ExportConfirmed(
                        ExportConfirmed {
                            batch_id,
                            export_permit,
                            exporter: caller,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn update_export_temperature(
            ref self: ComponentState<TContractState>, batch_id: u128, temperature: i32,
        ) {
            let caller = get_caller_address();
            let export_data = self.export_batches.read(batch_id);
            let (min_temp, max_temp) = export_data.temperature_range;

            let new_min = if temperature < min_temp {
                temperature
            } else {
                min_temp
            };
            let new_max = if temperature > max_temp {
                temperature
            } else {
                max_temp
            };

            let updated_export = ExportData {
                export_date: export_data.export_date,
                destination_country: export_data.destination_country,
                export_permit: export_data.export_permit,
                container_id: export_data.container_id,
                temperature_range: (new_min, new_max),
                exporter: export_data.exporter,
            };

            self.export_batches.write(batch_id, updated_export);

            self
                .emit(
                    Event::ExportTemperatureUpdated(
                        ExportTemperatureUpdated {
                            batch_id,
                            min_temperature: new_min,
                            max_temperature: new_max,
                            exporter: caller,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn get_export_data(self: @ComponentState<TContractState>, batch_id: u128) -> ExportData {
            self.export_batches.read(batch_id)
        }
    }
}
