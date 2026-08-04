import 'package:vault_ingestion/vault_ingestion.dart';

extension AppStringTranslation on String {
  /// Translates this string using the offline multilingual engine.
  String get tr => OfflineMultilingualEngine().translate(this);
}

/// Centralized repository of all UI text strings across the application.
/// Eliminates hardcoded strings from widget trees and simplifies translations.
abstract final class AppStrings {
  // --- App Shell & Branding ---
  /// Main application brand name.
  static const String appName = 'OwnKeep';

  /// Primary application tagline.
  static const String appTagline = 'Keep What Matters. Own Your Data.';

  /// Offline mode badge text.
  static const String strictOfflineMode = 'Strict offline mode';

  // --- Navigation Tabs ---
  /// Life overview navigation tab title.
  static const String navLife = 'Life';

  /// Records & library navigation tab title.
  static const String navRecords = 'Records';

  /// Ingestion inbox navigation tab title.
  static const String navInbox = 'Inbox';

  /// Document library tab title.
  static const String navLibrary = 'Library';

  /// Life timeline tab title.
  static const String navTimeline = 'Timeline';

  /// Attention items tab title.
  static const String navAttention = 'Attention';

  /// Settings navigation tab title.
  static const String navSettings = 'Settings';

  /// Universal search tab title.
  static const String navSearch = 'Search';

  /// Graph tab label.
  static const String navGraph = 'Graph';

  // --- Vault Lifecycle & Authentication ---
  /// Title for onboarding vault creation screen.
  static const String createVaultTitle = 'Create your private vault';

  /// Subtitle for onboarding vault creation screen.
  static const String createVaultSubtitle =
      'Documents stay encrypted on this device. Start by choosing the '
      'recovery passphrase that protects your vault.';

  /// Recovery warning notice for vault creation.
  static const String passphraseNotice =
      'Store this passphrase somewhere safe. Losing it can make your '
      'encrypted documents permanently inaccessible.';

  /// Label for recovery passphrase input field.
  static const String passphraseHint = 'Recovery passphrase';

  /// Label for backup recovery passphrase input field.
  static const String backupPassphraseHint = 'Backup recovery passphrase';

  /// Helper text for passphrase complexity requirement.
  static const String passphraseMinLength =
      'At least 12 characters; a long phrase is best.';

  /// Label for confirming passphrase input field.
  static const String confirmPassphraseHint = 'Confirm recovery passphrase';

  /// Checkbox title acknowledging non-recoverability.
  static const String checkboxPassphraseNotice =
      'I understand OwnKeep cannot reset this passphrase.';

  /// Button label for submitting vault creation.
  static const String btnCreateVault = 'Create encrypted vault';

  /// Button label for restoring from a backup.
  static const String btnChooseBackup = 'Restore encrypted backup';

  /// Title for unlocking an existing vault.
  static const String unlockVaultTitle = 'Unlock OwnKeep';

  /// Subtitle for unlocking an existing vault.
  static const String unlockVaultSubtitle =
      'Enter your recovery passphrase to access your private encrypted vault.';

  /// Button label to unlock vault with passphrase.
  static const String btnUnlockVault = 'Unlock vault';

  /// Button label to unlock vault using biometrics.
  static const String btnBiometricUnlock = 'Unlock with biometrics';

  /// Selected backup card title.
  static const String selectedBackup = 'Selected backup';

  /// Verify and restore button label.
  static const String btnVerifyAndRestore = 'Verify and restore';

  /// Status label when verifying device state.
  static const String statusCheckingDevice = 'Checking this device...';

  /// Status label when creating vault storage.
  static const String statusCreatingVault = 'Creating your private vault...';

  /// Status label when opening encrypted vault.
  static const String statusOpeningVault = 'Opening your encrypted vault...';

  // --- Settings Screen ---
  /// Settings screen app bar title.
  static const String settingsTitle = 'Settings';

  /// Header for reminder offset configuration.
  static const String defaultReminderOffsets = 'Default reminder offsets';

  /// Subtitle for reminder offset configuration.
  static const String defaultReminderSubtitle =
      'Used when expiry reminder suggestions are added.';

  /// Label for reminder on the exact due date.
  static const String reminderOnDate = 'On the date';

  /// Formats reminder label for N days prior to due date.
  static String reminderDaysBefore(int days) => '$days days before';

  /// Title for Ask OwnKeep search tile.
  static const String askOwnKeepTitle = 'Ask OwnKeep';

  /// Subtitle for Ask OwnKeep search tile.
  static const String askOwnKeepSubtitle =
      'Execute deterministic graph queries for attention, expiry,'
      ' spending, and warranties.';

  /// Title for Emergency Card setting tile.
  static const String emergencyCardTitle = 'Emergency Medical Card';

  /// Subtitle for Emergency Card setting tile.
  static const String emergencyCardSubtitle =
      'View minimized emergency responder contacts, blood group,'
      ' and medical data.';

  /// Title for On-device Intelligence setting tile.
  static const String onDeviceIntelTitle = 'On-device Intelligence';

  /// Subtitle for On-device Intelligence setting tile.
  static const String onDeviceIntelSubtitle =
      'View grounded natural language summaries and recommendations.';

  /// Title for Language & OCR setting tile.
  static const String languageOcrTitle = 'Language & Regional OCR Packs';

  /// Subtitle for Language & OCR setting tile.
  static const String languageOcrSubtitle =
      'Configure interface locale and regional OCR text recognition packs.';

  /// Title for Automation Rules setting tile.
  static const String automationTitle = 'Offline Automation Engine';

  /// Subtitle for Automation Rules setting tile.
  static const String automationSubtitle =
      'Configure local WHEN / IF / THEN rules for reminders, backup,'
      ' and tagging.';

  /// Title for Device Transfer setting tile.
  static const String deviceTransferTitle = 'Device-to-Device Transfer';

  /// Subtitle for Device Transfer setting tile.
  static const String deviceTransferSubtitle =
      'Securely sync vault items directly to nearby devices over local P2P.';

  /// Title for Blind Backup setting tile.
  static const String blindBackupTitle = 'Blind Backup Destinations';

  /// Subtitle for Blind Backup setting tile.
  static const String blindBackupSubtitle =
      'Manage encrypted zero-knowledge backup destinations without token '
      'storage.';

  /// Title for Desktop Life OS setting tile.
  static const String desktopLifeOsTitle = 'OwnKeep Desktop Personal Life OS';

  /// Subtitle for Desktop Life OS setting tile.
  static const String desktopLifeOsSubtitle =
      'Access dual-pane workspace views, multi-window layout, and bulk drop.';

  // --- Life Dashboard & Inventory ---
  /// Title for main Life OS dashboard.
  static const String dashboardTitle = 'Life OS Overview';

  /// Header for vault summary section.
  static const String vaultSummaryHeader = 'Vault Summary';

  /// Metric label for total asset value.
  static const String totalAssetsValue = 'Total Assets Value';

  /// Metric label for total maintenance spend.
  static const String totalSpendLogged = 'Total Maintenance Spend';

  /// Header for recent evidence documents section.
  static const String recentEvidenceHeader = 'Recent Evidence Documents';

  /// Header for attention items section.
  static const String attentionNeededHeader = 'Attention Needed';

  /// Location title for assets.
  static const String locationTitle = 'Location';

  /// Purchase price title for assets.
  static const String purchasePriceTitle = 'Purchase Price';

