import 'dart:async';
import 'package:citizen_vault_app/src/backup/backup_archive_transfer.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:citizen_vault_app/src/library/vault_home_screen.dart';
import 'package:citizen_vault_app/src/vault/splash_screen.dart';
import 'package:citizen_vault_app/src/vault/user_agreement_screen.dart';
import 'package:citizen_vault_app/src/vault/vault_lifecycle.dart';
import 'package:flutter/material.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_domain/vault_domain.dart';

/// Loads onboarding, unlock, or the unlocked vault without opening storage
/// before authentication.
final class VaultGate extends StatefulWidget {
  /// Creates a gate backed by [lifecycle].
  const VaultGate({
    required this.lifecycle,
    this.backupTransfer = const PlatformBackupArchiveTransfer(),
    super.key,
  });

  /// Secure local vault lifecycle.
  final VaultLifecycle lifecycle;

  /// System document-provider bridge.
  final BackupArchiveTransfer backupTransfer;

  @override
  State<VaultGate> createState() => _VaultGateState();
}

enum _GateStage { loading, create, restore, unlock, opening, open, failed }

final class _VaultGateState extends State<VaultGate>
    with WidgetsBindingObserver {
  _GateStage _stage = _GateStage.loading;
  UnlockedVaultHandle? _handle;
  String? _error;
  var _privacyCovered = false;
  var _biometricEnabled = false;
  SelectedBackupArchive? _selectedRestoreArchive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_privacyCovered && mounted) {
          setState(() => _privacyCovered = false);
        }
      case AppLifecycleState.inactive:
        if (!_privacyCovered && mounted) {
          setState(() => _privacyCovered = true);
        }
      case AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        if (!_privacyCovered && mounted) {
          setState(() => _privacyCovered = true);
        }
        final handle = _handle;
        if (handle != null && !handle.isBusy) {
          unawaited(_lockForBackground(handle));
        }
    }
  }

  Future<void> _lockForBackground(UnlockedVaultHandle handle) async {
    if (!identical(_handle, handle)) return;
    _handle = null;
    if (mounted) {
      setState(() {
        _stage = _GateStage.unlock;
        _error = null;
      });
    }
    await handle.close();
  }

  Future<void> _load() async {
    try {
      final exists = await widget.lifecycle.exists();
      final biometricEnabled =
          exists && await widget.lifecycle.biometricEnabled();
      if (!mounted) return;
      setState(() {
        _biometricEnabled = biometricEnabled;
        _stage = exists ? _GateStage.unlock : _GateStage.create;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _stage = _GateStage.failed;
        _error = 'OwnKeep could not access its private storage.';
      });
    }
  }

  Future<void> _create(String passphrase, bool enableBiometrics) async {
    await _open(
      () => widget.lifecycle.create(recoveryPassphrase: passphrase),
      failureStage: _GateStage.create,
    );
    if (enableBiometrics && _stage == _GateStage.open) {
      try {
        await widget.lifecycle.enableBiometrics(recoveryPassphrase: passphrase);
        if (mounted) setState(() => _biometricEnabled = true);
      } on VaultLifecycleFailure {
        // Vault creation remains successful; recovery passphrase is available.
      }
    }
  }

  Future<void> _chooseRestoreArchive() async {
    try {
      final archive = await widget.backupTransfer.pickArchive();
      if (archive == null || !mounted) return;
      setState(() {
        _selectedRestoreArchive = archive;
        _error = null;
        _stage = _GateStage.restore;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = 'Select a valid OwnKeep .cvault backup.';
        _stage = _GateStage.create;
      });
    }
  }

  Future<void> _restore(String passphrase) async {
    final archive = _selectedRestoreArchive;
    if (archive == null) return;
    await _open(
      () => widget.lifecycle.restoreBackup(
        archive: archive.file,
        recoveryPassphrase: passphrase,
      ),
      failureStage: _GateStage.restore,
    );
  }

  void _cancelRestore() {
    setState(() {
      _selectedRestoreArchive = null;
      _error = null;
      _stage = _GateStage.create;
    });
  }

  Future<void> _unlock(String passphrase) async {
    await _open(
      () => widget.lifecycle.unlock(recoveryPassphrase: passphrase),
      failureStage: _GateStage.unlock,
    );
  }

  Future<void> _unlockBiometric() async {
    await _open(
      widget.lifecycle.unlockWithBiometrics,
      failureStage: _GateStage.unlock,
    );
  }

  Future<String?> _enableBiometrics(String passphrase) async {
    try {
      await widget.lifecycle.enableBiometrics(recoveryPassphrase: passphrase);
      if (mounted) setState(() => _biometricEnabled = true);
      return null;
    } on VaultLifecycleFailure catch (failure) {
      return _messageFor(failure.code);
    }
  }

  Future<String?> _disableBiometrics() async {
    try {
      await widget.lifecycle.disableBiometrics();
      if (mounted) setState(() => _biometricEnabled = false);
      return null;
    } on VaultLifecycleFailure catch (failure) {
      return _messageFor(failure.code);
    }
  }

  Future<String> _createBackup(String passphrase) async {
    PendingVaultBackup? pending;
    try {
      final handle = _handle;
      if (handle == null) {
        return _presentBackupResult(
          'Unlock the vault before creating a backup.',
        );
      }
      pending = await handle.createBackup(recoveryPassphrase: passphrase);
      final saved = await widget.backupTransfer.exportArchive(pending.archive);
      if (!saved) {
        return _presentBackupResult(
          'Backup export cancelled. No cloud copy was created.',
        );
      }
      final current = handle.ingestionController.preferences;
      await handle.ingestionController.savePreferences(
        VaultPreferencesView(
          useGrid: current.useGrid,
          darkMode: current.darkMode,
          defaultReminderOffsets: current.defaultReminderOffsets,
          lastBackupAt: DateTime.now().toUtc(),
          lastBackupObjectCount: pending.objectCount,
        ),
      );
      return _presentBackupResult(
        'Verified encrypted backup exported '
        '(${_formatBytes(pending.archiveBytes)}, '
        '${pending.objectCount} encrypted objects). '
        'Check that your provider finishes syncing it.',
      );
    } on VaultLifecycleFailure catch (failure) {
      return _presentBackupResult(_messageFor(failure.code));
    } on BackupArchiveTransferFailure {
      return _presentBackupResult(
        'The encrypted backup could not be saved to that location.',
      );
    } on Object {
      return _presentBackupResult(
        'The encrypted backup could not be created safely.',
      );
    } finally {
      pending?.dispose();
    }
  }

  String _presentBackupResult(String message) {
    if (mounted && _stage != _GateStage.open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      });
    }
    return message;
  }

  Future<void> _open(
    Future<UnlockedVaultHandle> Function() operation, {
    required _GateStage failureStage,
  }) async {
    setState(() {
      _stage = _GateStage.opening;
      _error = null;
    });
    try {
      final handle = await operation();
      if (!mounted) {
        await handle.close();
        return;
      }
      if (_privacyCovered) {
        await handle.close();
        if (!mounted) return;
        setState(() => _stage = _GateStage.unlock);
        return;
      }
      setState(() {
        _handle = handle;
        _stage = _GateStage.open;
      });
    } on VaultLifecycleFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        if (failure.code == 'biometric_invalidated') {
          _biometricEnabled = false;
        }
        _stage = switch (failure.code) {
          'vault_metadata_invalid' => _GateStage.failed,
          'vault_already_exists' => _GateStage.unlock,
          _ => failureStage,
        };
        _error = _messageFor(failure.code);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final handle = _handle;
    if (handle != null) unawaited(handle.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      switch (_stage) {
        _GateStage.loading || _GateStage.opening => _VaultProgressScreen(
          label: _stage == _GateStage.opening
              ? 'Opening your encrypted vault…'
              : 'Checking this device…',
        ),
        _GateStage.create => _CreateVaultFlow(
          error: _error,
          onCreate: _create,
          onChooseBackup: _chooseRestoreArchive,
        ),
        _GateStage.restore => _RestoreVaultScreen(
          archiveName: _selectedRestoreArchive!.displayName,
          error: _error,
          onRestore: _restore,
          onCancel: _cancelRestore,
        ),
        _GateStage.unlock => _UnlockVaultScreen(
          error: _error,
          onUnlock: _unlock,
          onBiometricUnlock: _biometricEnabled ? _unlockBiometric : null,
        ),
        _GateStage.open => VaultHomeScreen(
          controller: _handle!.ingestionController,
          biometricEnabled: _biometricEnabled,
          onEnableBiometrics: _enableBiometrics,
          onDisableBiometrics: _disableBiometrics,
          onCreateBackup: _createBackup,
        ),
        _GateStage.failed => _VaultFailureScreen(message: _error!),
      },
      if (_privacyCovered)
        ColoredBox(
          color: const Color(0xFF101416),
          child: Center(
            child: Semantics(
              liveRegion: true,
              label: 'OwnKeep content hidden',
              child: const Icon(Icons.lock, color: Colors.white, size: 48),
            ),
          ),
        ),
    ],
  );

  static String _messageFor(String code) => switch (code) {
    'weak_recovery_credential' =>
      'Use at least 12 characters and avoid common passwords.',
    'incorrect_recovery_credential' =>
      'That recovery passphrase did not unlock this vault.',
    'vault_metadata_invalid' =>
      'Vault metadata is damaged. Restore from a verified backup.',
    'biometric_unavailable' =>
      'No enrolled biometric is available on this device.',
    'biometric_cancelled' => 'Biometric authentication was not completed.',
    'biometric_invalidated' =>
      'Biometric unlock changed or expired. Use your recovery passphrase.',
    'biometric_not_enabled' => 'Biometric unlock is not enabled.',
    'biometric_enable_failed' ||
    'biometric_disable_failed' ||
    'biometric_unlock_failed' =>
      'Biometric security could not be updated. Recovery access is unchanged.',
    'backup_creation_failed' =>
      'The encrypted backup could not be created safely.',
    'backup_restore_failed' =>
      'That backup is damaged, incomplete, or unsupported.',
    'restore_storage_insufficient' =>
      'This device does not have enough free space to restore the backup.',
    'vault_creation_failed' =>
      'Vault creation could not be completed. Please try again.',
    _ => 'The vault could not be opened safely. Please try again.',
  };
}

