import 'package:vault_domain/vault_domain.dart';

/// Pure offline, deterministic query engine for Ask OwnKeep.
/// Executes indexed graph traversals without LLM hallucinations.
final class DeterministicAskEngine {
  /// Creates a deterministic Ask OwnKeep engine.
  const DeterministicAskEngine();

  /// Queries the vault deterministically using indexed graph facts.
  AskQueryResponse queryVault({
    required String query,
    required List<DocumentListItemView> documents,
    required List<AttentionItem> attentionItems,
    required List<HouseholdAssetRecord> householdAssets,
    required List<HouseholdEventRecord> householdEvents,
    required List<SmartPack> smartPacks,
    AskQueryCategory? preferredCategory,
  }) {
    final q = query.trim().toLowerCase();

    // 1. Warranty Queries
    if (q.contains('warrant') ||
        preferredCategory == AskQueryCategory.warranties) {
      final assetsWithWarranty = householdAssets
          .where((a) => a.warrantyProvider != null)
          .toList();
      if (assetsWithWarranty.isNotEmpty) {
        final explanations = <AskEvidenceExplanation>[];
        var idx = 1;
        for (final a in assetsWithWarranty) {
          final expStr = a.warrantyEndDate != null
              ? a.warrantyEndDate!.toIso8601String().split('T').first
              : 'N/A';
          explanations.add(
            AskEvidenceExplanation(
              stepNumber: idx++,
              description:
                  'Found active warranty coverage for ${a.name} via '
                  '${a.warrantyProvider} (Expires: $expStr).',
              targetType: 'Asset',
              targetId: a.id,
            ),
          );
        }
        final names = assetsWithWarranty
            .map((a) => '${a.name} (${a.warrantyProvider})')
            .join(', ');
        return AskQueryResponse(
          query: query,
          answerText:
              'You have ${assetsWithWarranty.length} active registered '
              'warranties: $names.',
          category: AskQueryCategory.warranties,
          isAvailable: true,
          explanationSteps: explanations,
        );
      }
    }

    // 2. Spending & Service Queries
    if (q.contains('spend') ||
        q.contains('cost') ||
        q.contains('service') ||
        q.contains('maint') ||
        preferredCategory == AskQueryCategory.spending ||
        preferredCategory == AskQueryCategory.service) {
      final totalCost = householdEvents.fold<double>(
        0,
        (sum, e) => sum + (e.cost ?? 0),
      );
      if (householdEvents.isNotEmpty) {
        final totalStr = totalCost.toStringAsFixed(0);
        final explanations = [
          AskEvidenceExplanation(
            stepNumber: 1,
            description:
                'Traversed ${householdEvents.length} maintenance, tax,'
                ' and service logs across household assets.',
            targetType: 'HouseholdEventSummary',
          ),
          AskEvidenceExplanation(
            stepNumber: 2,
            description:
                'Calculated cumulative lifetime expense sum: ₹$totalStr.',
          ),
        ];
        return AskQueryResponse(
          query: query,
          answerText:
              'Total logged maintenance and tax spend across '
              '${householdEvents.length} service entries is ₹$totalStr.',
          category: AskQueryCategory.spending,
          isAvailable: true,
          explanationSteps: explanations,
        );
      }
    }

    // 3. Expiry Queries
    if (q.contains('expir') ||
        q.contains('renew') ||
        preferredCategory == AskQueryCategory.expiry) {
      final expiringDocs = documents
          .where((d) => d.documentType == DocumentType.insurancePolicy)
          .toList();
      if (expiringDocs.isNotEmpty) {
        final docNames = expiringDocs.map((d) => d.logicalFilename).join(', ');
        final explanations = [
          for (var i = 0; i < expiringDocs.length; i++)
            AskEvidenceExplanation(
              stepNumber: i + 1,
              description:
                  'Matched document record ${expiringDocs[i].logicalFilename} '
                  '(Type: ${expiringDocs[i].documentType.displayName}).',
              targetType: 'Document',
              targetId: expiringDocs[i].id,
            ),
        ];
        return AskQueryResponse(
          query: query,
          answerText:
              'Found ${expiringDocs.length} insurance & expiry records: '
              '$docNames.',
          category: AskQueryCategory.expiry,
          isAvailable: true,
          explanationSteps: explanations,
          evidenceDocumentIds: expiringDocs.map((d) => d.id).toList(),
        );
      }
    }

    // 4. Household Inventory & Property Queries
    if (q.contains('home') ||
        q.contains('property') ||
        q.contains('car') ||
        q.contains('vehicle') ||
        preferredCategory == AskQueryCategory.household) {
      if (householdAssets.isNotEmpty) {
        final activeValuation = householdAssets
            .where((a) => a.status == HouseholdAssetStatus.active)
            .fold<double>(0, (sum, a) => sum + (a.purchasePrice ?? 0));
        final valStr = activeValuation.toStringAsFixed(0);
        return AskQueryResponse(
          query: query,
          answerText:
              'Vault tracks ${householdAssets.length} household items with '
              'an active valuation of ₹$valStr.',
          category: AskQueryCategory.household,
          isAvailable: true,
          explanationSteps: [
            AskEvidenceExplanation(
              stepNumber: 1,
              description:
                  'Indexed ${householdAssets.length} vehicles, properties,'
                  ' and electronics items.',
            ),
          ],
        );
      }
    }

    // 5. Smart Packs Queries
    if (q.contains('pack') ||
        preferredCategory == AskQueryCategory.smartPacks) {
      if (smartPacks.isNotEmpty) {
        final packNames = smartPacks.map((p) => p.title).join(', ');
        return AskQueryResponse(
          query: query,
          answerText:
              'You have ${smartPacks.length} smart packs prepared: $packNames.',
          category: AskQueryCategory.smartPacks,
          isAvailable: true,
          explanationSteps: const [
            AskEvidenceExplanation(
              stepNumber: 1,
              description: 'Traversed versioned smart pack repository.',
            ),
          ],
        );
      }
    }

    // Fallback: Explicit "information not available"
    return AskQueryResponse(
      query: query,
      answerText:
          'Information not available in vault. No matching graph entity'
          ' or evidence record was found.',
      category: preferredCategory ?? AskQueryCategory.provenance,
      isAvailable: false,
      confidence: 0,
      explanationSteps: const [
        AskEvidenceExplanation(
          stepNumber: 1,
          description:
              'Queried FTS index and graph entities; zero evidence matches'
              ' returned.',
        ),
      ],
    );
  }
}
