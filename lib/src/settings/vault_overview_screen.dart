import 'package:citizen_vault_app/src/design/ownkeep_theme.dart';
import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/reminders/reminders_screen.dart';
import 'package:citizen_vault_app/src/settings/settings_screen.dart';
import 'package:citizen_vault_app/src/transfer/device_transfer_screen.dart';
import 'package:flutter/material.dart';

/// Compact Vault landing page matching the primary OwnKeep navigation design.
final class VaultOverviewScreen extends StatelessWidget {
  const VaultOverviewScreen({
    required this.controller,
    required this.biometricEnabled,
    this.onEnableBiometrics,
    this.onDisableBiometrics,
    this.onCreateBackup,
    super.key,
  });

  final IngestionUiController controller;
  final bool biometricEnabled;
  final Future<String?> Function(String passphrase)? onEnableBiometrics;
  final Future<String?> Function()? onDisableBiometrics;
  final Future<String> Function(String passphrase)? onCreateBackup;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            const _SectionTitle('Security'),
            _Section(
              children: [
                _Tile(
                  icon: Icons.lock_outline,
                  title: 'Vault Lock',
                  subtitle: 'Passphrase & biometrics',
                  onTap: () => _openFullSettings(context),
                ),
                _Tile(
                  icon: Icons.cloud_sync_outlined,
                  title: 'Backup & Recovery',
                  subtitle: 'Encrypted .cvault backup',
                  onTap: () => _openFullSettings(context),
                ),
                _Tile(
                  icon: Icons.device_hub_outlined,
                  title: 'Device Transfer',
                  subtitle: 'Pair devices securely',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          DeviceTransferScreen(controller: controller),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Preferences'),
            _Section(
              children: [
                _Tile(
                  icon: Icons.brightness_6_outlined,
                  title: 'Appearance',
                  subtitle: controller.preferences.darkMode
                      ? 'Dark Mode'
                      : 'Light Mode',
                  onTap: () => _openFullSettings(context),
                ),
                _Tile(
                  icon: Icons.notifications_none,
                  title: 'Reminders',
                  subtitle: 'Default reminders & alerts',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => RemindersScreen(controller: controller),
                    ),
                  ),
                ),
                _Tile(
                  icon: Icons.settings_outlined,
                  title: 'Advanced',
                  subtitle: 'Automation, rules & more',
                  onTap: () => _openFullSettings(context),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  void _openFullSettings(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Theme(
            data: OwnKeepTheme.forBrightness(
              controller.preferences.darkMode
                  ? Brightness.dark
                  : Brightness.light,
            ),
            child: SettingsScreen(
              controller: controller,
              biometricEnabled: biometricEnabled,
              onEnableBiometrics: onEnableBiometrics,
              onDisableBiometrics: onDisableBiometrics,
              onCreateBackup: onCreateBackup,
            ),
          ),
        ),
      ),
    );
  }
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

final class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index < children.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );
}

final class _Tile extends StatelessWidget {
  const _Tile({
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
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right, size: 18),
    onTap: onTap,
  );
}
