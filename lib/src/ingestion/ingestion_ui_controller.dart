// Named public dependencies intentionally initialize private owned fields.
// ignore_for_file: avoid_positional_boolean_parameters
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';

import 'package:citizen_vault_app/src/ingestion/device_import_picker.dart';
import 'package:citizen_vault_app/src/library/document_file_transfer.dart';
import 'package:citizen_vault_app/src/life/life_graph_search.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vault_database/vault_database.dart'
    hide
        AttentionItem,
        ClaimValue,
        EvidenceLink,
        LifeChecklist,
        LifeEvent,
        LifeTask,
        SmartPack,
        SmartPackItem;
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';
import 'package:vault_notifications/vault_notifications.dart';
import 'package:vault_ocr/vault_ocr.dart';

/// Measured private storage occupied by the unlocked vault.
@immutable
final class VaultStorageSummary {
  /// Creates a storage measurement.
  const VaultStorageSummary({
    required this.databaseBytes,
    required this.objectBytes,
    required this.temporaryBytes,
    required this.otherBytes,
    required this.fileCount,
  });

  /// Creates an empty measurement.
  const VaultStorageSummary.empty()
    : databaseBytes = 0,
      objectBytes = 0,
      temporaryBytes = 0,
      otherBytes = 0,
      fileCount = 0;

  /// SQLCipher database, journal, and shared-memory bytes.
  final int databaseBytes;

  /// Authenticated encrypted object bytes.
  final int objectBytes;

  /// Short-lived private processing and backup bytes.
  final int temporaryBytes;

  /// Protected metadata and other private vault bytes.
  final int otherBytes;

  /// Number of private files included in the measurement.
  final int fileCount;

  /// Total measured private vault bytes.
  int get totalBytes =>
      databaseBytes + objectBytes + temporaryBytes + otherBytes;
}

/// Safe presentation controller for the import and processing screen.
abstract class IngestionUiController extends ChangeNotifier {
  /// Measures encrypted vault, database, and temporary storage.
  Future<VaultStorageSummary> storageSummary() async =>
      const VaultStorageSummary.empty();

  /// Removes expired decrypted leases and interrupted private working files.
  Future<void> cleanTemporaryStorage() async {}

  /// Current document-library results.
  List<DocumentListItemView> get documents => const <DocumentListItemView>[];

  /// Unfiltered encrypted records used by the private life dashboard.
  List<DocumentListItemView> get dashboardDocuments => documents;

  /// Current encrypted tags.
  List<DocumentTagView> get tags => const <DocumentTagView>[];

  /// Current active reminders.
  List<ReminderView> get reminders => const <ReminderView>[];

  /// Current encrypted Life Graph entities.
  List<LifeEntity> get entities => const <LifeEntity>[];

  /// Current encrypted global Life Timeline.
  List<LifeEvent> get events => const <LifeEvent>[];

  /// Current deterministic Needs Attention projection.
  List<AttentionItem> get attentionItems => const <AttentionItem>[];

  /// Current cached graph Claims loaded for Life OS navigation.
  List<LifeClaim> get graphClaims => const <LifeClaim>[];

  /// Current cached derived states loaded for Life OS navigation.
  List<DerivedLifeState> get lifeStatesCache => const <DerivedLifeState>[];

  /// Current open encrypted Tasks.
  List<LifeTask> get tasks => const <LifeTask>[];

  /// Current encrypted Checklists.
  List<LifeChecklist> get checklists => const <LifeChecklist>[];

  /// Current encrypted, versioned Smart Packs.
  List<SmartPack> get smartPacks => const <SmartPack>[];

  /// Current encrypted local preferences.
  VaultPreferencesView get preferences => const VaultPreferencesView.defaults();

  /// Current newest-first durable jobs.
  List<DocumentProcessingView> get jobs;

  /// Current documents requiring user verification.
  List<DocumentReviewView> get reviews;

  /// Whether a picker, registration, or worker operation is active.
  bool get isBusy;

  /// Whether an unlocked vault is currently injected.
  bool get isVaultAvailable;

  /// Keeps the session alive while an approved system picker is active.
  void beginExternalActivity() {}

  /// Releases a matching approved system-picker activity lease.
  void endExternalActivity() {}

  /// Latest safe user-facing status, if any.
  String? get notice;

  /// Imports from the native file picker.
  Future<void> importFile();

  /// Imports a native scanner output without exposing its path to storage.
  Future<void> importCandidate(IngestionCandidate candidate) async {}

  /// Imports from the native gallery picker.
  Future<void> importGalleryImage();

  /// Imports from the camera.
  Future<void> captureImage();

  /// Refreshes durable jobs.
  Future<void> refresh();

  /// Recovers expired jobs and lost Android picker results.
  Future<void> recover();

  /// Confirms or edits one local machine suggestion set.
  Future<void> confirmReview({
    required String documentId,
    required DocumentType documentType,
    required List<ConfirmedFieldEdit> fields,
    String? profileEntityId,
  });

  /// Runs a bounded literal query against the local FTS index.
  Future<List<DocumentSearchResult>> search(String query);

  /// Runs deterministic Life OS search across graph objects and records.
  Future<List<LifeSearchResult>> graphSearch(String query) async =>
      const <LifeSearchResult>[];

  /// Applies library search/filter/sort.
  Future<void> loadDocuments(DocumentLibraryFilter filter) async {}

  /// Loads one document's detail.
  Future<DocumentDetailView?> document(String documentId) async => null;

  /// Loads a bounded metadata-free preview into foreground memory.
  Future<Uint8List?> documentPreview(String documentId) async => null;

  /// Authenticates the complete original into a short-lived private lease.
  Future<DecryptedAssetLease> documentOriginal(
    String documentId, {
    required String mimeType,
  }) => Future<DecryptedAssetLease>.error(
    StateError('Document access requires an unlocked vault.'),
  );

  /// Saves one authenticated original to an explicitly selected destination.
  Future<String> exportDocument(DocumentDetailView detail) async =>
      'Unlock the vault before saving a document copy.';

  /// Saves a flattened, redacted copy with recipient watermark.
  Future<String> exportRedactedDocument(
    DocumentDetailView detail,
    PrivacyExportOptions options,
  ) async => 'Unlock the vault before exporting a redacted document copy.';

  /// Replaces one document's tag set.
  Future<void> replaceTags(String documentId, List<String> names) async {}

  /// Renames a tag, merging an existing normalized duplicate.
  Future<void> renameTag(String tagId, String name) async {}

  /// Deletes a tag without deleting linked documents.
  Future<void> deleteTag(String tagId) async {}

  /// Updates favourite state.
  Future<void> setFavourite(String documentId, bool value) async {}

  /// Updates archive state.
  Future<void> setArchived(String documentId, bool value) async {}

  /// Corrects a document type without replacing its encrypted original.
  Future<void> setDocumentType(String documentId, DocumentType type) async {}

  /// Re-runs OCR/classification locally while preserving the original.
  Future<void> reprocessDocument(String documentId) async {}

  /// Renames one record without changing its encrypted original.
  Future<void> renameDocument(String documentId, String name) async {}

  /// Moves records to recoverable encrypted trash.
  Future<void> moveDocumentsToTrash(Iterable<String> documentIds) async {}

  /// Restores records from encrypted trash.
  Future<void> restoreDocumentsFromTrash(Iterable<String> documentIds) async {}

  /// Updates archive state for several records as one UI operation.
  Future<void> setDocumentsArchived(
    Iterable<String> documentIds,
    bool value,
  ) async {}

  /// Updates favourite state for several records.
  Future<void> setDocumentsFavourite(
    Iterable<String> documentIds,
    bool value,
  ) async {}

  /// Replaces tags for several records.
  Future<void> replaceTagsForDocuments(
    Iterable<String> documentIds,
    List<String> names,
  ) async {}

  /// Creates a local reminder and requests permission at this user action.
  Future<void> createReminder(ReminderDraft draft) async {}

  /// Snoozes a local reminder.
  Future<void> snoozeReminder(String reminderId, Duration duration) async {}

  /// Reschedules a local reminder.
  Future<void> rescheduleReminder(String reminderId, DateTime dueAt) async {}

  /// Completes a local reminder.
  Future<void> completeReminder(String reminderId) async {}

  /// Enables or disables a local reminder.
  Future<void> setReminderEnabled(String reminderId, bool enabled) async {}

  /// Deletes a local reminder.
  Future<void> deleteReminder(String reminderId) async {}

  /// Saves encrypted local preferences.
  Future<void> savePreferences(VaultPreferencesView value) async {}

  /// Creates a generic Life Graph entity from an approved template.
  Future<String?> createEntity({
    required LifeEntityType type,
    required String displayName,
    String? subtype,
  }) async => null;