  /// Warranty coverage title for assets.
  static const String warrantyCoverageTitle = 'Warranty Coverage';

  /// Label when no maintenance logs are recorded.
  static const String noLogsYet = 'No maintenance or cost logs yet.';

  /// Button label to log maintenance or cost.
  static const String logMaintenanceButton = 'Log Maintenance / Cost';

  /// Household inventory screen title.
  static const String householdInventoryTitle = 'Household Inventory';

  /// Total lifetime spend label.
  static const String lifetimeSpendLabel = 'Lifetime Spend';

  /// Label when no matching household items exist.
  static const String noMatchingAssets = 'No matching household items found.';

  // --- Document Library, Ingestion & Detail ---
  /// Title for document library screen.
  static const String libraryTitle = 'Documents Library';

  /// Search field hint in document library.
  static const String searchDocsHint = 'Search documents...';

  /// Filter chip for all document types.
  static const String filterAllTypes = 'All Types';

  /// Filter chip for identity documents.
  static const String filterIdentity = 'Identity';

  /// Filter chip for vehicle documents.
  static const String filterVehicle = 'Vehicle';

  /// Filter chip for property documents.
  static const String filterProperty = 'Property';

  /// Filter chip for tax documents.
  static const String filterTax = 'Tax';

  /// Filter chip for insurance documents.
  static const String filterInsurance = 'Insurance';

  /// Filter chip for finance documents.
  static const String filterFinance = 'Finance';

  /// Filter chip for medical documents.
  static const String filterMedical = 'Medical';

  /// Ingestion inbox screen title.
  static const String inboxTitle = 'Inbox';

  /// Subtitle when no documents are currently processing.
  static const String noDocumentsProcessing = 'No documents processing';

  /// Title for document export confirmation.
  static const String exportConfirmationTitle = 'Export Document';

  /// Notice for privacy sharing & redactions.
  static const String privacySharingTitle = 'Privacy-aware Sharing';

  /// Button to export redacted PDF.
  static const String btnExportRedactedPdf = 'Export Redacted Copy';

  // --- Feature Specific Screens ---
  /// Ask OwnKeep screen header.
  static const String askOwnKeepHeader = 'Ask OwnKeep';

  /// Chip for warranties query.
  static const String warrantiesChip = 'Warranties';

  /// Chip for total spend query.
  static const String totalSpendChip = 'Total Spend';

  /// Chip for household valuation query.
  static const String householdValuationChip = 'Household Valuation';

  /// Chip for smart packs query.
  static const String smartPacksChip = 'Smart Packs';

  /// Trigger blind sync rehearsal button.
  static const String triggerBlindSync = 'Trigger Blind Sync Rehearsal';

  /// Add rule button label.
  static const String btnAddRule = 'Add Rule';

  /// Add automation rule dialog title.
  static const String addAutomationRuleTitle = 'Add Automation Rule';

  /// Save rule button label.
  static const String btnSaveRule = 'Save Rule';

  /// No automation executions recorded label.
  static const String noAutomationExecutions =
      'No automation executions recorded yet.';

  /// Reminders screen app bar title.
  static const String remindersTitle = 'Reminders';

  /// Label when no upcoming reminders exist.
  static const String noUpcomingReminders = 'No upcoming reminders';

  /// Subtitle directing user to add reminders from document detail.
  static const String addFromDocumentDetail =
      'Add one from a document detail screen.';

  /// Snooze 1 day action.
  static const String btnSnooze1Day = 'Snooze 1 day';

  /// Choose new date action.
  static const String btnChooseNewDate = 'Choose new date';

  /// Mark completed action.
  static const String btnMarkCompleted = 'Mark completed';

  /// Simulate bulk import drop button for desktop.
  static const String simulateBulkDrop = 'Simulate Bulk Import Drop';

  /// Known allergies title.
  static const String knownAllergies = 'Known Allergies';

  /// Active medications title.
  static const String activeMedications = 'Active Medications';

  /// Primary physician title.
  static const String primaryPhysician = 'Primary Physician';

  /// Health insurance policy title.
  static const String healthInsurancePolicy = 'Health Insurance Policy';

  /// Audit log dialog title.
  static const String accessAuditLogTitle = 'Emergency Access Audit Log';

  /// No access logs recorded message.
  static const String noAccessLogsRecorded = 'No access logs recorded.';

  /// Interface language header title.
  static const String interfaceLanguageTitle = 'Interface Language';

  /// OCR packs header title.
  static const String ocrPacksTitle = 'Regional OCR Text Packs';

  /// Initiate ephemeral pairing button.
  static const String initiatePairing = 'Generate Pairing PIN';

  /// Title for Smart Packs screen.
  static const String smartPacksTitle = 'Smart Packs';

  /// Title for Entity Directory screen.
  static const String entityDirectoryTitle = 'Life Directory';

  /// Title for Life Timeline screen.
  static const String lifeTimelineTitle = 'Life Timeline';

  /// Title for Life Navigator screen.
  static const String lifeNavigatorTitle = 'Life Navigator';

  /// Title for Attention Tasks screen.
  static const String attentionTasksTitle = 'Attention Items';

  /// Nothing urgent title for attention tasks.
  static const String nothingUrgent = 'Nothing urgent';

  // --- Common Dialog & Screen Actions ---
  /// Generic confirm action text.
  static const String btnConfirm = 'Confirm';

  /// Generic continue action text.
  static const String btnContinue = 'Continue';

  /// Generic cancel action text.
  static const String btnCancel = 'Cancel';

  /// Generic save action text.
  static const String btnSave = 'Save';

  /// Generic delete action text.
  static const String btnDelete = 'Delete';

  /// Generic close action text.
  static const String btnClose = 'Close';

  /// Generic back action text.
  static const String btnBack = 'Back';

  /// Generic retry action text.
  static const String btnRetry = 'Retry';

  /// Extracted UI string: 'OwnKeep could not access private storage.'.
  static const String txtOwnKeepCouldNotAccessPrivateStorage =
      'OwnKeep could not access private storage.';

  /// Extracted UI string: 'Deterministic Graph Answers'.
  static const String txtDeterministicGraphAnswers =
      'Deterministic Graph Answers';

  /// Extracted UI string: 'Ask OwnKeep parses facts directly from your encrypted graph and evidence documents without LLM hallucinations or cloud calls.'.
  static const String
  txtAskOwnKeepParsesFactsDirectlyFromYourEncryptedGraphAndEvidenceDocumentsWithoutLLMHallucinationsOrCloudCalls =
      'Ask OwnKeep parses facts directly from your encrypted graph and evidence documents without LLM hallucinations or cloud calls.';

  /// Extracted UI string: 'Type a query or tap a template above to query your vault.'.
  static const String txtTypeAQueryOrTapATemplateAboveToQueryYourVault =
      'Type a query or tap a template above to query your vault.';

  /// Extracted UI string: 'Attention & Tasks'.
  static const String txtAttentionTasks = 'Attention & Tasks';

  /// Extracted UI string: 'Prioritized locally from confirmed facts, events, evidence, integrity checks, and Inbox work.'.
  static const String
  txtPrioritizedLocallyFromConfirmedFactsEventsEvidenceIntegrityChecksAndInboxWork =
      'Prioritized locally from confirmed facts, events, evidence, integrity checks, and Inbox work.';

  /// Extracted UI string: 'Open encrypted evidence'.
  static const String txtOpenEncryptedEvidence = 'Open encrypted evidence';