final class _CreateVaultFlow extends StatefulWidget {
  const _CreateVaultFlow({
    required this.onCreate,
    required this.onChooseBackup,
    this.error,
  });

  final Future<void> Function(String passphrase, bool enableBiometrics)
  onCreate;
  final Future<void> Function() onChooseBackup;
  final String? error;

  @override
  State<_CreateVaultFlow> createState() => _CreateVaultFlowState();
}

final class _CreateVaultFlowState extends State<_CreateVaultFlow> {
  var _showSetup = false;
  var _showVaultInfo = false;
  var _showAgreement = false;
  var _showRecoverySetup = false;
  String? _passphrase;
  var _enableBiometrics = false;

  @override
  Widget build(BuildContext context) {
    if (_showRecoverySetup && _passphrase != null) {
      return _RecoverySetupScreen(
        onContinue: () => widget.onCreate(_passphrase!, _enableBiometrics),
      );
    }
    if (widget.error != null || _showSetup) {
      return _SetupVaultCredentialScreen(
        onCreate: (pass, enableBiometrics) async {
          setState(() {
            _passphrase = pass;
            _enableBiometrics = enableBiometrics;
            _showRecoverySetup = true;
          });
        },
        onChooseBackup: widget.onChooseBackup,
        error: widget.error,
      );
    }
    if (_showVaultInfo) {
      return _CreateVaultInfoScreen(
        onContinue: () => setState(() {
          _showVaultInfo = false;
          _showAgreement = true;
        }),
      );
    }
    if (_showAgreement) {
      return UserAgreementScreen(
        onAccepted: () async {
          if (mounted) {
            setState(() {
              _showAgreement = false;
              _showSetup = true;
            });
          }
        },
      );
    }
    return _LanguageSelectionScreen(
      onLanguageSelected: (lang) => setState(() => _showVaultInfo = true),
    );
  }
}

