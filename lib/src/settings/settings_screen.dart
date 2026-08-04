import 'dart:async';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:citizen_vault_app/src/library/document_library_screen.dart';
import 'package:citizen_vault_app/src/passwords/password_manager_screen.dart';
import 'package:citizen_vault_app/src/reminders/reminders_screen.dart';
import 'package:citizen_vault_app/src/settings/language_settings_screen.dart';
import 'package:citizen_vault_app/src/settings/tag_management_screen.dart';
import 'package:citizen_vault_app/src/settings/vault_storage_screen.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Encrypted local display and reminder-default settings.
final class SettingsScreen extends StatelessWidget {
  /// Creates the settings screen.
  const SettingsScreen({
    required this.controller,
    this.biometricEnabled = false,
    this.onEnableBiometrics,
    this.onDisableBiometrics,
    this.onCreateBackup,
    super.key,
  });

  /// Unlocked controller.
  final IngestionUiController controller;

  /// Whether the local device envelope is configured.
  final bool biometricEnabled;

  /// Enables biometric unlock using a confirmed recovery credential.
  final Future<String?> Function(String passphrase)? onEnableBiometrics;

  /// Disables biometric unlock.
  final Future<String?> Function()? onDisableBiometrics;

  /// Creates and exports a verified `.cvault` archive.
  final Future<String> Function(String passphrase)? onCreateBackup;

