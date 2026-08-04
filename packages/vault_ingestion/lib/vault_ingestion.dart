/// Durable, offline document-ingestion orchestration.
library;

export 'src/ask/deterministic_ask_engine.dart';
export 'src/automation/offline_automation_engine.dart';
export 'src/backup/blind_backup_destination_engine.dart';
export 'src/coordinator/ingestion_coordinator.dart';
export 'src/desktop/desktop_life_os_engine.dart';
export 'src/emergency/emergency_storage_manager.dart';
export 'src/errors/ingestion_failure.dart';
export 'src/intelligence/on_device_intelligence_engine.dart';
export 'src/model/ingestion_models.dart';
export 'src/multilingual/offline_multilingual_engine.dart';
export 'src/ownership/household_ownership_engine.dart';
export 'src/privacy/flattened_redactor.dart';
export 'src/repository/ingestion_job_repository.dart';
export 'src/thumbnail/thumbnail_generator.dart';
export 'src/transfer/device_to_device_transfer_engine.dart';

/// Package metadata for durable document ingestion.
abstract final class VaultIngestionPackage {
  /// Public API version introduced by Milestone 7.
  static const String apiVersion = '0.8.0';
}
