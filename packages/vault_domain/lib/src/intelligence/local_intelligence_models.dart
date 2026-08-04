import 'package:meta/meta.dart';

/// Evidence grounding reference for AI summaries.
@immutable
final class GroundingEvidence {
  /// Creates a grounding evidence item.
  const GroundingEvidence({
    required this.claimId,
    required this.documentId,
    required this.evidenceSnippet,
  });

  /// Linked vault claim ID.
  final String claimId;

  /// Source document ID.
  final String documentId;

  /// Grounded text snippet from verified OCR claim.
  final String evidenceSnippet;
}

/// Contextual, grounded summary of a vault document.
@immutable
final class IntelligenceSummary {
  /// Creates an intelligence summary.
  const IntelligenceSummary({
    required this.documentId,
    required this.title,
    required this.groundedSummary,
    required this.keyTakeaways,
    required this.groundingEvidence,
    this.confidenceScore = 1.0,
  });

  /// Target document ID.
  final String documentId;

  /// Document title.
  final String title;

  /// Grounded natural language summary text.
  final String groundedSummary;

  /// Key takeaway bullet points.
  final List<String> keyTakeaways;

  /// Grounding evidence references.
  final List<GroundingEvidence> groundingEvidence;

  /// Model confidence score.
  final double confidenceScore;
}

/// Grounded recommendation generated from vault facts.
@immutable
final class RecommendationItem {
  /// Creates a recommendation item.
  const RecommendationItem({
    required this.id,
    required this.title,
    required this.rationale,
    required this.category,
    this.isActionable = true,
  });

  /// Recommendation ID.
  final String id;

  /// Recommendation title.
  final String title;

  /// Fact-grounded rationale.
  final String rationale;

  /// Category label.
  final String category;

  /// Whether user can execute action.
  final bool isActionable;
}