  /// Extracted UI string: 'Dismiss'.
  static const String btnDismiss = 'Dismiss';

  /// Extracted UI string: 'Create task'.
  static const String txtCreateTask = 'Create task';

  /// Extracted UI string: 'Complete'.
  static const String txtComplete = 'Complete';

  /// Extracted UI string: 'Reschedule'.
  static const String txtReschedule = 'Reschedule';

  /// Extracted UI string: 'Task'.
  static const String btnTask = 'Task';

  /// Extracted UI string: 'Open linked evidence'.
  static const String txtOpenLinkedEvidence = 'Open linked evidence';

  /// Extracted UI string: 'Checklist'.
  static const String btnChecklist = 'Checklist';

  /// Extracted UI string: 'Add task'.
  static const String txtAddTask = 'Add task';

  /// Extracted UI string: 'Due date'.
  static const String txtDueDate = 'Due date';

  /// Extracted UI string: 'Does not repeat'.
  static const String txtDoesNotRepeat = 'Does not repeat';

  /// Extracted UI string: 'Daily'.
  static const String txtDaily = 'Daily';

  /// Extracted UI string: 'Weekly'.
  static const String txtWeekly = 'Weekly';

  /// Extracted UI string: 'Monthly'.
  static const String txtMonthly = 'Monthly';

  /// Extracted UI string: 'No profile'.
  static const String txtNoProfile = 'No profile';

  /// Extracted UI string: 'No record'.
  static const String txtNoRecord = 'No record';

  /// Extracted UI string: 'Add'.
  static const String btnAdd = 'Add';

  /// Extracted UI string: 'Add checklist'.
  static const String txtAddChecklist = 'Add checklist';

  /// Extracted UI string: 'Offline Safety Guaranteed'.
  static const String txtOfflineSafetyGuaranteed = 'Offline Safety Guaranteed';

  /// Extracted UI string: 'Automation runs 100% locally with bounded recursion, cycle detection, audit trails, and zero external network calls.'.
  static const String
  txtAutomationRuns100LocallyWithBoundedRecursionCycleDetectionAuditTrailsAndZeroExternalNetworkCalls =
      'Automation runs 100% locally with bounded recursion, cycle detection, audit trails, and zero external network calls.';

  /// Extracted UI string: 'Zero Token Blind Backup Policy'.
  static const String txtZeroTokenBlindBackupPolicy =
      'Zero Token Blind Backup Policy';

  /// Extracted UI string: 'Only encrypted archive bytes leave your device. Zero provider tokens or Master Vault Keys are retained by OwnKeep.'.
  static const String
  txtOnlyEncryptedArchiveBytesLeaveYourDeviceZeroProviderTokensOrMasterVaultKeysAreRetainedByOwnKeep =
      'Only encrypted archive bytes leave your device. Zero provider tokens or Master Vault Keys are retained by OwnKeep.';

  /// Extracted UI string: 'Select Destination Provider'.
  static const String txtSelectDestinationProvider =
      'Select Destination Provider';

  /// Extracted UI string: 'Active Destination Configuration'.
  static const String txtActiveDestinationConfiguration =
      'Active Destination Configuration';

  /// Extracted UI string: 'Desktop & Mobile Graph Compatibility Verified'.
  static const String txtDesktopMobileGraphCompatibilityVerified =
      'Desktop & Mobile Graph Compatibility Verified';

  /// Extracted UI string: 'OwnKeep 5.0.0 Final'.
  static const String txtOwnKeep500Final = 'OwnKeep 5.0.0 Final';

  /// Extracted UI string: 'Preserves complete Claim, provenance, history, evidence, and graph compatibility between mobile and desktop without central backends.'.
  static const String
  txtPreservesCompleteClaimProvenanceHistoryEvidenceAndGraphCompatibilityBetweenMobileAndDesktopWithoutCentralBackends =
      'Preserves complete Claim, provenance, history, evidence, and graph compatibility between mobile and desktop without central backends.';

  /// Extracted UI string: 'Desktop Layout Modes'.
  static const String txtDesktopLayoutModes = 'Desktop Layout Modes';

  /// Extracted UI string: 'Desktop Large-Scale Bulk Import Dropzone'.
  static const String txtDesktopLargeScaleBulkImportDropzone =
      'Desktop Large-Scale Bulk Import Dropzone';

  /// Extracted UI string: 'Drag & drop directories or multiple document files for high-throughput parallel OCR processing.'.
  static const String
  txtDragDropDirectoriesOrMultipleDocumentFilesForHighThroughputParallelOCRProcessing =
      'Drag & drop directories or multiple document files for high-throughput parallel OCR processing.';

  /// Extracted UI string: 'Emergency Storage Boundary Active. Isolated from main vault graph, evidence, and claims.'.
  static const String
  txtEmergencyStorageBoundaryActiveIsolatedFromMainVaultGraphEvidenceAndClaims =
      'Emergency Storage Boundary Active. Isolated from main vault graph, evidence, and claims.';

  /// Extracted UI string: 'Emergency Responder Contacts'.
  static const String txtEmergencyResponderContacts =
      'Emergency Responder Contacts';

  /// Extracted UI string: 'Timestamps when emergency medical card was opened:'.
  static const String txtTimestampsWhenEmergencyMedicalCardWasOpened =
      'Timestamps when emergency medical card was opened:';

  /// Extracted UI string: 'Link to a profile?'.
  static const String txtLinkToAProfile = 'Link to a profile?';

  /// Extracted UI string: 'OwnKeep found possible matches. You decide whether to create Claim suggestions.'.
  static const String
  txtOwnKeepFoundPossibleMatchesYouDecideWhetherToCreateClaimSuggestions =
      'OwnKeep found possible matches. You decide whether to create Claim suggestions.';

  /// Extracted UI string: 'Not now'.
  static const String txtNotNow = 'Not now';

  /// Extracted UI string: 'Offline'.
  static const String txtOffline = 'Offline';

  /// Extracted UI string: 'Bring records into your life'.
  static const String txtBringRecordsIntoYourLife =
      'Bring records into your life';

  /// Extracted UI string: 'Scan or import here. OwnKeep encrypts first, then organizes everything locally for your review.'.
  static const String
  txtScanOrImportHereOwnKeepEncryptsFirstThenOrganizesEverythingLocallyForYourReview =
      'Scan or import here. OwnKeep encrypts first, then organizes everything locally for your review.';

  /// Extracted UI string: 'Ready for you'.
  static const String txtReadyForYou = 'Ready for you';

  /// Extracted UI string: 'Local suggestions become part of your life record only after you confirm them.'.
  static const String
  txtLocalSuggestionsBecomePartOfYourLifeRecordOnlyAfterYouConfirmThem =
      'Local suggestions become part of your life record only after you confirm them.';

  /// Extracted UI string: 'Inbox activity'.
  static const String txtInboxActivity = 'Inbox activity';

  /// Extracted UI string: 'Review'.
  static const String btnReview = 'Review';

  /// Extracted UI string: 'Verify document details'.
  static const String txtVerifyDocumentDetails = 'Verify document details';

  /// Extracted UI string: 'Recognized text preview'.
  static const String txtRecognizedTextPreview = 'Recognized text preview';

  /// Extracted UI string: 'On-device OCR; check against original'.
  static const String txtOnDeviceOCRCheckAgainstOriginal =
      'On-device OCR; check against original';

