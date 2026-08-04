import 'package:meta/meta.dart';

/// Categories for deterministic vault query questions.
enum AskQueryCategory {
  /// Questions about attention items and pending review tasks.
  attention('Attention & Tasks'),

  /// Questions about upcoming expiration dates and document renewals.
  expiry('Expiry & Renewals'),

  /// Questions about vehicle/device maintenance and service history.
  service('Service & Repairs'),

  /// Questions about cumulative spending and payments.
  spending('Spending & Payments'),

  /// Questions about household items, property taxes, and inventory.
  household('Household & Property'),

  /// Questions about active warranties and protection plans.
  warranties('Warranties'),

  /// Questions about smart pack completeness and missing items.
  smartPacks('Smart Packs'),

  /// Questions about fact provenance and OCR source evidence.
  provenance('Source Provenance');

  const AskQueryCategory(this.displayName);

  /// Human-readable category label.
  final String displayName;
}

/// A step-by-step explainable graph traversal explanation.
@immutable
final class AskEvidenceExplanation {
  /// Creates an evidence explanation step.
  const AskEvidenceExplanation({
    required this.stepNumber,
    required this.description,
    this.targetType,
    this.targetId,
  });

  /// Step index (1-based).
  final int stepNumber;

  /// Clear explanation text of how facts were joined.
  final String description;

  /// Entity or document target type.
  final String? targetType;

  /// Entity or document ID.
  final String? targetId;
}

/// Structured evidence-linked response returned by Ask OwnKeep.
@immutable
final class AskQueryResponse {
  /// Creates an Ask OwnKeep response.
  const AskQueryResponse({
    required this.query,
    required this.answerText,
    required this.category,
    required this.isAvailable,
    this.confidence = 1.0,
    this.explanationSteps = const <AskEvidenceExplanation>[],
    this.evidenceDocumentIds = const <String>[],
  });

  /// Original query text.
  final String query;

  /// Deterministic answer text.
  final String answerText;

  /// Identified query category.
  final AskQueryCategory category;

  /// False if fact is not present in indexed vault graph.
  final bool isAvailable;

  /// Query confidence score (1.0 for exact graph match).
  final double confidence;

  /// Step-by-step traversal explanation.
  final List<AskEvidenceExplanation> explanationSteps;

  /// Linked document evidence IDs.
  final List<String> evidenceDocumentIds;
}