final class _RecoverySetupScreen extends StatelessWidget {
  const _RecoverySetupScreen({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _VaultScaffold(
      icon: Icons.security,
      title: 'Protect Your Vault',
      description:
          'Recovery is critical. If you lose your recovery secret, OwnKeep cannot reset your encrypted vault. Your data will be permanently lost.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(Icons.key),
            title: Text(AppStrings.lblRecoveryKey.tr),
            subtitle: Text(AppStrings.txtSavedSecurely.tr),
            trailing: Icon(Icons.check_circle, color: Colors.green),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_upload),
            title: Text(AppStrings.lblCreateRecoveryBackup.tr),
            subtitle: Text(AppStrings.txtHighlyRecommended.tr),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Create the first verified encrypted backup from Settings after the vault opens.'
                      .tr,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onContinue,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(AppStrings.btnSavedRecoveryKey.tr),
            ),
          ),
        ],
      ),
    );
  }
}

final class _LanguageSelectionScreen extends StatefulWidget {
  const _LanguageSelectionScreen({required this.onLanguageSelected});
  final ValueChanged<String> onLanguageSelected;
  @override
  State<_LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

final class _LanguageSelectionScreenState
    extends State<_LanguageSelectionScreen> {
  String _selected = 'en';

  final _languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'hi', 'name': 'हिंदी (Hindi)'},
    {'code': 'te', 'name': 'తెలుగు (Telugu)'},
    {'code': 'ta', 'name': 'தமிழ் (Tamil)'},
    {'code': 'kn', 'name': 'ಕನ್ನಡ (Kannada)'},
    {'code': 'ml', 'name': 'മലയാളം (Malayalam)'},
    {'code': 'bn', 'name': 'বাংলা (Bengali)'},
    {'code': 'mr', 'name': 'मराठी (Marathi)'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          AppStrings.txtChooseLanguage.tr,
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                AppStrings.lblSelectLanguage.tr,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _languages.length,
                itemBuilder: (context, index) {
                  final lang = _languages[index];
                  final isSelected = _selected == lang['code'];
                  return ListTile(
                    title: Text(lang['name']!),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Color(0xFF0B4A99))
                        : null,
                    onTap: () => setState(() => _selected = lang['code']!),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: () => widget.onLanguageSelected(_selected),
                child: Text(AppStrings.btnContinue.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _CreateVaultInfoScreen extends StatelessWidget {
  const _CreateVaultInfoScreen({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000B2B),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, 0.1),
            radius: 1.2,
            colors: [Color(0xFF1E3A8A), Color(0xFF000B2B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shield & Title
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.appName.tr,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.lblKeepWhatMatters.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      AppStrings.lblOnlyYouAlways.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF60A5FA), // Light Blue
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.msgVaultSubtitle.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/images/locker_small.png',
                        width: 250,
                        height: 250,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Glassmorphic Grid
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: const Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _FeatureItem(
                                  icon: Icons.lock,
                                  title: '100% Private',
                                  subtitle: 'No tracking.',
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _FeatureItem(
                                  icon: Icons.wifi_off,
                                  title: 'Works Offline',
                                  subtitle:
                                      'Your vault works without Internet.',
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _FeatureItem(
                                  icon: Icons.verified_user,
                                  title: 'Encrypted Vault',
                                  subtitle:
                                      'Files are encrypted before storage.',
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _FeatureItem(
                                  icon: Icons.person,
                                  title: 'You\'re in Control',
                                  subtitle:
                                      'You control your vault and backups.',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Buttons
                    FilledButton(
                      onPressed: onContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        AppStrings.btnCreateNewVault.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('How OwnKeep protects your data'.tr),
                          content: Text(
                            'OwnKeep encrypts originals and metadata locally, works offline, and exports only encrypted backups or copies you explicitly choose.'
                                .tr,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('Done'.tr),
                            ),
                          ],
                        ),
                      ),
                      child: Text.rich(
                        TextSpan(
                          text: 'New here? ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          children: const [
                            TextSpan(
                              text: 'Learn how',
                              style: TextStyle(
                                color: Color(0xFF60A5FA),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: ' OwnKeep keeps your data safe '),
                            TextSpan(
                              text: '>',
                              style: TextStyle(color: Color(0xFF60A5FA)),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _SetupVaultCredentialScreen extends StatefulWidget {
  const _SetupVaultCredentialScreen({
    required this.onCreate,
    required this.onChooseBackup,
    this.error,
  });

  final Future<void> Function(String passphrase, bool enableBiometrics)
  onCreate;
  final Future<void> Function() onChooseBackup;
  final String? error;

  @override
  State<_SetupVaultCredentialScreen> createState() =>
      _SetupVaultCredentialScreenState();
}

final class _SetupVaultCredentialScreenState
    extends State<_SetupVaultCredentialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passphrase = TextEditingController();
  final _confirmation = TextEditingController();
  var _enableBiometrics = false;
  var _obscure = true;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {});
      return;
    }
    await widget.onCreate(_passphrase.text, _enableBiometrics);
  }

  @override
  Widget build(BuildContext context) => _VaultScaffold(
    icon: Icons.lock_outline,
    title: 'Create Your Private Vault',
    description:
        'Your files, photos and records will be stored inside your encrypted OwnKeep vault.',
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.error != null) ...[
            _ErrorBanner(message: widget.error!),
            const SizedBox(height: 18),
          ],
          TextFormField(
            controller: _passphrase,
            obscureText: _obscure,
            autofillHints: const <String>[AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Create passphrase'.tr,
              helperText: AppStrings.passphraseMinLength.tr,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show passphrase' : 'Hide passphrase',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off,
                ),
              ),
            ),
            validator: (value) {
              final assessment = RecoveryCredentialPolicy.assess(value ?? '');
              return assessment.accepted
                  ? null
                  : 'Choose a stronger passphrase of at least 12 characters.';
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmation,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            autofillHints: const <String>[AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Confirm passphrase'.tr,
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == _passphrase.text
                ? null
                : 'The passphrases do not match.',
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _enableBiometrics,
            onChanged: (value) =>
                setState(() => _enableBiometrics = value ?? false),
            title: Text(AppStrings.txtEnableBiometricUnlock.tr),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submit,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(AppStrings.btnCreateVaultConfirm.tr),
            ),
          ),
        ],
      ),
    ),
  );
}

final class _RestoreVaultScreen extends StatefulWidget {
  const _RestoreVaultScreen({
    required this.archiveName,
    required this.onRestore,
    required this.onCancel,
    this.error,
  });

  final String archiveName;
  final Future<void> Function(String passphrase) onRestore;
  final VoidCallback onCancel;
  final String? error;

  @override
  State<_RestoreVaultScreen> createState() => _RestoreVaultScreenState();
}

final class _RestoreVaultScreenState extends State<_RestoreVaultScreen> {
  final _passphrase = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _VaultScaffold(
    icon: Icons.restore,
    title: 'Restore encrypted backup',
    description:
        'OwnKeep will verify the complete archive before activating it.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          elevation: 0,
          child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(AppStrings.selectedBackup.tr),
            subtitle: Text(widget.archiveName),
          ),
        ),
        if (widget.error != null) ...<Widget>[
          const SizedBox(height: 12),
          _ErrorBanner(message: widget.error!),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _passphrase,
          obscureText: _obscure,
          autofocus: true,
          autofillHints: const <String>[AutofillHints.password],
          decoration: InputDecoration(
            labelText: AppStrings.backupPassphraseHint.tr,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Show passphrase' : 'Hide passphrase',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off,
              ),
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.verified_user_outlined),
          label: Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(AppStrings.btnVerifyAndRestore.tr),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: widget.onCancel,
          child: Text(AppStrings.btnCancel.tr),
        ),
      ],
    ),
  );

  Future<void> _submit() async {
    if (_passphrase.text.isEmpty) return;
    await widget.onRestore(_passphrase.text);
  }
}

