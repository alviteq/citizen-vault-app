import 'package:test/test.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

void main() {
  group('DesktopLifeOsEngine (Milestone 25 Gate)', () {
    late DesktopLifeOsEngine desktopEngine;

    setUp(() {
      desktopEngine = DesktopLifeOsEngine();
    });

    test('updates desktop layout mode and sidebar state', () {
      expect(
        desktopEngine.windowConfig.layoutMode,
        DesktopLayoutMode.dualPane,
      );

      desktopEngine.setLayoutMode(DesktopLayoutMode.timelineFocus);
      expect(
        desktopEngine.windowConfig.layoutMode,
        DesktopLayoutMode.timelineFocus,
      );

      desktopEngine.toggleSidebar();
      expect(desktopEngine.windowConfig.isSidebarExpanded, isFalse);
    });

    test('executes desktop bulk import processing queue', () {
      final prog = desktopEngine.processBulkImport(
        filePaths: const ['/docs/doc1.pdf', '/docs/doc2.pdf'],
      );

      expect(prog.totalFiles, 2);
      expect(prog.fraction, 1.0);
      expect(prog.statusMessage, contains('Processed 2 files'));
    });

    test('verifies cross-platform graph compatibility (Milestone 25 Gate)', () {
      final isCompatible = desktopEngine.verifyCrossPlatformGraphCompatibility(
        mobileSchemaVersion: '5.0.0',
        desktopSchemaVersion: '5.0.0',
      );

      expect(isCompatible, isTrue);
    });
  });
}
