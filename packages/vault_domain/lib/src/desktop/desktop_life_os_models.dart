import 'package:meta/meta.dart';

/// Desktop UI layout modes for large screens.
enum DesktopLayoutMode {
  /// Dual pane overview (Entity graph left, Timeline right).
  dualPane('Dual-Pane Life OS'),

  /// Expanded timeline focus.
  timelineFocus('Timeline Focus'),

  /// Detailed entity graph focus.
  entityFocus('Entity Graph Focus');

  const DesktopLayoutMode(this.displayName);

  /// Layout display label.
  final String displayName;
}

/// Progress state for desktop large-scale bulk import jobs.
@immutable
final class BulkImportJobProgress {
  /// Creates a bulk import progress snapshot.
  const BulkImportJobProgress({
    required this.totalFiles,
    required this.processedFiles,
    required this.currentFileName,
    required this.statusMessage,
  });

  /// Total files queued.
  final int totalFiles;

  /// Processed count so far.
  final int processedFiles;

  /// Active filename being ingested.
  final String currentFileName;

  /// Status description.
  final String statusMessage;

  /// Fractional progress (0.0 to 1.0).
  double get fraction =>
      totalFiles > 0 ? (processedFiles / totalFiles).clamp(0.0, 1.0) : 0.0;
}

/// Desktop window configuration & keyboard shortcuts state.
@immutable
final class DesktopWindowConfig {
  /// Creates desktop window configuration.
  const DesktopWindowConfig({
    this.layoutMode = DesktopLayoutMode.dualPane,
    this.isSidebarExpanded = true,
    this.activeShortcutHelp = false,
  });

  /// Layout mode.
  final DesktopLayoutMode layoutMode;

  /// Whether desktop sidebar navigation is expanded.
  final bool isSidebarExpanded;

  /// Whether keyboard shortcut help overlay is visible.
  final bool activeShortcutHelp;
}