final class _UnlockVaultScreen extends StatefulWidget {
  const _UnlockVaultScreen({
    required this.onUnlock,
    this.onBiometricUnlock,
    this.error,
  });

  final Future<void> Function(String passphrase) onUnlock;
  final VoidCallback? onBiometricUnlock;
  final String? error;

  @override
  State<_UnlockVaultScreen> createState() => _UnlockVaultScreenState();
}

final class _UnlockVaultScreenState extends State<_UnlockVaultScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000B2B),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, 0.1),
            radius: 1.2,
            colors: [Color(0xFF1E3A8A), Color(0xFF000B2B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ErrorBanner(message: widget.error!),
                      ),
                    // Shield & Title
                    Text(
                      AppStrings.txtWelcomeBack.tr,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.lblUnlockPrivateVault.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/images/locker_small.png',
                        width: 250,
                        height: 250,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Options Text
                    Text(
                      AppStrings.msgUnlockOptions.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Buttons
                    FilledButton(
                      onPressed: () {
                        if (widget.onBiometricUnlock != null) {
                          widget.onBiometricUnlock!();
                        } else {
                          _showPassphraseSheet(context);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        AppStrings.txtUnlockVault.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPassphraseSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1B3C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _PassphraseSheet(onUnlock: widget.onUnlock),
    );
  }
}

final class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF60A5FA), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _PassphraseSheet extends StatefulWidget {
  const _PassphraseSheet({required this.onUnlock});
  final Future<void> Function(String passphrase) onUnlock;

  @override
  State<_PassphraseSheet> createState() => _PassphraseSheetState();
}

final class _PassphraseSheetState extends State<_PassphraseSheet> {
  final _passphrase = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passphrase.text.isEmpty) return;
    Navigator.pop(context);
    await widget.onUnlock(_passphrase.text);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.txtUnlockVault.tr,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _passphrase,
            obscureText: _obscure,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Recovery Passphrase'.tr,
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF60A5FA)),
              ),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              AppStrings.btnUnlock.tr,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    ),
  );
}