  /// Extracted UI string: 'No fields were extracted. Confirm the type to finish.'.
  static const String txtNoFieldsWereExtractedConfirmTheTypeToFinish =
      'No fields were extracted. Confirm the type to finish.';

  /// Extracted UI string: 'Confirm only after comparing these values with the original document. Clear a value to remove it.'.
  static const String
  txtConfirmOnlyAfterComparingTheseValuesWithTheOriginalDocumentClearAValueToRemoveIt =
      'Confirm only after comparing these values with the original document. Clear a value to remove it.';

  /// Extracted UI string: 'Confirm reviewed details'.
  static const String txtConfirmReviewedDetails = 'Confirm reviewed details';

  /// Extracted UI string: 'Add a record'.
  static const String txtAddARecord = 'Add a record';

  /// Extracted UI string: 'No documents are processing'.
  static const String txtNoDocumentsAreProcessing =
      'No documents are processing';

  /// Extracted UI string: 'New records will appear here and safely resume if interrupted.'.
  static const String txtNewRecordsWillAppearHereAndSafelyResumeIfInterrupted =
      'New records will appear here and safely resume if interrupted.';

  /// Extracted UI string: 'All natural language summaries and recommendations are strictly grounded on verified indexed vault claims.'.
  static const String
  txtAllNaturalLanguageSummariesAndRecommendationsAreStrictlyGroundedOnVerifiedIndexedVaultClaims =
      'All natural language summaries and recommendations are strictly grounded on verified indexed vault claims.';

  /// Extracted UI string: 'Edit tags'.
  static const String txtEditTags = 'Edit tags';

  /// Extracted UI string: 'Use expiry date'.
  static const String txtUseExpiryDate = 'Use expiry date';

  /// Extracted UI string: 'Choose a custom date'.
  static const String txtChooseACustomDate = 'Choose a custom date';

  /// Extracted UI string: 'This document is no longer available.'.
  static const String txtThisDocumentIsNoLongerAvailable =
      'This document is no longer available.';

  /// Extracted UI string: 'Privacy Share'.
  static const String txtPrivacyShare = 'Privacy Share';

  /// Extracted UI string: 'Full view'.
  static const String txtFullView = 'Full view';

  /// Extracted UI string: 'Save copy'.
  static const String txtSaveCopy = 'Save copy';

  /// Extracted UI string: 'Edit'.
  static const String txtEdit = 'Edit';

  /// Extracted UI string: 'No tags'.
  static const String txtNoTags = 'No tags';

  /// Extracted UI string: 'No extracted fields'.
  static const String txtNoExtractedFields = 'No extracted fields';

  /// Extracted UI string: 'No recognized text'.
  static const String txtNoRecognizedText = 'No recognized text';

  /// Extracted UI string: 'Integrity check failed'.
  static const String txtIntegrityCheckFailed = 'Integrity check failed';

  /// Extracted UI string: 'Use a verified backup to recover this document.'.
  static const String txtUseAVerifiedBackupToRecoverThisDocument =
      'Use a verified backup to recover this document.';

  /// Extracted UI string: 'Original remains encrypted'.
  static const String txtOriginalRemainsEncrypted =
      'Original remains encrypted';

  /// Extracted UI string: 'No reminders'.
  static const String txtNoReminders = 'No reminders';

  /// Extracted UI string: 'Save an unencrypted copy?'.
  static const String txtSaveAnUnencryptedCopy = 'Save an unencrypted copy?';

  /// Extracted UI string: 'The saved file will no longer be protected by OwnKeep. Anyone with access to the selected destination may be able to open it.'.
  static const String
  txtTheSavedFileWillNoLongerBeProtectedByOwnKeepAnyoneWithAccessToTheSelectedDestinationMayBeAbleToOpenIt =
      'The saved file will no longer be protected by OwnKeep. Anyone with access to the selected destination may be able to open it.';

  /// Extracted UI string: 'Newest'.
  static const String txtNewest = 'Newest';

  /// Extracted UI string: 'Oldest'.
  static const String txtOldest = 'Oldest';

  /// Extracted UI string: 'Name'.
  static const String txtName = 'Name';

  /// Extracted UI string: 'Type'.
  static const String txtType = 'Type';

  /// Extracted UI string: 'Upcoming reminder'.
  static const String txtUpcomingReminder = 'Upcoming reminder';

  /// Extracted UI string: 'Favourites'.
  static const String txtFavourites = 'Favourites';

  /// Extracted UI string: 'Archived'.
  static const String txtArchived = 'Archived';

  /// Extracted UI string: 'All document types'.
  static const String txtAllDocumentTypes = 'All document types';

  /// Extracted UI string: 'All tags'.
  static const String txtAllTags = 'All tags';

  /// Extracted UI string: 'No documents match these filters'.
  static const String txtNoDocumentsMatchTheseFilters =
      'No documents match these filters';

  /// Extracted UI string: 'Import and review a document, or clear a filter.'.
  static const String txtImportAndReviewADocumentOrClearAFilter =
      'Import and review a document, or clear a filter.';

  /// Extracted UI string: 'Original file remains untouched. Redactions are flattened permanently before export.'.
  static const String
  txtOriginalFileRemainsUntouchedRedactionsAreFlattenedPermanentlyBeforeExport =
      'Original file remains untouched. Redactions are flattened permanently before export.';

  /// Extracted UI string: '1. Recipient & Purpose'.
  static const String txtValue1RecipientPurpose = '1. Recipient & Purpose';

  /// Extracted UI string: '2. Field Redactions (Masking)'.
  static const String txtValue2FieldRedactionsMasking =
      '2. Field Redactions (Masking)';

  /// Extracted UI string: 'Mask ID Numbers (Aadhaar / PAN / Passport)'.
  static const String txtMaskIDNumbersAadhaarPANPassport =
      'Mask ID Numbers (Aadhaar / PAN / Passport)';

  /// Extracted UI string: 'Mask Residential Address'.
  static const String txtMaskResidentialAddress = 'Mask Residential Address';

  /// Extracted UI string: 'Mask Date of Birth'.
  static const String txtMaskDateOfBirth = 'Mask Date of Birth';

  /// Extracted UI string: 'Mask QR codes & Barcodes'.
  static const String txtMaskQRCodesBarcodes = 'Mask QR codes & Barcodes';

  /// Extracted UI string: 'Mask Signatures'.
  static const String txtMaskSignatures = 'Mask Signatures';

  /// Extracted UI string: 'Strip EXIF & File Metadata'.
  static const String txtStripEXIFFileMetadata = 'Strip EXIF & File Metadata';

  /// Extracted UI string: '3. Watermark Preview'.
  static const String txtValue3WatermarkPreview = '3. Watermark Preview';

  /// Extracted UI string: '⚠️ Notice: Exported copies leave OwnKeep protection and cannot be remotely revoked.'.
  static const String
  txtNoticeExportedCopiesLeaveOwnKeepProtectionAndCannotBeRemotelyRevoked =
      '⚠️ Notice: Exported copies leave OwnKeep protection and cannot be remotely revoked.';

  /// Extracted UI string: 'Export Redacted & Watermarked Copy'.
  static const String txtExportRedactedWatermarkedCopy =
      'Export Redacted & Watermarked Copy';

  /// Extracted UI string: 'Item Metadata & Location'.
  static const String txtItemMetadataLocation = 'Item Metadata & Location';

  /// Extracted UI string: 'Update Operational Status'.
  static const String txtUpdateOperationalStatus = 'Update Operational Status';

