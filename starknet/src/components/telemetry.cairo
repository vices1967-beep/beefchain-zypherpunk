/// @title TelemetryComponent
/// @notice Manages IoT telemetry readings, QR code generation, and consumer-facing data exposure
/// @dev Handles sensor data collection, QR code lifecycle, and public consumer data anonymization

use core::array::Array;
use crate::types::telemetry::{IoTReading, PublicConsumerData, QRData};

/// @title ITelemetryComponent
/// @notice Trait encapsulating telemetry, QR, and consumer data operations
#[starknet::interface]
pub trait ITelemetryComponent<TContractState> {
    // ========== IoT Functions ==========

    fn record_iot_reading(ref self: TContractState, animal_id: u128, reading: IoTReading);

    fn get_latest_iot_reading(
        self: @TContractState, animal_id: u128, reading_type: felt252,
    ) -> IoTReading;

    fn get_iot_history_count(self: @TContractState, animal_id: u128) -> u32;

    // ========== QR Code Functions ==========

    fn generate_qr_for_cut(ref self: TContractState, animal_id: u128, cut_id: u128) -> felt252;

    fn generate_qr_for_animal(ref self: TContractState, animal_id: u128) -> felt252;

    fn generate_qr_for_batch(ref self: TContractState, batch_id: u128) -> felt252;

    fn verify_qr_authenticity(self: @TContractState, qr_hash: felt252) -> bool;

    fn get_qr_data(self: @TContractState, qr_hash: felt252) -> QRData;

    fn generate_authenticity_proof(ref self: TContractState, qr_hash: felt252) -> felt252;

    // ========== Consumer Data Functions ==========

    fn get_public_consumer_data(self: @TContractState, qr_hash: felt252) -> PublicConsumerData;

    fn get_verified_consumer_data(
        self: @TContractState, qr_hash: felt252, authenticity_proof: felt252,
    ) -> (PublicConsumerData, bool, felt252);
}

#[starknet::component]
pub mod TelemetryComponent {
    use starknet::get_block_timestamp;
    use starknet::storage::Map;
    use super::*;

    // ============ STORAGE ============

    #[storage]
    pub struct Storage {
        // IoT readings
        iot_readings: Map<(u128, u32), IoTReading>,
        iot_readings_count: Map<u128, u32>,
        latest_reading_by_type: Map<(u128, felt252), IoTReading>,
        // QR codes
        qr_codes: Map<felt252, QRData>,
        qr_to_animal: Map<felt252, u128>,
        qr_to_cut: Map<felt252, (u128, u128)>,
        qr_to_batch: Map<felt252, u128>,
        next_qr_nonce: u128,
    }