  /// Edits an entity without replacing its stable identity.
  Future<void> updateEntity({
    required String entityId,
    required String displayName,
    String? subtype,
  }) async {}

  /// Archives or restores an entity while retaining history.
  Future<void> setEntityArchived(String entityId, bool archived) async {}

  /// Reads encrypted non-Claim profile attributes.
  Future<List<LifeEntityAttribute>> entityAttributes(String entityId) async =>
      const <LifeEntityAttribute>[];

  /// Reads one encrypted graph entity by stable id.
  Future<LifeEntity?> entityById(String entityId) async => null;

  /// Writes one encrypted non-Claim profile attribute.
  Future<void> upsertEntityAttribute({
    required String entityId,
    required String key,
    required ClaimValue value,
  }) async {}

  /// Reads auditable entity lifecycle history.
  Future<List<LifeEntityHistoryEvent>> entityHistory(String entityId) async =>
      const <LifeEntityHistoryEvent>[];

  /// Finds same-type, same-name candidates that require user review.
  Future<List<LifeEntity>> duplicateEntityCandidates(LifeEntity entity) async =>
      const <LifeEntity>[];

  /// Archives a confirmed duplicate under a stable primary entity.
  Future<void> mergeEntities({
    required String primaryEntityId,
    required String duplicateEntityId,
  }) async {}

  /// Lists Claim proposals and history for a profile.
  Future<List<LifeClaim>> entityClaims(String entityId) async =>
      const <LifeClaim>[];

  /// Lists profile evidence linked through Claims or Relationships.
  Future<List<EvidenceLink>> entityEvidence(String entityId) async =>
      const <EvidenceLink>[];

  /// Lists profile Relationships.
  Future<List<LifeRelationship>> entityRelationships(String entityId) async =>
      const <LifeRelationship>[];

  /// Confirms or rejects one profile Claim proposal.
  Future<void> reviewEntityClaim(String claimId, ClaimStatus status) async {}

  /// Creates a user-confirmed Relationship between two profiles.
  Future<void> createEntityRelationship({
    required String fromEntityId,
    required String toEntityId,
    required LifeRelationshipType type,
  }) async {}

  /// Confirms or rejects an existing Relationship while retaining history.
  Future<void> reviewEntityRelationship(
    String relationshipId,
    ClaimStatus status,
  ) async {}

  /// Links an existing encrypted record as user-confirmed profile evidence.
  Future<void> linkDocumentEvidence({
    required String entityId,
    required String documentId,
  }) async {}

  /// Lists profiles linked to one encrypted record.
  Future<List<LifeEntity>> entitiesForDocument(String documentId) async =>
      const <LifeEntity>[];

  Future<void> unlinkDocumentEvidence({
    required String entityId,
    required String documentId,
  }) async {}

  /// Suggests possible profiles for an imported record; user must choose.
  Future<List<LifeEntity>> profileMatchCandidates(
    DocumentReviewView review,
  ) async => const <LifeEntity>[];

  /// Lists current and optionally historical Events for one profile.
  Future<List<LifeEvent>> entityEvents(
    String entityId, {
    bool includeHistorical = false,
  }) async => const <LifeEvent>[];

  /// Lists exact encrypted evidence for one Event.
  Future<List<LifeEventEvidence>> eventEvidence(String eventId) async =>
      const <LifeEventEvidence>[];

  /// Creates a user-confirmed temporal Event.
  Future<String?> createEvent({
    required LifeEventType type,
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    int? amountMinorUnits,
    String? currency,
    String? locationEntityId,
    String? notes,
    String? entityId,
    String? documentId,
  }) async => null;

  /// Confirms or rejects an extracted Event proposal.
  Future<void> reviewEvent(String eventId, LifeEventStatus status) async {}

  /// Corrects an Event by superseding it with a confirmed replacement.
  Future<String?> correctEvent({
    required String eventId,
    required LifeEventType type,
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    int? amountMinorUnits,
    String? currency,
    String? locationEntityId,
    String? notes,
  }) async => null;

  /// Calculates confirmed expense totals for a half-open time period.
  Future<List<LifeExpenseTotal>> expenseTotals({
    required DateTime from,
    required DateTime until,
    String? entityId,
  }) async => const <LifeExpenseTotal>[];

  /// Lists explainable calculated states for a profile or the whole vault.
  Future<List<DerivedLifeState>> lifeStates({String? entityId}) async =>
      const <DerivedLifeState>[];

  /// Converts an Attention item into a linked generated Task.
  Future<void> createTaskFromAttention(String attentionId) async {}

  /// Dismisses one Attention item without changing its source fact.
  Future<void> dismissAttention(String attentionId) async {}

  /// Creates a manual or recurring Task.
  Future<void> createTask({
    required String title,
    String? notes,
    DateTime? dueAt,
    String? recurrenceRule,
    String? entityId,
    String? eventId,
    String? documentId,
  }) async {}

  /// Snoozes a Task without changing its due date.
  Future<void> snoozeTask(String taskId, DateTime until) async {}

  /// Reschedules a Task.
  Future<void> rescheduleTask(String taskId, DateTime dueAt) async {}

  /// Completes a Task and creates its next occurrence when recurring.
  Future<void> completeTask(String taskId) async {}

  /// Dismisses a Task while retaining history.
  Future<void> dismissTask(String taskId) async {}

  /// Creates an entity/event/evidence-linked Checklist.
  Future<void> createChecklist({
    required String title,
    required List<String> items,
    String? entityId,
    String? eventId,
    String? evidenceDocumentId,
  }) async {}

  /// Updates a Checklist item.
  Future<void> setChecklistItemCompleted(String itemId, bool completed) async {}

  /// Creates a versioned built-in Smart Pack snapshot.
  Future<void> createSmartPack({
    required String presetId,
    String? title,
    String? entityId,
    bool includeIndiaPack = false,
  }) async {}

  /// Creates a user-defined Smart Pack.
  Future<void> createCustomSmartPack({
    required String title,
    required List<String> items,
    String? entityId,
  }) async {}

  /// Adds a user-defined organizational item.
  Future<void> addSmartPackItem({
    required String packId,
    required String label,
  }) async {}

  /// Customizes applicability without changing any graph fact.
  Future<void> customizeSmartPackItem({
    required String itemId,
    required String label,
    required bool isEnabled,
    required bool isOptional,
    required bool includeInExport,
  }) async {}

  /// Links a Pack item to existing encrypted information.
  Future<void> linkSmartPackItem({
    required String itemId,
    String? claimId,
    String? eventId,
    String? documentId,
    String? taskId,
  }) async {}

  /// Archives a Pack without removing linked facts or evidence.
  Future<void> archiveSmartPack(String packId) async {}

  /// Returns document IDs selected for later export preparation.
  Future<List<String>> smartPackExportDocuments(String packId) async =>
      const <String>[];

  /// Household inventory and ownership engine.
  HouseholdOwnershipEngine get householdEngine => HouseholdOwnershipEngine();

  /// Adds or updates a household asset.
  void addOrUpdateHouseholdAsset(HouseholdAssetRecord asset) {}

  /// Updates a household asset's status.
  void updateHouseholdAssetStatus(
    String assetId,
    HouseholdAssetStatus newStatus,
  ) {}

  /// Logs a cost, maintenance, tax, or repair event for a household asset.
  void logHouseholdEvent(HouseholdEventRecord event) {}

  /// Offline automation engine.
  OfflineAutomationEngine get automationEngine => OfflineAutomationEngine();

  /// Adds or updates an automation rule.
  void addOrUpdateAutomationRule(AutomationRule rule) {}

  /// Toggles rule enablement.
  void toggleAutomationRule(String ruleId, bool isEnabled) {}

  /// Toggles rule preview mode.
  void toggleAutomationPreviewMode(String ruleId, bool isPreviewMode) {}

  /// Evaluates an automation trigger.
  void evaluateAutomationTrigger({
    required AutomationTriggerKind trigger,
    required Map<String, String> payload,
  }) {}

  /// Undoes an automation audit execution.
  bool undoAutomationExecution(String auditId) => false;

  /// Executes deterministic Ask OwnKeep query traversals.
  AskQueryResponse askVault(String query, {AskQueryCategory? category}) {
    return const DeterministicAskEngine().queryVault(
      query: query,
      documents: documents,
      attentionItems: attentionItems,
      householdAssets: householdEngine.assets,
      householdEvents: householdEngine.events,
      smartPacks: smartPacks,
      preferredCategory: category,
    );
  }

  /// Minimized Emergency Storage boundary manager.
  EmergencyStorageManager get emergencyStorage => EmergencyStorageManager();

  /// Records emergency medical card access attempt.
  void recordEmergencyAccess() {}

