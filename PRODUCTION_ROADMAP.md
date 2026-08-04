# OwnKeep production roadmap

Status legend: `[ ]` pending, `[~]` in progress, `[x]` complete.

- [x] Phase 1 — Localization completeness
- [x] Phase 2 — Regional OCR
- [x] Phase 3 — End-to-end document lifecycle tests
- [x] Phase 4 — Document management
- [x] Phase 5 — Search and organization
- [x] Phase 6 — Review and reminders
- [x] Phase 7 — Backup and recovery
- [x] Phase 8 — Security and biometric QA
- [x] Phase 9 — Sharing and export
- [x] Phase 10 — Storage management
- [x] Phase 11 — Accessibility and UI polish
- [x] Phase 12 — Performance and reliability
- [x] Phase 13 — Release preparation
- [x] Phase 14 — Restore Document Detail parity
- [x] Phase 15 — Complete categories and tag management
- [x] Phase 16 — Reconnect People, Things and Places
- [x] Phase 17 — Restore document-to-entity linking
- [x] Phase 18 — Reconnect global search, timeline and attention
- [~] Phase 19 — Capture/review software complete; hardware scan QA pending
- [~] Phase 20 — Lifecycle polish complete; permanent purge intentionally pending

Detailed acceptance items and the regression inventory are maintained in
[`FEATURE_GAP_REGISTER.md`](FEATURE_GAP_REGISTER.md).

## 5.0 restoration result

- Document Detail again exposes tags, extracted fields, page-separated OCR,
  reminders, linked records, metadata, integrity, processing history, type
  correction and safe reprocessing.
- Categories cover every Records group and display live counts. Tags can be
  renamed, merged by normalized rename, removed and audited with record counts.
- People, Things and Places are reachable from Home; global search, Timeline,
  Needs Attention, Tasks and Ask OwnKeep are connected to their existing
  encrypted repositories.
- Review supports a zoomable encrypted preview, type/field edits, initial tags,
  reminder creation and confirmed entity linking. Document links can be added
  and removed while retaining graph audit evidence.
- Home uses live reminders and persists the date/object count of the last
  verified backup. Record thumbnails use bounded encrypted previews.
- Safe reprocessing preserves the original and OCR asset, regenerates derived
  classification/extraction/search data and returns the document to Review.

The two remaining gates are deliberately not represented as completed software:

- Multi-page crop/rotate/reorder and camera behavior require physical-device
  validation because the simulator has no representative document camera.
- Irreversible purge is withheld until its cross-graph and backup-retention
  migration has dedicated destructive-path tests. Recoverable encrypted Trash,
  restore and retention-safe orphan cleanup remain available.

## Current batch acceptance gates

### Phase 1

- Every active user-facing string passes through the offline translator.
- Interface and OCR language preferences persist independently.
- Navigation, dialogs, errors, empty states, and settings update immediately.
- Locale regression tests cover the primary application shell.

### Phase 2

- OCR selection is capability-aware and never silently claims unsupported
  recognition.
- Selected OCR language reaches each newly created OCR request.
- Android and iOS native bridges compile and apply supported recognition models.
- OCR selection and persistence have automated coverage.

### Phase 3

- An encrypted import is processed, reviewed, searchable, opened, archived,
  restored, backed up, and reopened in an automated integration journey.
- Interrupted picker/worker behavior and persistence across unlock are covered.
- Static analysis, the complete test suite, and Android/iOS compilation pass.

### Phase 7

- Portable backups are encrypted, authenticated, and verified before export.
- Restore checks available storage and never overwrites an active vault.
- Wrong credentials and corrupted archives fail without creating a partial vault.
- Documents, OCR text, review state, organization, and originals survive restore.
- Temporary backup archives are deleted after export or cancellation.

### Phase 8

- Backgrounding immediately covers sensitive UI and closes an idle vault session.
- Active picker, ingestion, and backup operations hold a bounded activity lease.
- Biometric keys are device-only and recovery credentials remain the fallback.
- Changed or invalidated biometric enrollment fails closed.
- Closing the vault destroys in-memory key material and decrypted leases.

### Phase 9

- Original export requires an explicit plaintext warning.
- Redacted image export burns masks and a recipient/purpose/date watermark into
  a flattened metadata-free PNG.
- Unsupported inputs fail closed; original bytes are never silently exported as
  a supposedly redacted copy.
- Temporary plaintext export files and decrypted leases are removed after
  success, cancellation, or failure.
- Exported copies clearly warn that OwnKeep cannot remotely revoke them.

### Phase 10

- Storage usage separates SQLCipher, encrypted objects, temporary files, and
  protected metadata without exposing private paths.
- Users can safely trigger bounded cleanup of expired leases, interrupted
  writes, and eligible unreferenced objects.
- Archived and recently deleted records remain directly accessible from storage
  management.
- Cleanup never deletes a referenced document object.

### Phase 11

- Global button and icon-button themes enforce 48-point minimum touch targets.
- Primary actions expose text labels or accessibility tooltips.
- Loading, empty, error, destructive, and privacy states remain explicit.
- Dynamic themes, offline locale changes, and scalable Material layouts are
  preserved across the primary shell.

### Phase 12

- Import, OCR, backup, restore, and export remain bounded by one active vault
  operation and release resources in `finally` paths.
- Object writes publish atomically and startup recovery cleans recognized
  partial files, expired leases, and eligible orphans.
- Search, document lists, previews, and worker drains use bounded result/work
  limits.
- Regression tests cover interruption, corruption, recovery, and complete
  encrypted document persistence.

### Phase 13

- Android disables screenshots and OS cloud/device backup of private vault
  storage.
- Android and iOS declare only required platform capabilities and purpose text.
- Debug Android and iOS simulator builds, static analysis, package tests, and
  app tests form the release gate.
- Release signing remains outside source control and release scripts fail
  closed when credentials are absent.
- Physical-device integration suites remain available for Android and iOS
  hardware validation before store submission.
