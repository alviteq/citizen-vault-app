import 'dart:async';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:citizen_vault_app/src/library/document_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Screen 07 — Inbox
/// Represents the pipeline: Imported → Processing → Review → Organized
final class IngestionScreen extends StatefulWidget {
  const IngestionScreen({required this.controller, super.key});

  final IngestionUiController controller;

  @override
  State<IngestionScreen> createState() => _IngestionScreenState();
}

enum _InboxFilter { all, processing, review, ready }

final class _IngestionScreenState extends State<IngestionScreen> {
  _InboxFilter _filter = _InboxFilter.all;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.controller.isVaultAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(widget.controller.recover());
      });
    }
  }

  @override
  void didUpdateWidget(IngestionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _review(DocumentReviewView review) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DocumentReviewScreen(review: review, controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Combine jobs and reviews for a unified pipeline list
    final List<Object> allItems = [
      ...widget.controller.jobs,
      ...widget.controller.reviews,
    ];
    final processingCount = widget.controller.jobs
        .where(
          (job) =>
              job.status != DocumentProcessingStatus.ready &&
              job.status != DocumentProcessingStatus.failed,
        )
        .length;
    final reviewCount = widget.controller.reviews.length;

    final filteredItems = allItems.where((item) {
      if (_filter == _InboxFilter.all) return true;
      if (item is DocumentProcessingView) {
        if (_filter == _InboxFilter.processing) {
          return item.status != DocumentProcessingStatus.ready &&
              item.status != DocumentProcessingStatus.failed;
        }
        if (_filter == _InboxFilter.ready) {
          return item.status == DocumentProcessingStatus.ready;
        }
      } else if (item is DocumentReviewView) {
        if (_filter == _InboxFilter.review) return true;
      }
      return false;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          AppStrings.inboxTitle.tr,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: const Icon(
                Icons.lock_outline,
                size: 17,
                color: Color(0xFF64748B),
              ),
              label: Text(
                AppStrings.txtOffline.tr,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                ),
              ),
              side: BorderSide.none,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: widget.controller.refresh,
          child: Column(
            children: [
              // Filters
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                color: Theme.of(context).colorScheme.surface,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        'All',
                        _InboxFilter.all,
                        allItems.length,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Processing',
                        _InboxFilter.processing,
                        processingCount,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Review',
                        _InboxFilter.review,
                        reviewCount,
                      ),
                    ],
                  ),
                ),
              ),

              // List
              Expanded(
                child: filteredItems.isEmpty
                    ? const Center(child: _EmptyProcessingState())
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          if (item is DocumentReviewView) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ReviewCard(
                                review: item,
                                onReview: () => _review(item),
                              ),
                            );
                          } else if (item is DocumentProcessingView) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ProcessingCard(job: item),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
              ),
              if (reviewCount > 0)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () =>
                            _review(widget.controller.reviews.first),
                        child: Text('Review All ($reviewCount)'.tr),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, _InboxFilter filter, int count) {
    final isSelected = _filter == filter;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.tr),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filter = filter);
      },
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}

final class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onReview});

  final DocumentReviewView review;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.fact_check_outlined,
            color: Color(0xFFD97706),
          ),
        ),
        title: Text(
          review.logicalFilename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          AppStrings.txtNeedsReview.tr,
          style: TextStyle(
            color: Color(0xFFD97706),
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: FilledButton.tonal(
          onPressed: onReview,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEFF6FF),
            foregroundColor: const Color(0xFF1D4ED8),
          ),
          child: Text(
            AppStrings.btnReview.tr,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ),
  );
}

final class _EmptyProcessingState extends StatelessWidget {
  const _EmptyProcessingState();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFF0FDF4),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFFBBF7D0),
        style: BorderStyle.solid,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.task_alt,
              size: 42,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.txtInboxIsClean.tr,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF166534),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.txtNewRecordsWillAppearHereForProcessingAndReview.tr,
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF15803D)),
          ),
        ],
      ),
    ),
  );
}

final class _ProcessingCard extends StatelessWidget {
  const _ProcessingCard({required this.job});

  final DocumentProcessingView job;

  @override
  Widget build(BuildContext context) {
    final isReady = job.status == DocumentProcessingStatus.ready;
    final isFailed = job.status == DocumentProcessingStatus.failed;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isReady
                  ? const Color(0xFFDCFCE7)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isReady ? Icons.check : _iconFor(job.mimeType),
              color: isReady
                  ? const Color(0xFF16A34A)
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          title: Text(
            job.logicalFilename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 6),
              Text(
                _labelFor(job.status) +
                    (job.status.progress > 0 && job.status.progress < 1
                        ? '... ${(job.status.progress * 100).toInt()}%'
                        : ''),
                style: TextStyle(
                  color: isReady
                      ? const Color(0xFF16A34A)
                      : (isFailed
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF64748B)),
                  fontWeight: isReady ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (job.status.progress > 0 && job.status.progress < 1) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: job.status.progress,
                  color: const Color(0xFF3B82F6),
                  backgroundColor: const Color(0xFFE2E8F0),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(String mimeType) => mimeType.startsWith('image/')
      ? Icons.image_outlined
      : mimeType == 'application/pdf'
      ? Icons.picture_as_pdf_outlined
      : Icons.description_outlined;

  static String _labelFor(DocumentProcessingStatus status) => switch (status) {
    DocumentProcessingStatus.registering => 'Securing original',
    DocumentProcessingStatus.queued => 'Waiting securely',
    DocumentProcessingStatus.processing => 'Extracting information',
    DocumentProcessingStatus.retryScheduled => 'Will retry automatically',
    DocumentProcessingStatus.awaitingReview => 'Waiting for your review',
    DocumentProcessingStatus.ready => 'Ready',
    DocumentProcessingStatus.failed => 'Needs attention',
  };
}
