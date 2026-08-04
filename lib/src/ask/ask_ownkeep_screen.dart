import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Screen presenting deterministic Ask OwnKeep query traversals.
final class AskOwnKeepScreen extends StatefulWidget {
  /// Creates the Ask OwnKeep search screen.
  const AskOwnKeepScreen({required this.controller, super.key});

  /// Ingestion and presentation controller.
  final IngestionUiController controller;

  @override
  State<AskOwnKeepScreen> createState() => _AskOwnKeepScreenState();
}

final class _AskOwnKeepScreenState extends State<AskOwnKeepScreen> {
  final _searchCtrl = TextEditingController();
  AskQueryCategory? _selectedCategory;
  AskQueryResponse? _response;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _runQuery(String queryText) {
    if (queryText.trim().isEmpty) return;
    final res = widget.controller.askVault(
      queryText.trim(),
      category: _selectedCategory,
    );
    setState(() => _response = res);
  }

  @override
  Widget build(BuildContext context) {
    final resp = _response;
    final tr = widget.controller.multilingualEngine.translate;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          tr('Ask OwnKeep'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        size: 20,
                        color: Color(0xFF0B4A99),
                      ),
                      SizedBox(width: 8),
                      Text(
                        AppStrings.txtDeterministicGraphAnswers.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF0B4A99),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    AppStrings
                        .txtAskOwnKeepParsesFactsDirectlyFromYourEncryptedGraphAndEvidenceDocumentsWithoutLLMHallucinationsOrCloudCalls
                        .tr,
                    style: TextStyle(fontSize: 13, color: Color(0xFF1E3A8A)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. What warranties do I have?',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF0B4A99)),
                  onPressed: () => _runQuery(_searchCtrl.text),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: Color(0xFF0B4A99),
                    width: 1.5,
                  ),
                ),
              ),
              onSubmitted: _runQuery,
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.shield_outlined, size: 14),
                    label: Text(AppStrings.warrantiesChip.tr),
                    onPressed: () {
                      _searchCtrl.text = 'What warranties do I have?';
                      _runQuery(_searchCtrl.text);
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.account_balance_wallet, size: 14),
                    label: Text(AppStrings.totalSpendChip.tr),
                    onPressed: () {
                      _searchCtrl.text =
                          'How much maintenance spend is logged?';
                      _runQuery(_searchCtrl.text);
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.home, size: 14),
                    label: Text(AppStrings.householdValuationChip.tr),
                    onPressed: () {
                      _searchCtrl.text = 'What household items do I own?';
                      _runQuery(_searchCtrl.text);
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.inventory_2, size: 14),
                    label: Text(AppStrings.smartPacksChip.tr),
                    onPressed: () {
                      _searchCtrl.text = 'What smart packs are prepared?';
                      _runQuery(_searchCtrl.text);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (resp != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: resp.isAvailable
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFFEDD5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                resp.isAvailable
                                    ? Icons.check_circle
                                    : Icons.help_outline,
                                size: 14,
                                color: resp.isAvailable
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                resp.isAvailable
                                    ? 'Fact Verified'
                                    : 'Missing Fact',
                                style: TextStyle(
                                  color: resp.isAvailable
                                      ? const Color(0xFF065F46)
                                      : const Color(0xFF9A3412),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            resp.category.displayName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      resp.answerText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Graph Traversal (${resp.explanationSteps.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final s in resp.explanationSteps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${s.stepNumber}. ${s.description}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    if (resp.evidenceDocumentIds.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.txtEvidenceDocuments.tr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final docId in resp.evidenceDocumentIds)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.description_outlined,
                                size: 14,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                docId,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF3B82F6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ] else
              Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    AppStrings
                        .txtTypeAQueryOrTapATemplateAboveToQueryYourVault
                        .tr,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
