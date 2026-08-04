import 'dart:io';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:vault_domain/vault_domain.dart';

/// Screen presenting persisted interface-language preferences.
final class LanguageSettingsScreen extends StatefulWidget {
  /// Creates the language settings screen.
  const LanguageSettingsScreen({required this.controller, super.key});

  /// Controller instance.
  final IngestionUiController controller;

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

final class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.controller.multilingualEngine;
    final pref = engine.preferences;
    final tr = engine.translate;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          tr('Language'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF), // Soft Blue
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.translate, size: 20, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 8),
                      Text(
                        AppStrings.txtMultilingualInvarianceGuaranteed.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    AppStrings
                        .txtChangingInterfaceLanguageDoesNotAlterStoredClaimValuesPredicatesEntityIDsEvidenceOrBackupBytes
                        .tr,
                    style: TextStyle(fontSize: 13, color: Color(0xFF1E3A8A)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 16),
            Text(
              AppStrings.interfaceLanguageTitle.tr,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
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
                child: Column(
                  children: [
                    for (
                      var i = 0;
                      i < SupportedLanguage.values.length;
                      i++
                    ) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          SupportedLanguage.values[i].displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        trailing: pref.uiLanguage == SupportedLanguage.values[i]
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF3B82F6),
                              )
                            : const Icon(
                                Icons.circle_outlined,
                                color: Color(0xFFCBD5E1),
                              ),
                        onTap: () {
                          widget.controller.setUiLanguage(
                            SupportedLanguage.values[i],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr('Regional OCR Text Packs'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (
                      var i = 0;
                      i < engine.availableOcrPacks.length;
                      i++
                    ) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ListTile(
                        enabled: _ocrSupported(
                          engine.availableOcrPacks[i].code,
                        ),
                        onTap: _ocrSupported(engine.availableOcrPacks[i].code)
                            ? () => widget.controller.setOcrLanguage(
                                engine.availableOcrPacks[i].code,
                              )
                            : null,
                        title: Text(engine.availableOcrPacks[i].displayName),
                        subtitle: Text(
                          !_ocrSupported(engine.availableOcrPacks[i].code)
                              ? tr('Not available on this device')
                              : engine.availableOcrPacks[i].code == 'en'
                              ? tr('Bundled on this device')
                              : tr('Used for newly imported documents'),
                        ),
                        trailing:
                            pref.ocrLanguage == engine.availableOcrPacks[i].code
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF3B82F6),
                              )
                            : const Icon(
                                Icons.circle_outlined,
                                color: Color(0xFFCBD5E1),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _ocrSupported(String code) {
    if (Platform.isIOS) return true;
    if (Platform.isAndroid) {
      return const <String>{'en', 'hi', 'mr'}.contains(code);
    }
    return true;
  }
}
