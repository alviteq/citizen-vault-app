// Immutable view fields are documented at their type boundaries.
// ignore_for_file: public_member_api_docs

import 'package:meta/meta.dart';
import 'package:vault_domain/src/intelligence/document_intelligence_models.dart';

enum DocumentSort { newest, oldest, name, type, upcomingReminder }

@immutable
final class DocumentLibraryFilter {
  const DocumentLibraryFilter({
    this.query = '',
    this.type,
    this.tagId,
    this.favouritesOnly = false,
    this.archivedOnly = false,
    this.deletedOnly = false,
    this.sort = DocumentSort.newest,
  });

  final String query;
  final DocumentType? type;
  final String? tagId;
  final bool favouritesOnly;
  final bool archivedOnly;
  final bool deletedOnly;
  final DocumentSort sort;
}

@immutable
final class DocumentTagView {
  const DocumentTagView({required this.id, required this.name});

  final String id;
  final String name;
}

@immutable
final class DocumentListItemView {
  const DocumentListItemView({
    required this.id,
    required this.logicalFilename,
    required this.documentType,
    required this.mimeType,
    required this.status,
    required this.integrityStatus,
    required this.importedAt,
    required this.isFavourite,
    required this.isArchived,
    required this.tags,
    this.isDeleted = false,
    this.nextReminderAt,
    this.expiryAt,
  });

  final String id;
  final String logicalFilename;
  final DocumentType documentType;
  final String mimeType;
  final String status;
  final String integrityStatus;
  final DateTime importedAt;
  final bool isFavourite;
  final bool isArchived;
  final bool isDeleted;
  final List<DocumentTagView> tags;
  final DateTime? nextReminderAt;
  final DateTime? expiryAt;
}

@immutable
final class DocumentTextPageView {
  const DocumentTextPageView({required this.pageNumber, required this.text});

  final int? pageNumber;
  final String text;
}

@immutable
final class DocumentAssetView {
  const DocumentAssetView({
    required this.assetType,
    required this.mimeType,
    required this.createdAt,
  });

  final String assetType;
  final String mimeType;
  final DateTime createdAt;
}

@immutable
final class ProcessingHistoryView {
  const ProcessingHistoryView({
    required this.stepName,
    required this.status,
    required this.attemptCount,
    this.completedAt,
    this.errorCode,
  });

  final String stepName;
  final String status;
  final int attemptCount;
  final DateTime? completedAt;
  final String? errorCode;
}

@immutable
final class DocumentDetailView {
  const DocumentDetailView({
    required this.summary,
    required this.fields,
    required this.textPages,
    required this.assets,
    required this.processingHistory,
  });

  final DocumentListItemView summary;
  final List<ExtractedFieldView> fields;
  final List<DocumentTextPageView> textPages;
  final List<DocumentAssetView> assets;
  final List<ProcessingHistoryView> processingHistory;
}

@immutable
final class VaultPreferencesView {
  const VaultPreferencesView({
    required this.useGrid,
    required this.darkMode,
    required this.defaultReminderOffsets,
    this.lastBackupAt,
    this.lastBackupObjectCount,
  });

  const VaultPreferencesView.defaults()
    : useGrid = false,
      darkMode = false,
      defaultReminderOffsets = const <int>[30, 7, 1],
      lastBackupAt = null,
      lastBackupObjectCount = null;

  final bool useGrid;
  final bool darkMode;
  final List<int> defaultReminderOffsets;
  final DateTime? lastBackupAt;
  final int? lastBackupObjectCount;
}