  /// On-device intelligence engine.
  OnDeviceIntelligenceEngine get intelligenceEngine =>
      OnDeviceIntelligenceEngine();

  /// Offline multilingual UI engine.
  OfflineMultilingualEngine get multilingualEngine =>
      OfflineMultilingualEngine();

  /// Sets UI language.
  void setUiLanguage(SupportedLanguage language) {}

  /// Sets OCR language code.
  void setOcrLanguage(String ocrLanguageCode) {}

  /// Device-to-device encrypted transfer engine.
  DeviceToDeviceTransferEngine get transferEngine =>
      DeviceToDeviceTransferEngine();

  /// Initiates device transfer pairing session.
  TransferPairingSession initiateDeviceTransferPairing(String deviceId) =>
      transferEngine.initiatePairingSession(senderDeviceId: deviceId);

  /// Simulates a device transfer step.
  TransferProgress simulateDeviceTransferStep() {
    final pkg = transferEngine.preparePayloadPackage(
      rawVaultBackupBytesHex: '0102030405060708',
    );
    return transferEngine.updateTransferStep(
      package: pkg,
      completedChunks: pkg.totalChunks,
    );
  }

  /// Blind cloud/NAS backup destination engine.
  BlindBackupDestinationEngine get blindBackupEngine =>
      BlindBackupDestinationEngine();

  /// Configures blind backup destination.
  void configureBlindBackupDestination(BlindBackupConfig config) {}

  /// Triggers blind sync rehearsal.
  BlindBackupSyncStatus triggerBlindSyncRehearsal() => blindBackupEngine
      .triggerBlindSync(encryptedArchiveBytesHex: '0102030405060708');

  /// Desktop Personal Life OS engine.
  DesktopLifeOsEngine get desktopEngine => DesktopLifeOsEngine();

  /// Sets desktop layout mode.
  void setDesktopLayoutMode(DesktopLayoutMode mode) {}

  /// Toggles desktop sidebar.
  void toggleDesktopSidebar() {}

  /// Processes desktop bulk import.
  BulkImportJobProgress processDesktopBulkImport(List<String> filePaths) =>
      desktopEngine.processBulkImport(filePaths: filePaths);
}

/// Honest default until onboarding/unlock composes a secure vault session.
final class LockedIngestionUiController extends IngestionUiController {
  @override
  bool get isBusy => false;

  @override
  bool get isVaultAvailable => false;

  @override
  List<DocumentProcessingView> get jobs => const <DocumentProcessingView>[];

  @override
  List<DocumentReviewView> get reviews => const <DocumentReviewView>[];

  @override
  String? get notice => 'Create or unlock your vault before importing.';

  @override
  Future<void> captureImage() async {}

  @override
  Future<void> confirmReview({
    required String documentId,
    required DocumentType documentType,
    required List<ConfirmedFieldEdit> fields,
    String? profileEntityId,
  }) async {}

  @override
  Future<void> importFile() async {}

  @override
  Future<void> importCandidate(IngestionCandidate candidate) async {}

  @override
  Future<void> importGalleryImage() async {}

  @override
  Future<void> recover() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<List<DocumentSearchResult>> search(String query) async =>
      const <DocumentSearchResult>[];

  @override
  Future<List<LifeSearchResult>> graphSearch(String query) async =>
      const <LifeSearchResult>[];
}

/// Controller used after secure composition supplies an unlocked coordinator.
final class UnlockedIngestionUiController extends IngestionUiController {
  /// Creates the controller and native picker adapter.
  UnlockedIngestionUiController({
    required IngestionCoordinator coordinator,
    required SqlCipherDocumentLibrary library,
    required SqlCipherLifeGraphRepository graph,
    required ReminderCoordinator reminders,
    required Directory vaultRoot,
    SqlCipherAttentionRepository? attention,
    SqlCipherSmartPackRepository? smartPacks,
    ImportPicker? picker,
    DocumentFileTransfer? documentTransfer,
    this.workerId = 'foreground-ui',
  }) : _coordinator = coordinator,
       _library = library,
       _graph = graph,
       _attention =
           attention ??
           SqlCipherAttentionRepository(graph.session, graph.random),
       _smartPackRepository =
           smartPacks ??
           SqlCipherSmartPackRepository(graph.session, graph.random),
       _reminderCoordinator = reminders,
       _vaultRoot = vaultRoot,
       _picker = picker ?? DeviceImportPicker(),
       _documentTransfer =
           documentTransfer ?? const PlatformDocumentFileTransfer() {
    _restoreSavedLanguage();
  }

  final IngestionCoordinator _coordinator;
  final SqlCipherDocumentLibrary _library;
  final SqlCipherLifeGraphRepository _graph;
  final SqlCipherAttentionRepository _attention;
  final SqlCipherSmartPackRepository _smartPackRepository;
  final ReminderCoordinator _reminderCoordinator;
  final Directory _vaultRoot;
  final ImportPicker _picker;
  final DocumentFileTransfer _documentTransfer;

  /// Stable foreground worker identifier.
  final String workerId;

  var _jobs = const <DocumentProcessingView>[];
  var _reviews = const <DocumentReviewView>[];
  var _documents = const <DocumentListItemView>[];
  var _dashboardDocuments = const <DocumentListItemView>[];
  var _tags = const <DocumentTagView>[];
  var _reminders = const <ReminderView>[];
  var _entities = const <LifeEntity>[];
  var _events = const <LifeEvent>[];
  var _attentionItems = const <AttentionItem>[];
  var _graphClaims = const <LifeClaim>[];
  var _lifeStates = const <DerivedLifeState>[];
  var _tasks = const <LifeTask>[];
  var _checklists = const <LifeChecklist>[];
  var _smartPacks = const <SmartPack>[];
  var _entityAttributesById = <String, List<LifeEntityAttribute>>{};
  var _preferences = const VaultPreferencesView.defaults();
  var _filter = const DocumentLibraryFilter();
  final _householdEngine = HouseholdOwnershipEngine(
    initialAssets: const <HouseholdAssetRecord>[],
    initialEvents: const <HouseholdEventRecord>[],
  );
  var _isBusy = false;
  var _externalActivityCount = 0;
  String? _notice;
  Timer? _processingRetryTimer;

  @override
  void dispose() {
    _processingRetryTimer?.cancel();
    super.dispose();
  }

  @override
  Future<VaultStorageSummary> storageSummary() async {
    var databaseBytes = 0;
    var objectBytes = 0;
    var temporaryBytes = 0;
    var otherBytes = 0;
    var fileCount = 0;

    if (!_vaultRoot.existsSync()) return const VaultStorageSummary.empty();
    await for (final entity in _vaultRoot.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      int bytes;
      try {
        bytes = await entity.length();
      } on FileSystemException {
        continue;
      }
      fileCount += 1;
      final relative = entity.path.substring(_vaultRoot.path.length + 1);
      if (relative == 'vault.db' ||
          relative == 'vault.db-wal' ||
          relative == 'vault.db-shm') {
        databaseBytes += bytes;
      } else if (relative.startsWith('objects${Platform.pathSeparator}')) {
        objectBytes += bytes;
      } else if (relative.startsWith('temporary${Platform.pathSeparator}')) {
        temporaryBytes += bytes;
      } else {
        otherBytes += bytes;
      }
    }
    return VaultStorageSummary(
      databaseBytes: databaseBytes,
      objectBytes: objectBytes,
      temporaryBytes: temporaryBytes,
      otherBytes: otherBytes,
      fileCount: fileCount,
    );
  }

  @override
  Future<void> cleanTemporaryStorage() => _libraryAction(() async {
    await _coordinator.recover();
    _notice = 'Temporary private files cleaned safely.';
  });

  @override
  bool get isBusy => _isBusy || _externalActivityCount > 0;

  @override
  bool get isVaultAvailable => true;

  @override
  void beginExternalActivity() {
    _externalActivityCount += 1;
    notifyListeners();
  }

  @override
  void endExternalActivity() {
    if (_externalActivityCount == 0) return;
    _externalActivityCount -= 1;
    notifyListeners();
  }

  @override
  HouseholdOwnershipEngine get householdEngine => _householdEngine;

  @override
  void addOrUpdateHouseholdAsset(HouseholdAssetRecord asset) {
    _householdEngine.addOrUpdateAsset(asset);
    notifyListeners();
  }

  @override
  void updateHouseholdAssetStatus(
    String assetId,
    HouseholdAssetStatus newStatus,
  ) {
    _householdEngine.updateAssetStatus(assetId, newStatus);
    notifyListeners();
  }