  /// Extracted UI string: 'Transition item state while preserving complete historical service & cost records:'.
  static const String
  txtTransitionItemStateWhilePreservingCompleteHistoricalServiceCostRecords =
      'Transition item state while preserving complete historical service & cost records:';

  /// Extracted UI string: 'Total Lifetime Maintenance & Tax Spend'.
  static const String txtTotalLifetimeMaintenanceTaxSpend =
      'Total Lifetime Maintenance & Tax Spend';

  /// Extracted UI string: 'Save Event Log'.
  static const String txtSaveEventLog = 'Save Event Log';

  /// Extracted UI string: 'Private notes'.
  static const String txtPrivateNotes = 'Private notes';

  /// Extracted UI string: 'Aliases'.
  static const String txtAliases = 'Aliases';

  /// Extracted UI string: 'Import a photo first, then link it.'.
  static const String txtImportAPhotoFirstThenLinkIt =
      'Import a photo first, then link it.';

  /// Extracted UI string: 'Choose encrypted profile photo'.
  static const String txtChooseEncryptedProfilePhoto =
      'Choose encrypted profile photo';

  /// Extracted UI string: 'Import a record first.'.
  static const String txtImportARecordFirst = 'Import a record first.';

  /// Extracted UI string: 'Link encrypted evidence'.
  static const String txtLinkEncryptedEvidence = 'Link encrypted evidence';

  /// Extracted UI string: 'The original remains encrypted and unchanged.'.
  static const String txtTheOriginalRemainsEncryptedAndUnchanged =
      'The original remains encrypted and unchanged.';

  /// Extracted UI string: 'Add another profile first.'.
  static const String txtAddAnotherProfileFirst = 'Add another profile first.';

  /// Extracted UI string: 'No matching duplicate was found.'.
  static const String txtNoMatchingDuplicateWasFound =
      'No matching duplicate was found.';

  /// Extracted UI string: 'Choose duplicate to merge'.
  static const String txtChooseDuplicateToMerge = 'Choose duplicate to merge';

  /// Extracted UI string: 'The duplicate ID and history will be retained.'.
  static const String txtTheDuplicateIDAndHistoryWillBeRetained =
      'The duplicate ID and history will be retained.';

  /// Extracted UI string: 'Profile fields'.
  static const String txtProfileFields = 'Profile fields';

  /// Extracted UI string: 'No confirmed value yet'.
  static const String txtNoConfirmedValueYet = 'No confirmed value yet';

  /// Extracted UI string: 'Add custom field'.
  static const String txtAddCustomField = 'Add custom field';

  /// Extracted UI string: 'History and evidence are retained.'.
  static const String txtHistoryAndEvidenceAreRetained =
      'History and evidence are retained.';

  /// Extracted UI string: 'Merge a duplicate'.
  static const String txtMergeADuplicate = 'Merge a duplicate';

  /// Extracted UI string: 'Requires an exact same-name profile match.'.
  static const String txtRequiresAnExactSameNameProfileMatch =
      'Requires an exact same-name profile match.';

  /// Extracted UI string: 'Relationships'.
  static const String txtRelationships = 'Relationships';

  /// Extracted UI string: 'No relationships yet'.
  static const String txtNoRelationshipsYet = 'No relationships yet';

  /// Extracted UI string: 'REJECTED'.
  static const String txtREJECTED = 'REJECTED';

  /// Extracted UI string: 'History'.
  static const String txtHistory = 'History';

  /// Extracted UI string: 'No profile changes recorded yet'.
  static const String txtNoProfileChangesRecordedYet =
      'No profile changes recorded yet';

  /// Extracted UI string: 'Link encrypted record'.
  static const String txtLinkEncryptedRecord = 'Link encrypted record';

  /// Extracted UI string: 'No linked evidence yet.'.
  static const String txtNoLinkedEvidenceYet = 'No linked evidence yet.';

  /// Extracted UI string: 'Include rejected and superseded'.
  static const String txtIncludeRejectedAndSuperseded =
      'Include rejected and superseded';

  /// Extracted UI string: 'No Claims yet. Link a reviewed record from the Inbox.'.
  static const String txtNoClaimsYetLinkAReviewedRecordFromTheInbox =
      'No Claims yet. Link a reviewed record from the Inbox.';

  /// Extracted UI string: 'Build your private life map'.
  static const String txtBuildYourPrivateLifeMap =
      'Build your private life map';

  /// Extracted UI string: 'Add people, vehicles, properties, devices, and places. Everything stays encrypted on this device.'.
  static const String
  txtAddPeopleVehiclesPropertiesDevicesAndPlacesEverythingStaysEncryptedOnThisDevice =
      'Add people, vehicles, properties, devices, and places. Everything stays encrypted on this device.';

  /// Extracted UI string: 'Add your first profile'.
  static const String txtAddYourFirstProfile = 'Add your first profile';

  /// Extracted UI string: 'Custom encrypted field'.
  static const String txtCustomEncryptedField = 'Custom encrypted field';

  /// Extracted UI string: 'Text'.
  static const String txtText = 'Text';

  /// Extracted UI string: 'Identifier'.
  static const String txtIdentifier = 'Identifier';

  /// Extracted UI string: 'Website / URI'.
  static const String txtWebsiteURI = 'Website / URI';

  /// Extracted UI string: 'Save field'.
  static const String txtSaveField = 'Save field';

  /// Extracted UI string: 'Add relationship'.
  static const String txtAddRelationship = 'Add relationship';

  /// Extracted UI string: 'Household & Ownership'.
  static const String txtHouseholdOwnership = 'Household & Ownership';

  /// Extracted UI string: 'Active Valuation'.
  static const String txtActiveValuation = 'Active Valuation';

  /// Extracted UI string: 'All Categories'.
  static const String txtAllCategories = 'All Categories';

  /// Extracted UI string: 'Add Item'.
  static const String btnAddItem = 'Add Item';

  /// Extracted UI string: 'Add Household Item'.
  static const String txtAddHouseholdItem = 'Add Household Item';

  /// Extracted UI string: 'Save Item'.
  static const String txtSaveItem = 'Save Item';

  /// Extracted UI string: 'People, things & places'.
  static const String txtPeopleThingsPlaces = 'People, things & places';

  /// Extracted UI string: 'Tasks & checklists'.
  static const String txtTasksChecklists = 'Tasks & checklists';

  /// Extracted UI string: 'Your private life, organized locally.'.
  static const String txtYourPrivateLifeOrganizedLocally =
      'Your private life, organized locally.';

  /// Extracted UI string: 'Review local suggestions and finish organizing.'.
  static const String txtReviewLocalSuggestionsAndFinishOrganizing =
      'Review local suggestions and finish organizing.';

  /// Extracted UI string: 'Upcoming dues and expiries will appear here.'.
  static const String txtUpcomingDuesAndExpiriesWillAppearHere =
      'Upcoming dues and expiries will appear here.';

  /// Extracted UI string: 'Start building your private life record'.
  static const String txtStartBuildingYourPrivateLifeRecord =
      'Start building your private life record';

  /// Extracted UI string: 'Import a document and OwnKeep will organize it locally.'.
  static const String txtImportADocumentAndOwnKeepWillOrganizeItLocally =
      'Import a document and OwnKeep will organize it locally.';

  /// Extracted UI string: 'Open inbox'.
  static const String txtOpenInbox = 'Open inbox';

