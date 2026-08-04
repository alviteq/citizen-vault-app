/// Platform-independent Citizen Vault domain models.
library;

export 'src/ask/ask_ownkeep_models.dart';
export 'src/attention/attention_models.dart';
export 'src/automation/automation_engine_models.dart';
export 'src/backup/blind_backup_models.dart';
export 'src/desktop/desktop_life_os_models.dart';
export 'src/emergency/emergency_mode_models.dart';
export 'src/graph/entity_templates.dart';
export 'src/graph/graph_models.dart';
export 'src/graph/life_event_models.dart';
export 'src/ingestion/ingestion_models.dart';
export 'src/intelligence/document_intelligence_models.dart';
export 'src/intelligence/local_intelligence_models.dart';
export 'src/library/document_library_models.dart';
export 'src/multilingual/multilingual_models.dart';
export 'src/ownership/household_ownership_models.dart';
export 'src/packs/smart_pack_models.dart';
export 'src/privacy/privacy_export_models.dart';
export 'src/reminders/reminder_models.dart';
export 'src/transfer/device_transfer_models.dart';

/// Package metadata for the platform-independent domain boundary.
abstract final class VaultDomainPackage {
  /// Package API version introduced by the ingestion milestone.
  static const String apiVersion = '1.0.0';
}