final class _VaultScaffold extends StatelessWidget {
  const _VaultScaffold({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF0B4A99)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(icon, size: 64, color: Colors.white),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Theme(
                    data: Theme.of(context).copyWith(
                      inputDecorationTheme: InputDecorationTheme(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        helperStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                      textTheme: const TextTheme(
                        titleMedium: TextStyle(color: Colors.white),
                        bodyLarge: TextStyle(color: Colors.white),
                        bodyMedium: TextStyle(color: Colors.white),
                      ),
                      filledButtonTheme: FilledButtonThemeData(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0B4A99),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                      ),
                      outlinedButtonTheme: OutlinedButtonThemeData(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                    ),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final class _VaultProgressScreen extends StatelessWidget {
  const _VaultProgressScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => OwnKeepSplashScreen(statusLabel: label);
}

final class _VaultFailureScreen extends StatelessWidget {
  const _VaultFailureScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => _VaultScaffold(
    icon: Icons.error_outline,
    title: 'Vault unavailable',
    description: message,
    child: Text(
      AppStrings
          .txtCloseAndReopenTheAppIfThisContinuesPreserveTheAppDataUntilRecoveryOrRestoreToolsAreAvailable
          .tr,
    ),
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(1)} KiB';
  return '${(kib / 1024).toStringAsFixed(1)} MiB';
}