  /// Extracted UI string: 'Every result stays linked to your encrypted graph and evidence.'.
  static const String txtEveryResultStaysLinkedToYourEncryptedGraphAndEvidence =
      'Every result stays linked to your encrypted graph and evidence.';

  /// Extracted UI string: 'Nothing matched yet. Try a person, car, home, insurer, pack or record name.'.
  static const String
  txtNothingMatchedYetTryAPersonCarHomeInsurerPackOrRecordName =
      'Nothing matched yet. Try a person, car, home, insurer, pack or record name.';

  /// Extracted UI string: 'Suggested'.
  static const String txtSuggested = 'Suggested';

  /// Extracted UI string: 'This month'.
  static const String txtThisMonth = 'This month';

  /// Extracted UI string: 'Add event'.
  static const String txtAddEvent = 'Add event';

  /// Extracted UI string: 'Corrected'.
  static const String txtCorrected = 'Corrected';

  /// Extracted UI string: 'Evidence'.
  static const String txtEvidence = 'Evidence';

  /// Extracted UI string: 'No encrypted evidence linked.'.
  static const String txtNoEncryptedEvidenceLinked =
      'No encrypted evidence linked.';

  /// Extracted UI string: 'Reject'.
  static const String btnReject = 'Reject';

  /// Extracted UI string: 'Correct without overwriting'.
  static const String txtCorrectWithoutOverwriting =
      'Correct without overwriting';

  /// Extracted UI string: 'The original remains in history and this replacement keeps its entity and evidence links.'.
  static const String
  txtTheOriginalRemainsInHistoryAndThisReplacementKeepsItsEntityAndEvidenceLinks =
      'The original remains in history and this replacement keeps its entity and evidence links.';

  /// Extracted UI string: 'Date'.
  static const String txtDate = 'Date';

  /// Extracted UI string: 'Date range'.
  static const String txtDateRange = 'Date range';

  /// Extracted UI string: 'End date'.
  static const String txtEndDate = 'End date';

  /// Extracted UI string: 'No location'.
  static const String txtNoLocation = 'No location';

  /// Extracted UI string: 'Enter an event title.'.
  static const String txtEnterAnEventTitle = 'Enter an event title.';

  /// Extracted UI string: 'End date cannot be before start date.'.
  static const String txtEndDateCannotBeBeforeStartDate =
      'End date cannot be before start date.';

  /// Extracted UI string: 'Enter a valid amount.'.
  static const String txtEnterAValidAmount = 'Enter a valid amount.';

  /// Extracted UI string: 'Enter a currency code.'.
  static const String txtEnterACurrencyCode = 'Enter a currency code.';

  /// Extracted UI string: 'Organizational guidance'.
  static const String txtOrganizationalGuidance = 'Organizational guidance';

  /// Extracted UI string: 'Create a Smart Pack'.
  static const String txtCreateASmartPack = 'Create a Smart Pack';

  /// Extracted UI string: 'Templates guide organization and never change your facts.'.
  static const String txtTemplatesGuideOrganizationAndNeverChangeYourFacts =
      'Templates guide organization and never change your facts.';

  /// Extracted UI string: 'Use an offline template'.
  static const String txtUseAnOfflineTemplate = 'Use an offline template';

  /// Extracted UI string: 'Create a custom Pack'.
  static const String txtCreateACustomPack = 'Create a custom Pack';

  /// Extracted UI string: 'Offline Pack template'.
  static const String txtOfflinePackTemplate = 'Offline Pack template';

  /// Extracted UI string: 'Whole vault'.
  static const String txtWholeVault = 'Whole vault';

  /// Extracted UI string: 'Add India Pack suggestions'.
  static const String txtAddIndiaPackSuggestions = 'Add India Pack suggestions';

  /// Extracted UI string: 'Optional country-specific guidance, not legal advice.'.
  static const String txtOptionalCountrySpecificGuidanceNotLegalAdvice =
      'Optional country-specific guidance, not legal advice.';

  /// Extracted UI string: 'Create'.
  static const String btnCreate = 'Create';

  /// Extracted UI string: 'Custom Smart Pack'.
  static const String txtCustomSmartPack = 'Custom Smart Pack';

  /// Extracted UI string: 'Pack is archived.'.
  static const String txtPackIsArchived = 'Pack is archived.';

  /// Extracted UI string: 'Add custom item'.
  static const String txtAddCustomItem = 'Add custom item';

  /// Extracted UI string: 'Archive Pack'.
  static const String txtArchivePack = 'Archive Pack';

  /// Extracted UI string: 'Guidance, not a requirement'.
  static const String txtGuidanceNotARequirement =
      'Guidance, not a requirement';

  /// Extracted UI string: 'ORGANIZATIONAL ITEMS'.
  static const String txtORGANIZATIONALITEMS = 'ORGANIZATIONAL ITEMS';

  /// Extracted UI string: 'Review export preparation'.
  static const String txtReviewExportPreparation = 'Review export preparation';

  /// Extracted UI string: 'Customize item'.
  static const String txtCustomizeItem = 'Customize item';

  /// Extracted UI string: 'Applies to me'.
  static const String txtAppliesToMe = 'Applies to me';

  /// Extracted UI string: 'Optional'.
  static const String txtOptional = 'Optional';

  /// Extracted UI string: 'Prepare evidence for export'.
  static const String txtPrepareEvidenceForExport =
      'Prepare evidence for export';

  /// Extracted UI string: 'Does not create a plaintext export.'.
  static const String txtDoesNotCreateAPlaintextExport =
      'Does not create a plaintext export.';

  /// Extracted UI string: 'Link existing information'.
  static const String txtLinkExistingInformation = 'Link existing information';

  /// Extracted UI string: 'Links support organization; they do not change the source.'.
  static const String txtLinksSupportOrganizationTheyDoNotChangeTheSource =
      'Links support organization; they do not change the source.';

  /// Extracted UI string: 'Encrypted evidence'.
  static const String txtEncryptedEvidence = 'Encrypted evidence';

  /// Extracted UI string: 'Life Event'.
  static const String txtLifeEvent = 'Life Event';

  /// Extracted UI string: 'No linkable information yet'.
  static const String txtNoLinkableInformationYet =
      'No linkable information yet';

  /// Extracted UI string: 'Export preparation'.
  static const String txtExportPreparation = 'Export preparation';

  /// Extracted UI string: 'Done'.
  static const String btnDone = 'Done';

  /// Extracted UI string: 'Archive this Pack?'.
  static const String btnArchiveThisPack = 'Archive this Pack?';

  /// Extracted UI string: 'Linked Claims, Events, Tasks, and evidence remain unchanged.'.
  static const String btnLinkedClaimsEventsTasksAndEvidenceRemainUnchanged =
      'Linked Claims, Events, Tasks, and evidence remain unchanged.';

  /// Extracted UI string: 'Archive'.
  static const String btnArchive = 'Archive';

  /// Extracted UI string: 'Event'.
  static const String txtEvent = 'Event';

  /// Extracted UI string: 'Link information'.
  static const String txtLinkInformation = 'Link information';

  /// Extracted UI string: 'Customize'.
  static const String txtCustomize = 'Customize';

  /// Extracted UI string: 'Your facts remain yours'.
  static const String txtYourFactsRemainYours = 'Your facts remain yours';

