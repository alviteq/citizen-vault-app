import 'package:citizen_vault_app/src/backup/backup_archive_transfer.dart';
import 'package:citizen_vault_app/src/design/ownkeep_figma_screens.dart';
import 'package:citizen_vault_app/src/design/ownkeep_theme.dart';
import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:citizen_vault_app/src/library/vault_home_screen.dart';
import 'package:citizen_vault_app/src/vault/splash_screen.dart';
import 'package:citizen_vault_app/src/vault/vault_gate.dart';
import 'package:citizen_vault_app/src/vault/vault_lifecycle.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Root widget for the OwnKeep application shell.
final class CitizenVaultApp extends StatefulWidget {
  /// Creates the app with optional test/integration composition overrides.
  const CitizenVaultApp({
    this.ingestionController,
    this.vaultLifecycle,
    this.backupTransfer,
    super.key,
  });

  /// Supplied after onboarding/unlock owns the encrypted vault session.
  final IngestionUiController? ingestionController;

  /// Optional lifecycle override. Production resolves app-private storage.
  final VaultLifecycle? vaultLifecycle;

  /// Optional system document-provider override for tests.
  final BackupArchiveTransfer? backupTransfer;

  @override
  State<CitizenVaultApp> createState() => _CitizenVaultAppState();
}

final class _CitizenVaultAppState extends State<CitizenVaultApp> {
  Future<LocalVaultLifecycle>? _productionLifecycle;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    if (widget.ingestionController == null && widget.vaultLifecycle == null) {
      _productionLifecycle = LocalVaultLifecycle.applicationSupport();
    }
    _router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) {
            final controller = widget.ingestionController;
            if (controller != null) {
              return VaultHomeScreen(controller: controller);
            }
            final lifecycle = widget.vaultLifecycle;
            if (lifecycle != null) {
              return VaultGate(
                lifecycle: lifecycle,
                backupTransfer:
                    widget.backupTransfer ??
                    const PlatformBackupArchiveTransfer(),
              );
            }
            return FutureBuilder<LocalVaultLifecycle>(
              future: _productionLifecycle,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return VaultGate(
                    lifecycle: snapshot.requireData,
                    backupTransfer:
                        widget.backupTransfer ??
                        const PlatformBackupArchiveTransfer(),
                  );
                }
                if (snapshot.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Text(
                        AppStrings.txtOwnKeepCouldNotAccessPrivateStorage.tr,
                      ),
                    ),
                  );
                }
                return OwnKeepSplashScreen();
              },
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.ingestionController;
    if (controller != null) {
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final langCode =
              controller.multilingualEngine.preferences.uiLanguage.code;
          return MaterialApp.router(
            title: 'OwnKeep',
            debugShowCheckedModeBanner: false,
            locale: Locale(langCode),
            theme: OwnKeepTheme.light,
            darkTheme: OwnKeepTheme.dark,
            routerConfig: _router,
          );
        },
      );
    }

    return MaterialApp.router(
      title: 'OwnKeep',
      debugShowCheckedModeBanner: false,
      theme: OwnKeepTheme.light,
      darkTheme: OwnKeepTheme.dark,
      routerConfig: _router,
    );
  }
}