  @override
  void logHouseholdEvent(HouseholdEventRecord event) {
    _householdEngine.logEvent(event);
    evaluateAutomationTrigger(
      trigger: AutomationTriggerKind.householdEventLogged,
      payload: <String, String>{
        'eventType': event.eventType.name,
        'assetId': event.assetId,
        'title': event.title,
        if (event.cost != null) 'cost': event.cost!.toString(),
      },
    );
    notifyListeners();
  }

  final _automationEngine = OfflineAutomationEngine();

  @override
  OfflineAutomationEngine get automationEngine => _automationEngine;

  @override
  void addOrUpdateAutomationRule(AutomationRule rule) {
    _automationEngine.addOrUpdateRule(rule);
    notifyListeners();
  }

  @override
  void toggleAutomationRule(String ruleId, bool isEnabled) {
    _automationEngine.toggleRule(ruleId, isEnabled: isEnabled);
    notifyListeners();
  }

  @override
  void toggleAutomationPreviewMode(String ruleId, bool isPreviewMode) {
    _automationEngine.togglePreviewMode(ruleId, isPreviewMode: isPreviewMode);
    notifyListeners();
  }

  @override
  void evaluateAutomationTrigger({
    required AutomationTriggerKind trigger,
    required Map<String, String> payload,
  }) {
    _automationEngine.evaluateTrigger(trigger: trigger, payload: payload);
    notifyListeners();
  }

  @override
  bool undoAutomationExecution(String auditId) {
    final res = _automationEngine.undoExecution(auditId);
    if (res) notifyListeners();
    return res;
  }

  final _emergencyStorage = EmergencyStorageManager(
    initialEnvelope: EmergencyCardEnvelope(
      medicalRecord: const EmergencyMedicalRecord(
        fullName: '',
        bloodGroup: '',
        allergies: '',
        medications: '',
        doctorName: '',
        doctorPhone: '',
        insuranceProvider: '',
        insurancePolicyNumber: '',
      ),
      contacts: const <EmergencyContact>[],
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isEnabled: false,
    ),
  );

  @override
  EmergencyStorageManager get emergencyStorage => _emergencyStorage;

  @override
  void recordEmergencyAccess() {
    _emergencyStorage.recordAccessEvent();
    notifyListeners();
  }

  final _intelligenceEngine = OnDeviceIntelligenceEngine();
  final _multilingualEngine = OfflineMultilingualEngine();
  final _transferEngine = DeviceToDeviceTransferEngine();

  @override
  OnDeviceIntelligenceEngine get intelligenceEngine => _intelligenceEngine;

  @override
  OfflineMultilingualEngine get multilingualEngine => _multilingualEngine;

  @override
  void setUiLanguage(SupportedLanguage language) {
    _multilingualEngine.setUiLanguage(language);
    unawaited(_saveLanguagePreference(language.code));
    notifyListeners();
  }