  /// Extracted UI string: 'Changing a template only changes this checklist. It never changes confirmed facts or claims that an item is legally required.'.
  static const String
  txtChangingATemplateOnlyChangesThisChecklistItNeverChangesConfirmedFactsOrClaimsThatAnItemIsLegallyRequired =
      'Changing a template only changes this checklist. It never changes confirmed facts or claims that an item is legally required.';

  /// Extracted UI string: 'No Smart Packs yet'.
  static const String txtNoSmartPacksYet = 'No Smart Packs yet';

  /// Extracted UI string: 'Create a private organizational checklist from an offline template or make your own.'.
  static const String
  txtCreateAPrivateOrganizationalChecklistFromAnOfflineTemplateOrMakeYourOwn =
      'Create a private organizational checklist from an offline template or make your own.';

  /// Extracted UI string: 'Create Smart Pack'.
  static const String txtCreateSmartPack = 'Create Smart Pack';

  /// Extracted UI string: 'Notifications are local and contain no document details.'.
  static const String txtNotificationsAreLocalAndContainNoDocumentDetails =
      'Notifications are local and contain no document details.';

  /// Extracted UI string: 'Multilingual Invariance Guaranteed'.
  static const String txtMultilingualInvarianceGuaranteed =
      'Multilingual Invariance Guaranteed';

  /// Extracted UI string: 'Changing interface language does not alter stored Claim values, predicates, Entity IDs, evidence, or backup bytes.'.
  static const String
  txtChangingInterfaceLanguageDoesNotAlterStoredClaimValuesPredicatesEntityIDsEvidenceOrBackupBytes =
      'Changing interface language does not alter stored Claim values, predicates, Entity IDs, evidence, or backup bytes.';

  /// Extracted UI string: 'Grid document view'.
  static const String txtGridDocumentView = 'Grid document view';

  /// Extracted UI string: 'Use larger visual document cards.'.
  static const String txtUseLargerVisualDocumentCards =
      'Use larger visual document cards.';

  /// Extracted UI string: 'Dark mode'.
  static const String txtDarkMode = 'Dark mode';

  /// Extracted UI string: 'Stored inside your encrypted vault.'.
  static const String txtStoredInsideYourEncryptedVault =
      'Stored inside your encrypted vault.';

  /// Extracted UI string: 'Device security'.
  static const String txtDeviceSecurity = 'Device security';

  /// Extracted UI string: 'Biometric unlock'.
  static const String txtBiometricUnlock = 'Biometric unlock';

  /// Extracted UI string: 'Backup & recovery'.
  static const String txtBackupRecovery = 'Backup & recovery';

  /// Extracted UI string: 'Create encrypted backup'.
  static const String txtCreateEncryptedBackup = 'Create encrypted backup';

  /// Extracted UI string: 'Save a verified .cvault file to Drive, iCloud, Files, or another document provider.'.
  static const String
  txtSaveAVerifiedCvaultFileToDriveICloudFilesOrAnotherDocumentProvider =
      'Save a verified .cvault file to Drive, iCloud, Files, or another document provider.';

  /// Extracted UI string: 'Pair devices with ephemeral PIN codes for encrypted transfer.'.
  static const String txtPairDevicesWithEphemeralPINCodesForEncryptedTransfer =
      'Pair devices with ephemeral PIN codes for encrypted transfer.';

  /// Extracted UI string: 'Configure local WHEN / IF / THEN rules, preview execution, and inspect audit logs.'.
  static const String
  txtConfigureLocalWHENIFTHENRulesPreviewExecutionAndInspectAuditLogs =
      'Configure local WHEN / IF / THEN rules, preview execution, and inspect audit logs.';

  /// Extracted UI string: 'Configure user-selected blind cloud & NAS encrypted destinations.'.
  static const String
  txtConfigureUserSelectedBlindCloudNASEncryptedDestinations =
      'Configure user-selected blind cloud & NAS encrypted destinations.';

  /// Extracted UI string: 'Large-screen dual-pane overview and bulk import dropzone.'.
  static const String txtLargeScreenDualPaneOverviewAndBulkImportDropzone =
      'Large-screen dual-pane overview and bulk import dropzone.';

  /// Extracted UI string: 'No account, analytics, cloud OCR, advertisements, or Internet permission in release builds.'.
  static const String
  txtNoAccountAnalyticsCloudOCRAdvertisementsOrInternetPermissionInReleaseBuilds =
      'No account, analytics, cloud OCR, advertisements, or Internet permission in release builds.';

  /// Extracted UI string: 'OwnKeep 5.0.0'.
  static const String txtOwnKeep500 = 'OwnKeep 5.0.0';

  /// Extracted UI string: 'Encrypted P2P Transfer (No Server)'.
  static const String txtEncryptedP2PTransferNoServer =
      'Encrypted P2P Transfer (No Server)';

  /// Extracted UI string: 'Transferred vault archives are byte- and graph- equivalent, authenticated with SHA-256 signatures, and zero keys or plaintext leave your devices.'.
  static const String
  txtTransferredVaultArchivesAreByteAndGraphEquivalentAuthenticatedWithSHA256SignaturesAndZeroKeysOrPlaintextLeaveYourDevices =
      'Transferred vault archives are byte- and graph- equivalent, authenticated with SHA-256 signatures, and zero keys or plaintext leave your devices.';

  /// Extracted UI string: 'Select Transport Layer'.
  static const String txtSelectTransportLayer = 'Select Transport Layer';

  /// Extracted UI string: 'Ephemeral Pairing PIN Code'.
  static const String txtEphemeralPairingPINCode = 'Ephemeral Pairing PIN Code';

  /// Extracted UI string: 'Simulate Transfer Session'.
  static const String txtSimulateTransferSession = 'Simulate Transfer Session';

  /// Extracted UI string: 'Confirm the recovery warning to continue.'.
  static const String txtConfirmTheRecoveryWarningToContinue =
      'Confirm the recovery warning to continue.';

  /// Extracted UI string: 'Close and reopen the app. If this continues, preserve the app data until recovery or restore tools are available.'.
  static const String
  txtCloseAndReopenTheAppIfThisContinuesPreserveTheAppDataUntilRecoveryOrRestoreToolsAreAvailable =
      'Close and reopen the app. If this continues, preserve the app data until recovery or restore tools are available.';

  /// Extracted UI string: 'Evidence Documents'.
  static const String txtEvidenceDocuments = 'Evidence Documents';

  /// Extracted UI string: 'Add to OwnKeep'.
  static const String txtAddToOwnKeep = 'Add to OwnKeep';

  /// Extracted UI string: 'What would you like to add?'.
  static const String txtWhatWouldYouLikeToAdd = 'What would you like to add?';

  /// Extracted UI string: 'Capture & Import'.
  static const String txtCaptureImport = 'Capture & Import';

  /// Extracted UI string: 'Create a record'.
  static const String txtCreateARecord = 'Create a record';

  /// Extracted UI string: 'Needs review'.
  static const String txtNeedsReview = 'Needs review';

  /// Extracted UI string: 'Inbox is clean'.
  static const String txtInboxIsClean = 'Inbox is clean';

  /// Extracted UI string: 'New records will appear here for processing and review.'.
  static const String txtNewRecordsWillAppearHereForProcessingAndReview =
      'New records will appear here for processing and review.';

  /// Extracted UI string: 'Batch'.
  static const String txtBatch = 'Batch';

  /// Extracted UI string: 'Detecting edges and applying crop...'.
  static const String txtDetectingEdgesAndApplyingCrop =
      'Detecting edges and applying crop...';

