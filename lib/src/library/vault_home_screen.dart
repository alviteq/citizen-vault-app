import 'dart:async';

import 'package:citizen_vault_app/src/design/ownkeep_theme.dart';
import 'package:citizen_vault_app/src/ingestion/add_new_screen.dart';
import 'package:citizen_vault_app/src/ingestion/ingestion_screen.dart';
import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:citizen_vault_app/src/library/document_detail_screen.dart';
import 'package:citizen_vault_app/src/library/document_library_screen.dart';
import 'package:citizen_vault_app/src/life/life_dashboard_screen.dart';
import 'package:citizen_vault_app/src/life/life_navigator_screen.dart';
import 'package:citizen_vault_app/src/life/life_timeline_screen.dart';
import 'package:citizen_vault_app/src/reminders/flutter_local_notification_projection.dart';
import 'package:citizen_vault_app/src/reminders/reminders_screen.dart';
import 'package:citizen_vault_app/src/settings/vault_overview_screen.dart';
import 'package:flutter/material.dart';

/// Unlocked OwnKeep private-life shell.
final class VaultHomeScreen extends StatefulWidget {
  /// Creates the shell.
  const VaultHomeScreen({
    required this.controller,
    this.biometricEnabled = false,
    this.onEnableBiometrics,
    this.onDisableBiometrics,
    this.onCreateBackup,
    super.key,
  });

  /// Controller scoped to the unlocked encrypted vault.
  final IngestionUiController controller;

  /// Whether device-local biometric unlock is configured.
  final bool biometricEnabled;

  /// Enables biometrics after re-authenticating the recovery credential.
  final Future<String?> Function(String passphrase)? onEnableBiometrics;

  /// Removes the device envelope without affecting recovery.
  final Future<String?> Function()? onDisableBiometrics;

  /// Creates, verifies, and exports an encrypted portable backup.
  final Future<String> Function(String passphrase)? onCreateBackup;

  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

final class _VaultHomeScreenState extends State<VaultHomeScreen> {
  var _index = 0;
  StreamSubscription<String>? _notificationOpenSubscription;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _notificationOpenSubscription = FlutterLocalNotificationProjection
        .documentOpenRequests
        .listen(_openNotificationDocument);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    unawaited(_notificationOpenSubscription?.cancel());
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _openNotificationDocument(String documentId) async {
    final detail = await widget.controller.document(documentId);
    if (!mounted || detail == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DocumentDetailScreen(
          controller: widget.controller,
          documentId: documentId,
        ),
      ),
    );
  }

  void _openRecords() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DocumentLibraryScreen(controller: widget.controller),
      ),
    );
  }

  void _openInbox() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => IngestionScreen(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.controller.preferences.darkMode;
    final appTheme = OwnKeepTheme.forBrightness(
      dark ? Brightness.dark : Brightness.light,
    );
    final colorScheme = appTheme.colorScheme;

    return Theme(
      data: appTheme,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;

          final mainContent = IndexedStack(
            index: _index,
            children: <Widget>[
              LifeDashboardScreen(
                controller: widget.controller,
                onOpenRecords: _openRecords,
                onOpenInbox: _openInbox,
              ),
              LifeNavigatorScreen(controller: widget.controller),
              LifeTimelineScreen(controller: widget.controller),
              VaultOverviewScreen(
                controller: widget.controller,
                biometricEnabled: widget.biometricEnabled,
                onEnableBiometrics: widget.onEnableBiometrics,
                onDisableBiometrics: widget.onDisableBiometrics,
                onCreateBackup: widget.onCreateBackup,
              ),
            ],
          );

          if (isDesktop) {
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: Row(
                children: [
                  _DesktopSidebar(
                    controller: widget.controller,
                    currentIndex: _index,
                    onIndexChanged: (index) => setState(() => _index = index),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DesktopTopBar(controller: widget.controller),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                            ),
                            child: Container(
                              color: Theme.of(context).colorScheme.surface,
                              child: mainContent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            body: mainContent,
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 64,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _buildNavItem(
                          0,
                          Icons.home_outlined,
                          Icons.home,
                          'Home',
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          1,
                          Icons.search_outlined,
                          Icons.search,
                          'Search',
                        ),
                      ),
                      Expanded(child: _buildAddNavItem()),
                      Expanded(
                        child: _buildNavItem(
                          2,
                          Icons.timeline_outlined,
                          Icons.timeline,
                          'Timeline',
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          3,
                          Icons.more_horiz,
                          Icons.more_horiz,
                          'Vault',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = _index == index;
    final color = isSelected
        ? const Color(0xFF2563EB)
        : const Color(0xFF64748B);
    return InkWell(
      onTap: () => setState(() => _index = index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label.tr,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNavItem() {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddNewScreen(controller: widget.controller),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.controller,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  final IngestionUiController controller;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: const Color(0xFF0F172A), // Dark blue sidebar
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.shield, color: Color(0xFF10B981), size: 28),
                const SizedBox(width: 12),
                Text(
                  AppStrings.appName.tr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            isSelected: currentIndex == 0,
            onTap: () => onIndexChanged(0),
          ),
          _NavItem(
            icon: Icons.search_rounded,
            label: 'Search',
            isSelected: currentIndex == 1,
            onTap: () => onIndexChanged(1),
          ),
          _NavItem(
            icon: Icons.add_circle_rounded,
            label: 'Add New',
            isSelected: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddNewScreen(controller: controller),
              ),
            ),
          ),
          _NavItem(
            icon: Icons.timeline_rounded,
            label: 'Timeline',
            isSelected: currentIndex == 2,
            onTap: () => onIndexChanged(2),
          ),
          _NavItem(
            icon: Icons.more_horiz,
            label: 'Vault',
            isSelected: currentIndex == 3,
            onTap: () => onIndexChanged(3),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF334155),
                  radius: 16,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  AppStrings.txtUser.tr,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Color(0xFF10B981).withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : const Color(0xFF94A3B8),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  label.tr,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                if (isSelected) const Spacer(),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({required this.controller});

  final IngestionUiController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.txtGoodMorning.tr,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                AppStrings.msgWelcomeSecureLifeOS.tr,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 300,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
                SizedBox(width: 8),
                Text(
                  AppStrings.searchDocsHint.tr,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          IconButton(
            tooltip: 'Reminders',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => RemindersScreen(controller: controller),
              ),
            ),
            icon: const Icon(
              Icons.notifications_none,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => AddNewScreen(controller: controller),
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981), // Emerald Green
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(AppStrings.txtAddNew.tr),
          ),
        ],
      ),
    );
  }
}