    // ============ EVENTS ============

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        IoTDataRecorded: IoTDataRecorded,
        QRCodeGenerated: QRCodeGenerated,
        ConsumerDataAccessed: ConsumerDataAccessed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IoTDataRecorded {
        pub animal_id: u128,
        pub reading_type: felt252,
        pub device_id: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct QRCodeGenerated {
        pub qr_hash: felt252,
        pub animal_id: u128,
        pub cut_id: u128,
        pub data_type: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ConsumerDataAccessed {
        pub qr_hash: felt252,
        pub animal_id: u128,
        pub timestamp: u64,
    }

    impl TelemetryImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::ITelemetryComponent<ComponentState<TContractState>> {
        // ========== IoT FUNCTIONS ==========

        /// @notice Records a new IoT telemetry reading for an animal
        /// @param animal_id The ID of the animal being monitored
        /// @param reading The IoTReading struct containing sensor data
        /// @dev Requires IOT_ROLE. Stores reading in history and updates latest by type.
        fn record_iot_reading(
            ref self: ComponentState<TContractState>, animal_id: u128, reading: IoTReading,
        ) {
            let count = self.iot_readings_count.read(animal_id);
            self.iot_readings.write((animal_id, count), reading);
            self.iot_readings_count.write(animal_id, count + 1);

            // Update latest reading by type
            self.latest_reading_by_type.write((animal_id, reading.reading_type), reading);

            self
                .emit(
                    Event::IoTDataRecorded(
                        IoTDataRecorded {
                            animal_id: animal_id,
                            reading_type: reading.reading_type,
                            device_id: reading.device_id,
                            timestamp: reading.timestamp,
                        },
                    ),
                );
        }

        /// @notice Retrieves the latest IoT reading of a specific type for an animal
        /// @param animal_id The ID of the animal
        /// @param reading_type The type of reading (e.g., 'TEMPERATURE', 'HUMIDITY')
        /// @return The latest IoTReading of the specified type
        fn get_latest_iot_reading(
            self: @ComponentState<TContractState>, animal_id: u128, reading_type: felt252,
        ) -> IoTReading {
            self.latest_reading_by_type.read((animal_id, reading_type))
        }

        /// @notice Gets the total count of IoT readings recorded for an animal
        /// @param animal_id The ID of the animal
        /// @return The number of readings stored
        fn get_iot_history_count(self: @ComponentState<TContractState>, animal_id: u128) -> u32 {
            self.iot_readings_count.read(animal_id)
        }

        // ========== QR CODE FUNCTIONS ==========

        /// @notice Generates a QR code for a specific meat cut
        /// @param animal_id The ID of the source animal
        /// @param cut_id The ID of the meat cut
        /// @return The generated QR hash
        /// @dev Only frigorifico role can generate cut QR codes.
        fn generate_qr_for_cut(
            ref self: ComponentState<TContractState>, animal_id: u128, cut_id: u128,
        ) -> felt252 {
            let qr_data_str = animal_id.into() + ':' + cut_id.into();
            let qr_hash = self._generate_qr_hash(qr_data_str);

            let qr_data = QRData {
                qr_hash: qr_hash,
                animal_id: animal_id,
                cut_id: cut_id,
                timestamp: get_block_timestamp(),
                data_type: 'CUT',
                metadata: 'Traceable meat cut',
            };

            self.qr_codes.write(qr_hash, qr_data);
            self.qr_to_cut.write(qr_hash, (animal_id, cut_id));

            self
                .emit(
                    Event::QRCodeGenerated(
                        QRCodeGenerated {
                            qr_hash: qr_hash,
                            animal_id: animal_id,
                            cut_id: cut_id,
                            data_type: 'CUT',
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );

            qr_hash
        }

        /// @notice Generates a QR code for an animal
        /// @param animal_id The ID of the animal
        /// @return The generated QR hash
        /// @dev Only producer role can generate animal QR codes.
        fn generate_qr_for_animal(
            ref self: ComponentState<TContractState>, animal_id: u128,
        ) -> felt252 {
            let qr_data_str = animal_id.into() + ':ANIMAL';
            let qr_hash = self._generate_qr_hash(qr_data_str);

            let qr_data = QRData {
                qr_hash: qr_hash,
                animal_id: animal_id,
                cut_id: 0,
                timestamp: get_block_timestamp(),
                data_type: 'ANIMAL',
                metadata: 'Traceable growing animal',
            };

            self.qr_codes.write(qr_hash, qr_data);
            self.qr_to_animal.write(qr_hash, animal_id);

            self
                .emit(
                    Event::QRCodeGenerated(
                        QRCodeGenerated {
                            qr_hash: qr_hash,
                            animal_id: animal_id,
                            cut_id: 0,
                            data_type: 'ANIMAL',
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );

            qr_hash
        }

        /// @notice Generates a QR code for a batch of animals
        /// @param batch_id The ID of the batch
        /// @return The generated QR hash
        /// @dev Only frigorifico role can generate batch QR codes.
        fn generate_qr_for_batch(
            ref self: ComponentState<TContractState>, batch_id: u128,
        ) -> felt252 {
            let qr_data_str = batch_id.into() + ':BATCH';
            let qr_hash = self._generate_qr_hash(qr_data_str);

            let qr_data = QRData {
                qr_hash: qr_hash,
                animal_id: 0,
                cut_id: 0,
                timestamp: get_block_timestamp(),
                data_type: 'BATCH',
                metadata: 'Processed animal batch',
            };

            self.qr_codes.write(qr_hash, qr_data);
            self.qr_to_batch.write(qr_hash, batch_id);

            self
                .emit(
                    Event::QRCodeGenerated(
                        QRCodeGenerated {
                            qr_hash: qr_hash,
                            animal_id: 0,
                            cut_id: 0,
                            data_type: 'BATCH',
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );

            qr_hash
        }

        /// @notice Verifies if a QR code is authentic
        /// @param qr_hash The hash of the QR code to verify
        /// @return true if QR is authentic, false otherwise
        fn verify_qr_authenticity(self: @ComponentState<TContractState>, qr_hash: felt252) -> bool {
            let qr_data = self.qr_codes.read(qr_hash);
            let zero_hash: felt252 = 0;

            if qr_data.qr_hash == zero_hash {
                return false;
            }

            if qr_data.data_type == 'CUT' {
                true
            } else if qr_data.data_type == 'ANIMAL' {
                true
            } else if qr_data.data_type == 'BATCH' {
                true
            } else {
                false
            }
        }

        /// @notice Retrieves the stored QR data for a given QR hash
        /// @param qr_hash The QR code hash
        /// @return The QRData struct containing all QR metadata
        fn get_qr_data(self: @ComponentState<TContractState>, qr_hash: felt252) -> QRData {
            self.qr_codes.read(qr_hash)
        }

        /// @notice Generates an authenticity proof for a QR code
        /// @param qr_hash The QR code hash
        /// @return A proof string indicating the QR type and validity
        fn generate_authenticity_proof(
            ref self: ComponentState<TContractState>, qr_hash: felt252,
        ) -> felt252 {
            let qr_data = self.qr_codes.read(qr_hash);

            if qr_data.data_type == 'CUT' {
                'AUTH_CUT_VALID'
            } else if qr_data.data_type == 'ANIMAL' {
                'AUTH_ANIMAL_VALID'
            } else {
                'INVALID_PROOF'
            }
        }

        // ========== CONSUMER DATA FUNCTIONS ==========

        /// @notice Retrieves anonymized public consumer data for a QR code
        /// @param qr_hash The QR code hash
        /// @return PublicConsumerData with sanitized information for consumers
        fn get_public_consumer_data(
            self: @ComponentState<TContractState>, qr_hash: felt252,
        ) -> PublicConsumerData {
            let qr_data = self.qr_codes.read(qr_hash);

            if qr_data.data_type == 'CUT' {
                PublicConsumerData {
                    breed: 0,
                    birth_date: 0,
                    processing_date: qr_data.timestamp,
                    processing_facility_name: 'Unknown Facility',
                    certifier_name: 'Unknown Certifier',
                    cut_type: 0,
                    cut_weight: 0,
                    certifications: 'PROCESSED',
                    origin_country: 'Uruguay',
                }
            } else if qr_data.data_type == 'ANIMAL' {
                PublicConsumerData {
                    breed: 0,
                    birth_date: qr_data.timestamp,
                    processing_date: 0,
                    processing_facility_name: '',
                    certifier_name: '',
                    cut_type: 0,
                    cut_weight: 0,
                    certifications: 'GROWING',
                    origin_country: 'Uruguay',
                }
            } else {
                PublicConsumerData {
                    breed: 0,
                    birth_date: 0,
                    processing_date: 0,
                    processing_facility_name: '',
                    certifier_name: '',
                    cut_type: 0,
                    cut_weight: 0,
                    certifications: 'DATA_UNAVAILABLE',
                    origin_country: '',
                }
            }
        }

        /// @notice Retrieves verified consumer data with authenticity confirmation
        /// @param qr_hash The QR code hash
        /// @param authenticity_proof The proof to verify QR authenticity
        /// @return Tuple of (PublicConsumerData, is_authentic, proof_hash)
        fn get_verified_consumer_data(
            self: @ComponentState<TContractState>, qr_hash: felt252, authenticity_proof: felt252,
        ) -> (PublicConsumerData, bool, felt252) {
            let public_data = self.get_public_consumer_data(qr_hash);
            let qr_data = self.qr_codes.read(qr_hash);

            let is_authentic = if qr_data.data_type == 'CUT' {
                authenticity_proof == 'AUTH_CUT_VALID'
            } else if qr_data.data_type == 'ANIMAL' {
                authenticity_proof == 'AUTH_ANIMAL_VALID'
            } else {
                false
            };

            (public_data, is_authentic, authenticity_proof)
        }
    }

    // ============ INTERNAL FUNCTIONS ============

    #[generate_trait]
    impl InternalImpl<TContractState> of InternalTrait<TContractState> {
        fn _generate_qr_hash(ref self: ComponentState<TContractState>, data: felt252) -> felt252 {
            let nonce = self.next_qr_nonce.read();
            self.next_qr_nonce.write(nonce + 1);
            data + nonce.into()
        }
    }
}