  /// Extracted UI string: 'Retake'.
  static const String btnRetake = 'Retake';

  /// Extracted UI string: 'Review Scan'.
  static const String btnReviewScan = 'Review Scan';

  /// Extracted UI string: 'Scanned Document'.
  static const String txtScannedDocument = 'Scanned Document';

  /// Extracted UI string: 'Save to OwnKeep'.
  static const String btnSaveToOwnKeep = 'Save to OwnKeep';

  /// Extracted UI string: 'File information'.
  static const String txtFileInformation = 'File information';

  /// Extracted UI string: 'Extracted information'.
  static const String txtExtractedInformation = 'Extracted information';

  /// Extracted UI string: 'Linked to'.
  static const String txtLinkedTo = 'Linked to';

  /// Extracted UI string: 'Honda City ZX'.
  static const String txtHondaCityZX = 'Honda City ZX';

  /// Extracted UI string: 'Active reminder set'.
  static const String txtActiveReminderSet = 'Active reminder set';

  /// Extracted UI string: 'Filter by Type'.
  static const String txtFilterByType = 'Filter by Type';

  /// Extracted UI string: 'No records found'.
  static const String txtNoRecordsFound = 'No records found';

  /// Extracted UI string: 'Review Document'.
  static const String txtReviewDocument = 'Review Document';

  /// Extracted UI string: 'OwnKeep found'.
  static const String txtOwnKeepFound = 'OwnKeep found';

  /// Extracted UI string: 'Edit Fields'.
  static const String txtEditFields = 'Edit Fields';

  /// Extracted UI string: 'Link to'.
  static const String txtLinkTo = 'Link to';

  /// Extracted UI string: 'OwnKeep can suggest linking this document to:'.
  static const String msgSuggestLinkHeader =
      'OwnKeep can suggest linking this document to:';

  /// Extracted UI string: 'Add expiry reminder'.
  static const String txtAddExpiryReminder = 'Add expiry reminder';

  /// Extracted UI string: 'Confirm & Save'.
  static const String btnConfirmSave = 'Confirm & Save';

  /// Extracted UI string: 'User'.
  static const String txtUser = 'User';

  /// Extracted UI string: 'Good morning!'.
  static const String txtGoodMorning = 'Good morning!';

  /// Extracted UI string: 'Welcome to your secure Life OS.'.
  static const String msgWelcomeSecureLifeOS =
      'Welcome to your secure Life OS.';

  /// Extracted UI string: 'Add New'.
  static const String txtAddNew = 'Add New';

  /// Extracted UI string: 'Your private vault is ready.'.
  static const String lblYourPrivateVaultReady = 'Your private vault is ready.';

  /// Extracted UI string: 'Start by protecting something important.'.
  static const String msgStartProtectingImportant =
      'Start by protecting something important.';

  /// Extracted UI string: 'Passport • ID cards • Insurance • Bills • Certificates • Medical records • Property documents'.
  static const String msgEmptyVaultExamples =
      'Passport • ID cards • Insurance • Bills • Certificates • Medical records • Property documents';

  /// Extracted UI string: 'Add Your First Record'.
  static const String lblAddFirstRecord = 'Add Your First Record';

  /// Extracted UI string: 'Good Morning, Taraka'.
  static const String lblGoodMorningUser = 'Good Morning, Taraka';

  /// Extracted UI string: 'T'.
  static const String txtT = 'T';

  /// Extracted UI string: 'Search OwnKeep...'.
  static const String lblSearchOwnKeep = 'Search OwnKeep...';

  /// Extracted UI string: 'Everything is safe'.
  static const String lblEverythingIsSafe = 'Everything is safe';

  /// Extracted UI string: 'On this device • Encrypted'.
  static const String lblOnThisDeviceEncrypted = 'On this device • Encrypted';

  /// Extracted UI string: '3'.
  static const String lblAttentionCountBadge = '3';

  /// Extracted UI string: 'Upcoming'.
  static const String txtUpcoming = 'Upcoming';

  /// Extracted UI string: 'Recent Records'.
  static const String txtRecentRecords = 'Recent Records';

  /// Extracted UI string: 'See All'.
  static const String btnSeeAll = 'See All';

  /// Extracted UI string: '3 need attention • Last backup: Today'.
  static const String msgDashboardBackupStatus =
      '3 need attention • Last backup: Today';

  /// Extracted UI string: 'View Activity'.
  static const String btnViewActivity = 'View Activity';

  /// Extracted UI string: 'Biometric Unlock'.
  static const String lblBiometricUnlockTitle = 'Biometric Unlock';

  /// Extracted UI string: 'Dark Mode'.
  static const String lblDarkModeTitle = 'Dark Mode';

  /// Extracted UI string: 'Document View Grid'.
  static const String txtDocumentViewGrid = 'Document View Grid';

  /// Extracted UI string: 'Keep What Matters.\nOwn Your Data.'.
  static const String msgSplashTagline = 'Keep What Matters.\nOwn Your Data.';

  /// Extracted UI string: 'Recovery Passphrase / Recovery Key'.
  static const String lblRecoveryKey = 'Recovery Passphrase / Recovery Key';

  /// Extracted UI string: 'Saved securely'.
  static const String txtSavedSecurely = 'Saved securely';

  /// Extracted UI string: 'Create encrypted recovery backup'.
  static const String lblCreateRecoveryBackup =
      'Create encrypted recovery backup';

  /// Extracted UI string: 'Highly recommended'.
  static const String txtHighlyRecommended = 'Highly recommended';

  /// Extracted UI string: 'I've Saved My Recovery Key'.
  static const String btnSavedRecoveryKey = 'I\'ve Saved My Recovery Key';

  /// Extracted UI string: 'Choose Language'.
  static const String txtChooseLanguage = 'Choose Language';

  /// Extracted UI string: 'Select your language / अपनी भाषा चुनें'.
  static const String lblSelectLanguage =
      'Select your language / अपनी भाषा चुनें';

  /// Extracted UI string: 'Keep what matters.'.
  static const String lblKeepWhatMatters = 'Keep what matters.';

  /// Extracted UI string: 'Only you. Always.'.
  static const String lblOnlyYouAlways = 'Only you. Always.';

  /// Extracted UI string: 'Your private encrypted vault for important documents,\nrecords and memories.'.
  static const String msgVaultSubtitle =
      'Your private encrypted vault for important documents,\nrecords and memories.';

  /// Extracted UI string: 'Create New Vault'.
  static const String btnCreateNewVault = 'Create New Vault';

  /// Extracted UI string: 'Enable biometric unlock'.
  static const String txtEnableBiometricUnlock = 'Enable biometric unlock';

  /// Extracted UI string: 'Create Vault'.
  static const String btnCreateVaultConfirm = 'Create Vault';

  /// Extracted UI string: 'Welcome back'.
  static const String txtWelcomeBack = 'Welcome back';

  /// Extracted UI string: 'Unlock your private vault'.
  static const String lblUnlockPrivateVault = 'Unlock your private vault';

  /// Extracted UI string: 'Options: Face ID / Touch ID / Fingerprint\nor Enter vault passphrase'.
  static const String msgUnlockOptions =
      'Options: Face ID / Touch ID / Fingerprint\nor Enter vault passphrase';

  /// Extracted UI string: 'Unlock Vault'.
  static const String txtUnlockVault = 'Unlock Vault';

  /// Extracted UI string: 'Unlock'.
  static const String btnUnlock = 'Unlock';
}