  Future<void> _saveLanguagePreference(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ownkeep_ui_language', code);
    } on Object catch (_) {
      // Safe fallback in test environments without native channel plugins.
    }
  }

  void _restoreSavedLanguage() {
    unawaited(_loadLanguagePreference());
  }

  Future<void> _loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('ownkeep_ui_language');
      if (code != null && code.isNotEmpty) {
        _multilingualEngine.loadSavedLanguage(code);
      }
      final ocrCode = prefs.getString('ownkeep_ocr_language');
      if (ocrCode != null &&
          _multilingualEngine.availableOcrPacks.any(
            (pack) => pack.code == ocrCode,
          )) {
        _multilingualEngine.setOcrLanguage(ocrCode);
      }
      notifyListeners();
    } on Object catch (_) {
      // Safe fallback in test environments without native channel plugins.
    }
  }

  @override
  void setOcrLanguage(String ocrLanguageCode) {
    _multilingualEngine.setOcrLanguage(ocrLanguageCode);
    unawaited(_saveOcrLanguagePreference(ocrLanguageCode));
    notifyListeners();
  }

  Future<void> _saveOcrLanguagePreference(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ownkeep_ocr_language', code);
    } on Object catch (_) {
      // Safe fallback in test environments without native channel plugins.
    }
  }

  @override
  DeviceToDeviceTransferEngine get transferEngine => _transferEngine;

  final _blindBackupEngine = BlindBackupDestinationEngine();
  final _desktopEngine = DesktopLifeOsEngine();

  @override
  BlindBackupDestinationEngine get blindBackupEngine => _blindBackupEngine;

  @override
  void configureBlindBackupDestination(BlindBackupConfig config) {
    _blindBackupEngine.activeConfig = config;
    notifyListeners();
  }

  @override
  DesktopLifeOsEngine get desktopEngine => _desktopEngine;

  @override
  void setDesktopLayoutMode(DesktopLayoutMode mode) {
    _desktopEngine.setLayoutMode(mode);
    notifyListeners();
  }

  @override
  void toggleDesktopSidebar() {
    _desktopEngine.toggleSidebar();
    notifyListeners();
  }

  @override
  List<DocumentProcessingView> get jobs => _jobs;

  @override
  List<DocumentReviewView> get reviews => _reviews;

  @override
  List<DocumentListItemView> get documents => _documents;

  @override
  List<DocumentListItemView> get dashboardDocuments => _dashboardDocuments;

  @override
  List<DocumentTagView> get tags => _tags;

  @override
  List<ReminderView> get reminders => _reminders;

  @override
  List<LifeEntity> get entities => _entities;

  @override
  List<LifeEvent> get events => _events;

  @override
  List<AttentionItem> get attentionItems => _attentionItems;

  @override
  List<LifeClaim> get graphClaims => _graphClaims;

  @override
  List<DerivedLifeState> get lifeStatesCache => _lifeStates;

  @override
  List<LifeTask> get tasks => _tasks;

  @override
  List<LifeChecklist> get checklists => _checklists;

  @override
  List<SmartPack> get smartPacks => _smartPacks;

  @override
  VaultPreferencesView get preferences => _preferences;

  @override
  String? get notice => _notice;

  @override
  Future<void> importFile() => _pickAndImport(_picker.pickFile);

  @override
  Future<void> importCandidate(IngestionCandidate candidate) =>
      _import(candidate);

  @override
  Future<void> importGalleryImage() => _pickAndImport(_picker.pickGalleryImage);

  @override
  Future<void> captureImage() => _pickAndImport(_picker.captureImage);

  @override
  Future<void> recover() async {
    await _run(() async {
      await _coordinator.recover();
      await _reminderCoordinator.initializeAndReconcile();
      final lost = await _picker.recoverLostImages();
      for (final candidate in lost) {
        await _coordinator.import(candidate);
      }
      await _coordinator.processUntilIdle(workerId: workerId);
      _notice = lost.isEmpty ? null : 'Recovered ${lost.length} import(s).';
    });
  }

  @override
  Future<void> refresh() async {
    _jobs = await _coordinator.listJobs();
    _reviews = await _coordinator.listReviews();
    await _refreshLibrary();
    notifyListeners();
  }

  @override
  Future<void> confirmReview({
    required String documentId,
    required DocumentType documentType,
    required List<ConfirmedFieldEdit> fields,
    String? profileEntityId,
  }) => _run(() async {
    final review = _reviews
        .where((candidate) => candidate.documentId == documentId)
        .firstOrNull;
    await _coordinator.confirmReview(
      documentId: documentId,
      documentType: documentType,
      fields: fields,
    );
    if (profileEntityId != null && review != null) {
      await _suggestProfileClaims(profileEntityId, review, fields);
    }
    if (review != null) {
      await _suggestDocumentEvents(
        review,
        fields,
        profileEntityId: profileEntityId,
      );
    }
    _notice = 'Verified details saved locally.';
  });

  @override
  Future<List<DocumentSearchResult>> search(String query) =>
      _coordinator.search(query);

  @override
  Future<List<LifeSearchResult>> graphSearch(String query) async {
    final documents = await search(query);
    return LifeGraphSearch.build(
      query: query,
      entities: _entities,
      attributesByEntityId: _entityAttributesById,
      claims: _graphClaims,
      events: _events,
      states: _lifeStates,
      attentionItems: _attentionItems,
      tasks: _tasks,
      smartPacks: _smartPacks,
      documents: documents,
    );
  }

  @override
  Future<void> loadDocuments(DocumentLibraryFilter filter) async {
    _filter = filter;
    _documents = await _library.listDocuments(filter);
    notifyListeners();
  }

  @override
  Future<DocumentDetailView?> document(String documentId) =>
      _library.document(documentId);

  @override
  Future<Uint8List?> documentPreview(String documentId) =>
      _coordinator.preview(documentId);

  @override
  Future<DecryptedAssetLease> documentOriginal(
    String documentId, {
    required String mimeType,
  }) async {
    if (_isBusy) {
      throw StateError('Another vault operation is active.');
    }
    _isBusy = true;
    notifyListeners();
    try {
      return await _coordinator.originalLease(
        documentId,
        suffix: _suffixFor(mimeType),
      );
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  Future<String> exportDocument(DocumentDetailView detail) async {
    if (_isBusy) return 'Another vault operation is still active.';
    _isBusy = true;
    _notice = null;
    notifyListeners();
    DecryptedAssetLease? lease;
    try {
      lease = await _coordinator.originalLease(
        detail.summary.id,
        suffix: _suffixFor(detail.summary.mimeType),
      );
      final saved = await lease.usePrivatePath(
        (path) => _documentTransfer.exportDocument(
          source: File(path),
          suggestedName: detail.summary.logicalFilename,
          mimeType: detail.summary.mimeType,
        ),
      );
      return saved
          ? 'Document copy saved. It is no longer protected by OwnKeep.'
          : 'Save cancelled. No plaintext copy was created.';
    } on DocumentFileTransferFailure {
      return 'The document copy could not be saved to that location.';
    } on Object {
      return 'The original could not be opened safely.';
    } finally {
      await lease?.close();
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  Future<String> exportRedactedDocument(
    DocumentDetailView detail,
    PrivacyExportOptions options,
  ) async {
    if (_isBusy) return 'Another vault operation is still active.';
    _isBusy = true;
    _notice = null;
    notifyListeners();
    DecryptedAssetLease? lease;
    try {
      lease = await _coordinator.originalLease(
        detail.summary.id,
        suffix: _suffixFor(detail.summary.mimeType),
      );
      final rawBytes = await lease.usePrivatePath(
        (path) => File(path).readAsBytes(),
      );
      const redactor = FlattenedRedactor();
      final redactedBytes = redactor.redactAndFlatten(
        inputBytes: rawBytes,
        options: options,
      );
      final tempDir = await Directory.systemTemp.createTemp('ownkeep_redact_');
      final name = detail.summary.logicalFilename.replaceAll('.', '_redacted.');
      final tempFile = File('${tempDir.path}/$name.png');
      await tempFile.writeAsBytes(redactedBytes);
      try {
        final saved = await _documentTransfer.exportDocument(
          source: tempFile,
          suggestedName: name,
          mimeType: 'image/png',
        );
        return saved
            ? 'Redacted copy exported. It cannot be remotely revoked.'
            : 'Export cancelled. No redacted copy was exported.';
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    } on UnsupportedRedactionInputFailure {
      return 'This file format cannot be safely redacted yet. No copy was exported.';
    } on DocumentFileTransferFailure {
      return 'The redacted copy could not be exported to that location.';
    } on Object {
      return 'The original could not be opened safely for redaction.';
    } finally {
      await lease?.close();
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  Future<void> replaceTags(String documentId, List<String> names) =>
      _libraryAction(() => _library.replaceTags(documentId, names));

  @override
  Future<void> renameTag(String tagId, String name) =>
      _libraryAction(() => _library.renameTag(tagId, name));

  @override
  Future<void> deleteTag(String tagId) =>
      _libraryAction(() => _library.deleteTag(tagId));

  @override
  Future<void> setFavourite(String documentId, bool value) =>
      _libraryAction(() => _library.setFavourite(documentId, value));

  @override
  Future<void> setArchived(String documentId, bool value) =>
      _libraryAction(() => _library.setArchived(documentId, value));

  @override
  Future<void> setDocumentType(String documentId, DocumentType type) =>
      _libraryAction(() => _library.setDocumentType(documentId, type));

  @override
  Future<void> reprocessDocument(String documentId) => _libraryAction(
    () => _coordinator.reprocessDocument(
      documentId: documentId,
      workerId: workerId,
    ),
  );

  @override
  Future<void> renameDocument(String documentId, String name) =>
      _libraryAction(() => _library.rename(documentId, name));

  @override
  Future<void> moveDocumentsToTrash(Iterable<String> documentIds) =>
      _libraryAction(() async {
        for (final id in documentIds.toSet()) {
          await _library.moveToTrash(id);
        }
      });

  @override
  Future<void> restoreDocumentsFromTrash(Iterable<String> documentIds) =>
      _libraryAction(() async {
        for (final id in documentIds.toSet()) {
          await _library.restoreFromTrash(id);
        }
      });

  @override
  Future<void> setDocumentsArchived(Iterable<String> documentIds, bool value) =>
      _libraryAction(() async {
        for (final id in documentIds.toSet()) {
          await _library.setArchived(id, value);
        }
      });

  @override
  Future<void> setDocumentsFavourite(
    Iterable<String> documentIds,
    bool value,
  ) => _libraryAction(() async {
    for (final id in documentIds.toSet()) {
      await _library.setFavourite(id, value);
    }
  });

  @override
  Future<void> replaceTagsForDocuments(
    Iterable<String> documentIds,
    List<String> names,
  ) => _libraryAction(() async {
    for (final id in documentIds.toSet()) {
      await _library.replaceTags(id, names);
    }
  });

  @override
  Future<void> createReminder(ReminderDraft draft) => _libraryAction(() async {
    final reminder = await _reminderCoordinator.create(draft);
    _notice = reminder.isEnabled
        ? 'Reminder scheduled on this device.'
        : 'Reminder saved, but notifications are not permitted.';
  });

  @override
  Future<void> snoozeReminder(String reminderId, Duration duration) =>
      _libraryAction(() => _reminderCoordinator.snooze(reminderId, duration));

  @override
  Future<void> rescheduleReminder(String reminderId, DateTime dueAt) =>
      _libraryAction(() => _reminderCoordinator.reschedule(reminderId, dueAt));

  @override
  Future<void> completeReminder(String reminderId) =>
      _libraryAction(() => _reminderCoordinator.complete(reminderId));

  @override
  Future<void> setReminderEnabled(String reminderId, bool enabled) =>
      _libraryAction(
        () => _reminderCoordinator.setEnabled(reminderId, enabled),
      );

  @override
  Future<void> deleteReminder(String reminderId) =>
      _libraryAction(() => _reminderCoordinator.delete(reminderId));

  @override
  Future<void> savePreferences(VaultPreferencesView value) =>
      _libraryAction(() => _library.savePreferences(value));

  @override
  Future<String?> createEntity({
    required LifeEntityType type,
    required String displayName,
    String? subtype,
  }) async {
    String? createdId;
    await _libraryAction(() async {
      createdId = await _graph.createEntity(
        type: type,
        displayName: displayName,
        subtype: subtype,
      );
      _notice = '${EntityTemplateRegistry.forType(type).singularLabel} saved.';
    });
    return createdId;
  }

  @override
  Future<void> updateEntity({
    required String entityId,
    required String displayName,
    String? subtype,
  }) => _libraryAction(
    () => _graph.updateEntity(
      entityId: entityId,
      displayName: displayName,
      subtype: subtype,
    ),
  );

  @override
  Future<void> setEntityArchived(String entityId, bool archived) =>
      _libraryAction(() => _graph.setEntityArchived(entityId, archived));

  @override
  Future<List<LifeEntityAttribute>> entityAttributes(String entityId) =>
      _entityAttributesById.containsKey(entityId)
      ? Future<List<LifeEntityAttribute>>.value(
          _entityAttributesById[entityId]!,
        )
      : _graph.entityAttributes(entityId);

  @override
  Future<LifeEntity?> entityById(String entityId) async =>
      _entities.where((entity) => entity.id == entityId).firstOrNull ??
      _graph.entity(entityId);

  @override
  Future<void> upsertEntityAttribute({
    required String entityId,
    required String key,
    required ClaimValue value,
  }) => _libraryAction(
    () => _graph.upsertEntityAttribute(
      entityId: entityId,
      key: key,
      value: value,
    ),
  );

  @override
  Future<List<LifeEntityHistoryEvent>> entityHistory(String entityId) =>
      _graph.entityHistory(entityId);

  @override
  Future<List<LifeEntity>> duplicateEntityCandidates(LifeEntity entity) =>
      _graph.duplicateCandidates(
        type: entity.type,
        displayName: entity.displayName,
        excludingId: entity.id,
      );

  @override
  Future<void> mergeEntities({
    required String primaryEntityId,
    required String duplicateEntityId,
  }) => _libraryAction(
    () => _graph.mergeEntities(
      primaryEntityId: primaryEntityId,
      duplicateEntityId: duplicateEntityId,
    ),
  );

  @override
  Future<List<LifeClaim>> entityClaims(String entityId) =>
      _graph.claimsForEntity(entityId);

  @override
  Future<List<EvidenceLink>> entityEvidence(String entityId) =>
      _graph.evidenceForEntity(entityId);

  @override
  Future<List<LifeRelationship>> entityRelationships(String entityId) =>
      _graph.relationshipsForEntity(entityId);

  @override
  Future<void> reviewEntityClaim(String claimId, ClaimStatus status) =>
      _libraryAction(() async {
        await _graph.setClaimStatus(claimId, status);
        if (status == ClaimStatus.confirmed) {
          await _suggestEventFromClaim(claimId);
        }
      });

  @override
  Future<void> createEntityRelationship({
    required String fromEntityId,
    required String toEntityId,
    required LifeRelationshipType type,
  }) => _libraryAction(() async {
    final provenance = await _graph.createProvenance(
      sourceType: ProvenanceSourceType.userEntered,
      confidence: 1,
      confidenceSource: 'USER',
    );
    final relationship = await _graph.suggestRelationship(
      fromEntityId: fromEntityId,
      toEntityId: toEntityId,
      type: type,
      provenanceId: provenance,
    );
    await _graph.setRelationshipStatus(relationship, ClaimStatus.confirmed);
  });

  @override
  Future<void> reviewEntityRelationship(
    String relationshipId,
    ClaimStatus status,
  ) => _libraryAction(
    () => _graph.setRelationshipStatus(relationshipId, status),
  );

  @override
  Future<void> linkDocumentEvidence({
    required String entityId,
    required String documentId,
  }) => _libraryAction(() async {
    final provenance = await _graph.createProvenance(
      sourceType: ProvenanceSourceType.userEntered,
      sourceDocumentId: documentId,
      confidence: 1,
      confidenceSource: 'USER',
    );
    final claim = await _graph.suggestClaim(
      subjectEntityId: entityId,
      predicate: 'SUPPORTING_DOCUMENT',
      value: ClaimValue.identifier(documentId),
      cardinality: ClaimCardinality.multipleCurrent,
      provenanceId: provenance,
    );
    await _graph.setClaimStatus(claim, ClaimStatus.confirmed);
    await _graph.addEvidence(
      documentId: documentId,
      claimId: claim,
      provenanceId: provenance,
    );
  });

  @override
  Future<List<LifeEntity>> entitiesForDocument(String documentId) =>
      _graph.entitiesForDocument(documentId);

  @override
  Future<void> unlinkDocumentEvidence({
    required String entityId,
    required String documentId,
  }) => _libraryAction(
    () => _graph.unlinkDocumentEvidence(
      entityId: entityId,
      documentId: documentId,
    ),
  );

  @override
  Future<List<LifeEntity>> profileMatchCandidates(
    DocumentReviewView review,
  ) async {
    final types = _entityTypesForDocument(review.suggestedType);
    if (types.isEmpty) return const <LifeEntity>[];
    return _entities
        .where(
          (entity) =>
              entity.status == LifeEntityStatus.active &&
              types.contains(entity.type),
        )
        .toList(growable: false);
  }

  @override
  Future<List<LifeEvent>> entityEvents(
    String entityId, {
    bool includeHistorical = false,
  }) => _graph.listEvents(
    entityId: entityId,
    includeHistorical: includeHistorical,
  );

  @override
  Future<List<LifeEventEvidence>> eventEvidence(String eventId) =>
      _graph.eventEvidence(eventId);

  @override
  Future<String?> createEvent({
    required LifeEventType type,
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    int? amountMinorUnits,
    String? currency,
    String? locationEntityId,
    String? notes,
    String? entityId,
    String? documentId,
  }) async {
    String? result;
    await _libraryAction(() async {
      final provenance = await _graph.createProvenance(
        sourceType: ProvenanceSourceType.userEntered,
        sourceDocumentId: documentId,
        confidence: 1,
        confidenceSource: 'USER',
      );
      result = await _graph.suggestEvent(
        type: type,
        title: title,
        startAt: startAt,
        endAt: endAt,
        amountMinorUnits: amountMinorUnits,
        currency: currency,
        locationEntityId: locationEntityId,
        notes: notes,
        entityRoles: entityId == null ? const {} : {entityId: 'SUBJECT'},
        provenanceId: provenance,
      );
      await _graph.setEventStatus(result!, LifeEventStatus.confirmed);
      if (documentId != null) {
        await _graph.addEventEvidence(
          eventId: result!,
          documentId: documentId,
          provenanceId: provenance,
        );
      }
    });
    return result;
  }

  @override
  Future<void> reviewEvent(String eventId, LifeEventStatus status) =>
      _libraryAction(() => _graph.setEventStatus(eventId, status));

  @override
  Future<String?> correctEvent({
    required String eventId,
    required LifeEventType type,
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    int? amountMinorUnits,
    String? currency,
    String? locationEntityId,
    String? notes,
  }) async {
    String? result;
    await _libraryAction(() async {
      final provenance = await _graph.createProvenance(
        sourceType: ProvenanceSourceType.userEntered,
        confidence: 1,
        confidenceSource: 'USER',
      );
      result = await _graph.correctEvent(
        eventId: eventId,
        type: type,
        title: title,
        startAt: startAt,
        endAt: endAt,
        amountMinorUnits: amountMinorUnits,
        currency: currency,
        locationEntityId: locationEntityId,
        notes: notes,
        provenanceId: provenance,
      );
    });
    return result;
  }

  @override
  Future<List<LifeExpenseTotal>> expenseTotals({
    required DateTime from,
    required DateTime until,
    String? entityId,
  }) => _graph.expenseTotals(from: from, until: until, entityId: entityId);

  @override
  Future<List<DerivedLifeState>> lifeStates({String? entityId}) =>
      _attention.listStates(entityId: entityId);

  @override
  Future<void> createTaskFromAttention(String attentionId) =>
      _libraryAction(() async {
        await _attention.createTaskFromAttention(attentionId);
      });

  @override
  Future<void> dismissAttention(String attentionId) =>
      _libraryAction(() => _attention.dismissAttention(attentionId));

  @override
  Future<void> createTask({
    required String title,
    String? notes,
    DateTime? dueAt,
    String? recurrenceRule,
    String? entityId,
    String? eventId,
    String? documentId,
  }) => _libraryAction(() async {
    await _attention.createTask(
      title: title,
      notes: notes,
      dueAt: dueAt,
      recurrenceRule: recurrenceRule,
      entityId: entityId,
      eventId: eventId,
      documentId: documentId,
    );
  });

  @override
  Future<void> snoozeTask(String taskId, DateTime until) =>
      _libraryAction(() => _attention.snoozeTask(taskId, until));

  @override
  Future<void> rescheduleTask(String taskId, DateTime dueAt) =>
      _libraryAction(() => _attention.rescheduleTask(taskId, dueAt));

  @override
  Future<void> completeTask(String taskId) => _libraryAction(() async {
    await _attention.completeTask(taskId);
  });

  @override
  Future<void> dismissTask(String taskId) =>
      _libraryAction(() => _attention.dismissTask(taskId));

  @override
  Future<void> createChecklist({
    required String title,
    required List<String> items,
    String? entityId,
    String? eventId,
    String? evidenceDocumentId,
  }) => _libraryAction(() async {
    await _attention.createChecklist(
      title: title,
      items: items,
      entityId: entityId,
      eventId: eventId,
      evidenceDocumentId: evidenceDocumentId,
    );
  });

  @override
  Future<void> setChecklistItemCompleted(String itemId, bool completed) =>
      _libraryAction(
        () => _attention.setChecklistItemCompleted(itemId, completed),
      );

  @override
  Future<void> createSmartPack({
    required String presetId,
    String? title,
    String? entityId,
    bool includeIndiaPack = false,
  }) => _libraryAction(() async {
    await _smartPackRepository.createFromPreset(
      presetId: presetId,
      title: title,
      entityId: entityId,
      includeIndiaPack: includeIndiaPack,
    );
    _notice = 'Smart Pack created from a versioned offline template.';
  });

  @override
  Future<void> createCustomSmartPack({
    required String title,
    required List<String> items,
    String? entityId,
  }) => _libraryAction(() async {
    await _smartPackRepository.createCustom(
      title: title,
      itemLabels: items,
      entityId: entityId,
    );
    _notice = 'Custom Smart Pack saved locally.';
  });

  @override
  Future<void> addSmartPackItem({
    required String packId,
    required String label,
  }) => _libraryAction(() async {
    await _smartPackRepository.addCustomItem(packId: packId, label: label);
  });

  @override
  Future<void> customizeSmartPackItem({
    required String itemId,
    required String label,
    required bool isEnabled,
    required bool isOptional,
    required bool includeInExport,
  }) => _libraryAction(
    () => _smartPackRepository.customizeItem(
      itemId: itemId,
      label: label,
      isEnabled: isEnabled,
      isOptional: isOptional,
      includeInExport: includeInExport,
    ),
  );

  @override
  Future<void> linkSmartPackItem({
    required String itemId,
    String? claimId,
    String? eventId,
    String? documentId,
    String? taskId,
  }) => _libraryAction(
    () => _smartPackRepository.linkItem(
      itemId: itemId,
      claimId: claimId,
      eventId: eventId,
      documentId: documentId,
      taskId: taskId,
    ),
  );

  @override
  Future<void> archiveSmartPack(String packId) =>
      _libraryAction(() => _smartPackRepository.setArchived(packId, true));

  @override
  Future<List<String>> smartPackExportDocuments(String packId) =>
      _smartPackRepository.exportDocumentIds(packId);

  Future<void> _pickAndImport(
    Future<IngestionCandidate?> Function() picker,
  ) async {
    beginExternalActivity();
    try {
      final candidate = await picker();
      if (candidate == null) return;
      await _import(candidate);
    } finally {
      endExternalActivity();
    }
  }

  Future<void> _import(IngestionCandidate candidate) async {
    await _run(() async {
      _notice = 'Securing your file...';
      notifyListeners();

      await _coordinator.import(candidate);
      _notice = 'Processing securely...';
      await _coordinator.processUntilIdle(workerId: workerId);
      _notice = 'Added to OwnKeep';
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) return;
    _isBusy = true;
    _notice = null;
    notifyListeners();
    try {
      await action();
    } on IngestionFailure catch (failure) {
      _notice = _messageFor(failure.code);
    } on Object catch (error, stackTrace) {
      assert(() {
        debugPrint('OwnKeep operation failed: $error\n$stackTrace');
        return true;
      }());
      _notice = 'The operation could not be completed. Please try again.';
    } finally {
      _jobs = await _coordinator.listJobs();
      _reviews = await _coordinator.listReviews();
      await _refreshLibrary();
      _isBusy = false;
      _scheduleProcessingRetry();
      notifyListeners();
    }
  }

  void _scheduleProcessingRetry() {
    _processingRetryTimer?.cancel();
    final retryTimes = _jobs
        .where(
          (job) =>
              job.status == DocumentProcessingStatus.retryScheduled &&
              job.availableAfter != null,
        )
        .map((job) => job.availableAfter!)
        .toList(growable: false);
    if (retryTimes.isEmpty) return;
    retryTimes.sort();
    final delay = retryTimes.first.difference(DateTime.now().toUtc());
    _processingRetryTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(_resumeScheduledProcessing()),
    );
  }

  Future<void> _resumeScheduledProcessing() async {
    if (_isBusy) {
      _processingRetryTimer = Timer(
        const Duration(seconds: 2),
        () => unawaited(_resumeScheduledProcessing()),
      );
      return;
    }
    try {
      await _coordinator.processUntilIdle(workerId: workerId);
    } finally {
      _jobs = await _coordinator.listJobs();
      _reviews = await _coordinator.listReviews();
      await _refreshLibrary();
      _scheduleProcessingRetry();
      notifyListeners();
    }
  }

  Future<void> _libraryAction(Future<void> Function() action) => _run(() async {
    await action();
    _notice ??= 'Saved locally.';
  });

  Future<void> _refreshLibrary() async {
    _documents = await _library.listDocuments(_filter);
    _dashboardDocuments = await _library.listDocuments(
      const DocumentLibraryFilter(),
    );
    _tags = await _library.listTags();
    _reminders = await _reminderCoordinator.list();
    _entities = await _graph.listEntities(includeArchived: true);
    _entityAttributesById = {
      for (final entity in _entities)
        entity.id: await _graph.entityAttributes(entity.id),
    };
    _graphClaims = [
      for (final entity in _entities)
        ...await _graph.claimsForEntity(entity.id),
    ];
    _events = await _graph.listEvents();
    final inboxCount =
        _reviews.length +
        _jobs
            .where(
              (job) =>
                  job.status != DocumentProcessingStatus.ready &&
                  job.status != DocumentProcessingStatus.failed,
            )
            .length;
    await _attention.recalculate(
      now: DateTime.now().toUtc(),
      inboxCount: inboxCount,
    );
    _attentionItems = await _attention.listAttention();
    _lifeStates = await _attention.listStates();
    _tasks = await _attention.listTasks();
    _checklists = await _attention.listChecklists();
    _smartPacks = await _smartPackRepository.listPacks();
    _preferences = await _library.preferences();
  }

  Future<void> _suggestProfileClaims(
    String entityId,
    DocumentReviewView review,
    List<ConfirmedFieldEdit> edits,
  ) async {
    final editedValues = {
      for (final edit in edits) edit.fieldId: edit.value.trim(),
    };
    for (final field in review.fields) {
      final value = editedValues[field.id] ?? field.effectiveValue.trim();
      if (value.isEmpty) continue;
      final provenance = await _graph.createProvenance(
        sourceType: ProvenanceSourceType.documentExtracted,
        sourceDocumentId: review.documentId,
        extractorId: field.extractorId,
        extractorVersion: field.extractorVersion,
        confidence: field.confidence,
        confidenceSource: 'OCR',
      );
      final claim = await _graph.suggestClaim(
        subjectEntityId: entityId,
        predicate: _predicateFor(field.type),
        value: _claimValueFor(field.type, value),
        cardinality: _cardinalityFor(field.type),
        provenanceId: provenance,
      );
      await _graph.addEvidence(
        documentId: review.documentId,
        claimId: claim,
        pageNumber: field.sourcePage,
        provenanceId: provenance,
      );
    }
  }

  Future<void> _suggestDocumentEvents(
    DocumentReviewView review,
    List<ConfirmedFieldEdit> edits, {
    String? profileEntityId,
  }) async {
    final editedValues = {
      for (final edit in edits) edit.fieldId: edit.value.trim(),
    };
    String valueFor(ExtractedFieldView field) =>
        editedValues[field.id] ?? field.effectiveValue.trim();
    final dateField = review.fields
        .where(
          (field) =>
              field.type == ExtractedFieldType.date ||
              field.type == ExtractedFieldType.dueDate,
        )
        .where((field) => DateTime.tryParse(valueFor(field)) != null)
        .firstOrNull;
    final mainType = _eventTypeForDocument(review.suggestedType);
    if (mainType != null && dateField != null) {
      final provenance = await _graph.createProvenance(
        sourceType: ProvenanceSourceType.documentExtracted,
        sourceDocumentId: review.documentId,
        extractorId: dateField.extractorId,
        extractorVersion: dateField.extractorVersion,
        confidence: dateField.confidence,
        confidenceSource: 'OCR',
      );
      final money = review.fields
          .where((field) => field.type == ExtractedFieldType.amount)
          .map(valueFor)
          .map(_parseMoney)
          .whereType<({int minorUnits, String currency})>()
          .firstOrNull;
      final eventId = await _graph.suggestEvent(
        type: mainType,
        title: _eventTitleForDocument(review.suggestedType),
        startAt: DateTime.parse(valueFor(dateField)).toUtc(),
        amountMinorUnits: money?.minorUnits,
        currency: money?.currency,
        entityRoles: profileEntityId == null
            ? const {}
            : {profileEntityId: 'SUBJECT'},
        provenanceId: provenance,
      );
      await _graph.addEventEvidence(
        eventId: eventId,
        documentId: review.documentId,
        pageNumber: dateField.sourcePage,
        provenanceId: provenance,
      );
    }
    for (final field in review.fields.where(
      (field) => field.type == ExtractedFieldType.expiryDate,
    )) {
      final expiry = DateTime.tryParse(valueFor(field));
      if (expiry == null) continue;
      final provenance = await _graph.createProvenance(
        sourceType: ProvenanceSourceType.documentExtracted,
        sourceDocumentId: review.documentId,
        extractorId: field.extractorId,
        extractorVersion: field.extractorVersion,
        confidence: field.confidence,
        confidenceSource: 'OCR',
      );
      final eventId = await _graph.suggestEvent(
        type: LifeEventType.expiry,
        title: '${review.suggestedType.displayName} expires',
        startAt: expiry.toUtc(),
        entityRoles: profileEntityId == null
            ? const {}
            : {profileEntityId: 'SUBJECT'},
        provenanceId: provenance,
      );
      await _graph.addEventEvidence(
        eventId: eventId,
        documentId: review.documentId,
        pageNumber: field.sourcePage,
        provenanceId: provenance,
      );
    }
  }

  Future<void> _suggestEventFromClaim(String claimId) async {
    final claim = await _graph.claim(claimId);
    if (claim == null ||
        (claim.value.type != ClaimValueType.date &&
            claim.value.type != ClaimValueType.datetime)) {
      return;
    }
    final upperPredicate = claim.predicate.toUpperCase();
    final type = upperPredicate.contains('EXPIR')
        ? LifeEventType.expiry
        : upperPredicate.contains('DUE')
        ? LifeEventType.payment
        : null;
    if (type == null) return;
    final date = claim.value.dateTimeValue.toUtc();
    final existing = await _graph.listEvents(
      entityId: claim.subjectEntityId,
      includeHistorical: true,
    );
    if (existing.any(
      (event) =>
          event.type == type &&
          event.startAt == date &&
          event.status != LifeEventStatus.rejected,
    )) {
      return;
    }
    final provenance = await _graph.createProvenance(
      sourceType: ProvenanceSourceType.ruleDerived,
      ruleId: 'confirmed-claim-to-event',
      ruleVersion: '1',
      confidence: 1,
      confidenceSource: 'RULE',
    );
    final eventId = await _graph.suggestEvent(
      type: type,
      title: type == LifeEventType.expiry
          ? 'Confirmed item expires'
          : 'Confirmed payment due',
      startAt: date,
      entityRoles: {claim.subjectEntityId: 'SUBJECT'},
      provenanceId: provenance,
    );
    final evidence = await _graph.evidenceForClaim(claimId);
    for (final link in evidence) {
      await _graph.addEventEvidence(
        eventId: eventId,
        documentId: link.documentId,
        evidenceRole: link.evidenceRole,
        assetId: link.assetId,
        pageNumber: link.pageNumber,
        boundingPolygonJson: link.boundingPolygonJson,
        textFragmentHash: link.textFragmentHash,
        provenanceId: provenance,
      );
    }
  }

  static LifeEventType? _eventTypeForDocument(DocumentType type) =>
      switch (type) {
        DocumentType.receipt => LifeEventType.purchase,
        DocumentType.invoice ||
        DocumentType.electricityBill ||
        DocumentType.waterBill ||
        DocumentType.gasBill => LifeEventType.payment,
        DocumentType.insurancePolicy => LifeEventType.renewal,
        DocumentType.medicalReport ||
        DocumentType.prescription => LifeEventType.medical,
        DocumentType.educationCertificate => LifeEventType.education,
        DocumentType.propertyTax => LifeEventType.tax,
        _ => null,
      };

  static String _eventTitleForDocument(DocumentType type) => switch (type) {
    DocumentType.receipt => 'Purchase recorded',
    DocumentType.invoice => 'Invoice payment',
    DocumentType.electricityBill => 'Electricity payment',
    DocumentType.waterBill => 'Water payment',
    DocumentType.gasBill => 'Gas payment',
    DocumentType.insurancePolicy => 'Insurance renewed',
    DocumentType.medicalReport => 'Medical record',
    DocumentType.prescription => 'Medical prescription',
    DocumentType.educationCertificate => 'Education milestone',
    DocumentType.propertyTax => 'Property tax',
    _ => type.displayName,
  };

  static ({int minorUnits, String currency})? _parseMoney(String value) {
    final upper = value.toUpperCase();
    final currency = upper.contains('INR') || value.contains('₹')
        ? 'INR'
        : upper.contains('USD') || value.contains(r'$')
        ? 'USD'
        : upper.contains('EUR') || value.contains('€')
        ? 'EUR'
        : upper.contains('GBP') || value.contains('£')
        ? 'GBP'
        : null;
    if (currency == null) return null;
    final normalized = value.replaceAll(RegExp('[^0-9.-]'), '');
    final amount = double.tryParse(normalized);
    if (amount == null || !amount.isFinite || amount < 0) return null;
    return (minorUnits: (amount * 100).round(), currency: currency);
  }

  static Set<LifeEntityType> _entityTypesForDocument(DocumentType type) =>
      switch (type) {
        DocumentType.aadhaar ||
        DocumentType.pan ||
        DocumentType.passport ||
        DocumentType.drivingLicence ||
        DocumentType.voterId ||
        DocumentType.medicalReport ||
        DocumentType.prescription ||
        DocumentType.educationCertificate => const {LifeEntityType.person},
        DocumentType.vehicleDocument => const {LifeEntityType.vehicle},
        DocumentType.electricityBill ||
        DocumentType.waterBill ||
        DocumentType.gasBill ||
        DocumentType.propertyTax => const {
          LifeEntityType.property,
          LifeEntityType.place,
        },
        DocumentType.insurancePolicy => const {
          LifeEntityType.vehicle,
          LifeEntityType.property,
          LifeEntityType.person,
        },
        _ => const {},
      };

  static String _predicateFor(ExtractedFieldType type) => switch (type) {
    ExtractedFieldType.date => 'DOCUMENT_DATE',
    ExtractedFieldType.expiryDate => 'EXPIRY_DATE',
    ExtractedFieldType.dueDate => 'DUE_DATE',
    ExtractedFieldType.amount => 'DOCUMENT_AMOUNT',
    ExtractedFieldType.documentNumber => 'DOCUMENT_NUMBER',
    ExtractedFieldType.issuer => 'ISSUER',
    ExtractedFieldType.email => 'EMAIL_ADDRESS',
    ExtractedFieldType.phone => 'PHONE_NUMBER',
    ExtractedFieldType.maskedAccountNumber => 'MASKED_ACCOUNT_NUMBER',
    ExtractedFieldType.address => 'ADDRESS',
    ExtractedFieldType.firstName => 'FIRST_NAME',
    ExtractedFieldType.lastName => 'LAST_NAME',
    ExtractedFieldType.fullName => 'FULL_NAME',
    ExtractedFieldType.relativeName => 'RELATIVE_NAME',
    ExtractedFieldType.age => 'AGE',
    ExtractedFieldType.gender => 'GENDER',
    ExtractedFieldType.state => 'STATE',
    ExtractedFieldType.parliamentaryConstituency =>
      'PARLIAMENTARY_CONSTITUENCY',
    ExtractedFieldType.assemblyConstituency => 'ASSEMBLY_CONSTITUENCY',
    ExtractedFieldType.pollingStation => 'POLLING_STATION',
    ExtractedFieldType.partNumber => 'PART_NUMBER',
    ExtractedFieldType.serialNumber => 'SERIAL_NUMBER',
    ExtractedFieldType.pollingDate => 'POLLING_DATE',
    ExtractedFieldType.nationality => 'NATIONALITY',
    ExtractedFieldType.placeOfBirth => 'PLACE_OF_BIRTH',
    ExtractedFieldType.policyholder => 'POLICYHOLDER',
    ExtractedFieldType.consumerNumber => 'CONSUMER_NUMBER',
    ExtractedFieldType.billingPeriod => 'BILLING_PERIOD',
    ExtractedFieldType.patientName => 'PATIENT_NAME',
    ExtractedFieldType.merchant => 'MERCHANT',
    ExtractedFieldType.taxAmount => 'TAX_AMOUNT',
    ExtractedFieldType.totalAmount => 'TOTAL_AMOUNT',
  };

  static ClaimCardinality _cardinalityFor(ExtractedFieldType type) =>
      switch (type) {
        ExtractedFieldType.email ||
        ExtractedFieldType.phone ||
        ExtractedFieldType.address => ClaimCardinality.multipleCurrent,
        ExtractedFieldType.date ||
        ExtractedFieldType.amount => ClaimCardinality.historical,
        _ => ClaimCardinality.singleCurrent,
      };

  static ClaimValue _claimValueFor(ExtractedFieldType type, String value) {
    return switch (type) {
      ExtractedFieldType.date ||
      ExtractedFieldType.expiryDate ||
      ExtractedFieldType.dueDate => switch (DateTime.tryParse(value)) {
        final parsed? => ClaimValue.date(parsed),
        null => ClaimValue.string(value),
      },
      ExtractedFieldType.documentNumber ||
      ExtractedFieldType.maskedAccountNumber => ClaimValue.identifier(value),
      _ => ClaimValue.string(value),
    };
  }

  static String _messageFor(String code) => switch (code) {
    'file_type_unsupported' => 'This file type is not supported.',
    'file_size_unsupported' ||
    'image_size_unsupported' => 'This file is too large to import safely.',
    'source_length_mismatch' => 'The selected file changed during import.',
    _ => 'Import could not be completed. Please try again.',
  };

  static String _suffixFor(String mimeType) => switch (mimeType.toLowerCase()) {
    'application/pdf' => '.pdf',
    'image/jpeg' => '.jpg',
    'image/png' => '.png',
    'image/webp' => '.webp',
    'image/gif' => '.gif',
    'image/bmp' => '.bmp',
    'image/tiff' => '.tiff',
    'image/heic' => '.heic',
    'image/heif' => '.heif',
    'text/plain' => '.txt',
    'text/csv' => '.csv',
    'application/msword' => '.doc',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
      '.docx',
    'application/vnd.ms-excel' => '.xls',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' =>
      '.xlsx',
    'application/vnd.ms-powerpoint' => '.ppt',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation' =>
      '.pptx',
    _ => '.bin',
  };
}