  Future<void> _save({bool? useGrid, bool? darkMode, List<int>? offsets}) =>
      controller.savePreferences(
        VaultPreferencesView(
          useGrid: useGrid ?? controller.preferences.useGrid,
          darkMode: darkMode ?? controller.preferences.darkMode,
          defaultReminderOffsets:
              offsets ?? controller.preferences.defaultReminderOffsets,
          lastBackupAt: controller.preferences.lastBackupAt,
          lastBackupObjectCount: controller.preferences.lastBackupObjectCount,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final preferences = controller.preferences;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(AppStrings.settingsTitle.tr),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              _SectionHeader('Security'),
              _SettingsSection(
                children: [
                  if (onEnableBiometrics != null &&
                      onDisableBiometrics != null) ...[
                    SwitchListTile(
                      secondary: _SettingsIcon(Icons.fingerprint),
                      title: Text(
                        AppStrings.lblBiometricUnlockTitle.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        biometricEnabled
                            ? 'Recovery passphrase remains available as fallback.'
                            : 'Protect a device-only key with enrolled biometrics.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: biometricEnabled,
                      onChanged: (enabled) {
                        unawaited(_changeBiometrics(context, enabled));
                      },
                      activeThumbColor: const Color(0xFF3B82F6),
                    ),
                  ],
                  _SettingsNavTile(
                    icon: Icons.password_outlined,
                    title: 'Password Manager',
                    subtitle:
                        'Encrypted passwords, usernames, and private notes',
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PasswordManagerScreen(controller: controller),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              _SectionHeader('Backup & Recovery'),
              _SettingsSection(
                children: [
                  if (onCreateBackup != null) ...[
                    _SettingsNavTile(
                      icon: Icons.cloud_upload_outlined,
                      title: 'Encrypted Backup',
                      subtitle:
                          'Your backup is encrypted before it leaves OwnKeep',
                      onTap: () => unawaited(_createBackup(context)),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ],
                  _SettingsNavTile(
                    icon: Icons.vpn_key_outlined,
                    title: 'Recovery Key',
                    subtitle: 'View or export your recovery secret',
                    onTap: () => _showInfo(
                      context,
                      'Recovery Key',
                      'For safety, OwnKeep never displays the existing recovery passphrase. Create an encrypted backup and keep its passphrase in a separate secure location.',
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _SettingsNavTile(
                    icon: Icons.label_outline,
                    title: 'Tags',
                    subtitle: 'Rename, merge or remove document tags',
                    onTap: () => unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              TagManagementScreen(controller: controller),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _SettingsNavTile(
                    icon: Icons.restore_outlined,
                    title: 'Restore Vault',
                    subtitle: 'Import a previously exported backup',
                    onTap: () => _showInfo(
                      context,
                      'Restore Vault',
                      'Restore is available from the locked welcome screen so an archive cannot overwrite an active unlocked vault.',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              _SectionHeader('Storage'),
              _SettingsSection(
                children: [
                  _SettingsNavTile(
                    icon: Icons.storage_outlined,
                    title: 'Vault Storage',
                    subtitle:
                        '${controller.documents.length} encrypted records',
                    onTap: () => unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              VaultStorageScreen(controller: controller),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _SettingsNavTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Archived Records',
                    subtitle: 'Manage hidden or inactive files',
                    onTap: () => unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DocumentLibraryScreen(
                            controller: controller,
                            initialFilter: const DocumentLibraryFilter(
                              archivedOnly: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _SettingsNavTile(
                    icon: Icons.delete_outline,
                    title: 'Recently Deleted',
                    subtitle: 'Restore records kept in encrypted trash',
                    onTap: () => unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DocumentLibraryScreen(
                            controller: controller,
                            initialFilter: const DocumentLibraryFilter(
                              deletedOnly: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              _SectionHeader('Privacy'),
              _SettingsSection(
                children: [
                  _SettingsNavTile(
                    icon: Icons.wifi_off_outlined,
                    title: 'Offline Mode',
                    subtitle: 'Restrict OwnKeep from network access entirely',
                    onTap: () => _showInfo(
                      context,
                      'Offline by design',
                      'Core vault, OCR, search, reminders, and intelligence run locally. Only destinations explicitly chosen for encrypted backup can receive archive bytes.',
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _SettingsNavTile(
                    icon: Icons.security_outlined,
                    title: 'Privacy Information',
                    subtitle: 'Learn how your data stays on your device',
                    onTap: () => _showInfo(
                      context,
                      'Privacy Information',
                      'Originals and metadata remain encrypted in the local vault. Decrypted copies exist only in short-lived authenticated leases or destinations you explicitly select.',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              _SectionHeader('Preferences'),
              _SettingsSection(
                children: [
                  SwitchListTile(
                    secondary: _SettingsIcon(Icons.dark_mode_outlined),
                    title: Text(
                      AppStrings.lblDarkModeTitle.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    value: preferences.darkMode,
                    onChanged: (value) => _save(darkMode: value),
                    activeThumbColor: const Color(0xFF3B82F6),
                  ),
                  Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  _SettingsNavTile(
                    icon: Icons.translate_outlined,
                    title: 'Language',
                    subtitle: 'Configure UI locale',
                    onTap: () => unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              LanguageSettingsScreen(controller: controller),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _SettingsNavTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Reminders',
                    subtitle: 'Configure default offset days',
                    onTap: () => unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              RemindersScreen(controller: controller),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  SwitchListTile(
                    secondary: _SettingsIcon(Icons.grid_view_outlined),
                    title: Text(
                      AppStrings.txtDocumentViewGrid.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    value: preferences.useGrid,
                    onChanged: (value) => _save(useGrid: value),
                    activeThumbColor: const Color(0xFF3B82F6),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              _SectionHeader('About'),
              _SettingsSection(
                children: [
                  _SettingsNavTile(
                    icon: Icons.info_outline,
                    title: 'OwnKeep version',
                    subtitle: '5.0.0 (Build 28)',
                    onTap: () => _showInfo(
                      context,
                      'OwnKeep',
                      'Version 5.0.0 • Build 28',
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _SettingsNavTile(
                    icon: Icons.security_update_good_outlined,
                    title: 'Security architecture',
                    subtitle: 'Learn about XChaCha20-Poly1305 encryption',
                    onTap: () => _showInfo(
                      context,
                      'Security architecture',
                      'OwnKeep uses authenticated encryption, device-protected key envelopes, SQLCipher metadata storage, immutable originals, and verified portable backups.',
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _SettingsNavTile(
                    icon: Icons.description_outlined,
                    title: 'Licences',
                    subtitle: 'Open source acknowledgements',
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'OwnKeep',
                      applicationVersion: '5.0.0+28',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showInfo(BuildContext context, String title, String message) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title.tr),
          content: Text(message.tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Done'.tr),
            ),
          ],
        ),
      );

  Future<void> _createBackup(BuildContext context) async {
    final passphrase = await _requestRecoveryPassphrase(context);
    if (passphrase == null || !context.mounted) return;
    final message = await onCreateBackup!(passphrase);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeBiometrics(BuildContext context, bool enabled) async {
    String? error;
    if (enabled) {
      final passphrase = await _requestRecoveryPassphrase(context);
      if (passphrase == null || !context.mounted) return;
      error = await onEnableBiometrics!(passphrase);
    } else {
      error = await onDisableBiometrics!();
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              (enabled
                  ? 'Biometric unlock enabled on this device.'
                  : 'Biometric unlock disabled.'),
        ),
      ),
    );
  }

  static Future<String?> _requestRecoveryPassphrase(
    BuildContext context,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const _RecoveryPassphraseDialog(),
    );
    return result?.trim().isEmpty == true ? null : result;
  }
}

final class _RecoveryPassphraseDialog extends StatefulWidget {
  const _RecoveryPassphraseDialog();

  @override
  State<_RecoveryPassphraseDialog> createState() =>
      _RecoveryPassphraseDialogState();
}

final class _RecoveryPassphraseDialogState
    extends State<_RecoveryPassphraseDialog> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(AppStrings.confirmPassphraseHint.tr),
    content: TextField(
      controller: _input,
      obscureText: true,
      autofocus: true,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => Navigator.pop(context, _input.text),
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        labelText: AppStrings.passphraseHint.tr,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(AppStrings.btnCancel.tr),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _input.text),
        child: Text(AppStrings.btnConfirm.tr),
      ),
    ],
  );
}

final class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    ),
  );
}

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text.tr,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

final class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 20),
  );
}

final class _SettingsNavTile extends StatelessWidget {
  const _SettingsNavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: _SettingsIcon(icon),
    title: Text(
      title.tr,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
    subtitle: Text(
      subtitle.tr,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
    trailing: Icon(
      Icons.chevron_right,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    onTap: onTap,
  );
}
