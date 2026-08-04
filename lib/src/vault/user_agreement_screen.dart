import 'package:citizen_vault_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Versioned clickwrap agreement shown before a user can create a new vault.
abstract final class OwnKeepUserAgreement {
  /// Increment whenever the legal text materially changes.
  static const version = '2026-07-29.v1';

  /// Human-readable effective date.
  static const effectiveDate = '29 July 2026';

  static const receiptVersionKey = 'ownkeep_user_agreement_version';
  static const receiptAcceptedAtKey = 'ownkeep_user_agreement_accepted_at';

  /// Records a minimal local receipt without storing identity or vault data.
  static Future<void> recordAcceptance() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(receiptVersionKey, version);
    await preferences.setString(
      receiptAcceptedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }
}

/// Mandatory agreement and data-responsibility acknowledgement.
class UserAgreementScreen extends StatefulWidget {
  const UserAgreementScreen({required this.onAccepted, super.key});

  /// Runs after the current agreement receipt is stored locally.
  final Future<void> Function() onAccepted;

  @override
  State<UserAgreementScreen> createState() => _UserAgreementScreenState();
}

class _UserAgreementScreenState extends State<UserAgreementScreen> {
  var _acceptedAgreement = false;
  var _acceptedRecoveryRisk = false;
  var _busy = false;

  bool get _canContinue =>
      _acceptedAgreement && _acceptedRecoveryRisk && !_busy;

  Future<void> _continue() async {
    if (!_canContinue) return;
    setState(() => _busy = true);
    try {
      await OwnKeepUserAgreement.recordAcceptance();
      await widget.onAccepted();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.gavel_outlined,
                        size: 44,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'User Agreement & Data Responsibility'.tr,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Effective ${OwnKeepUserAgreement.effectiveDate} • '
                                'Version ${OwnKeepUserAgreement.version}'
                            .tr,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Scrollbar(
                            child: ListView(
                              padding: const EdgeInsets.all(18),
                              children: const [
                                _AgreementSection(
                                  title: '1. Local-first software',
                                  body:
                                      'OwnKeep is a tool for organizing and '
                                      'encrypting information on your device. '
                                      'OwnKeep does not create an online '
                                      'account or automatically keep a server '
                                      'copy of your vault. A file leaves the '
                                      'vault only when you use an export, '
                                      'share, backup, or operating-system '
                                      'provider action.',
                                ),
                                _AgreementSection(
                                  title: '2. Your responsibility',
                                  body:
                                      'You are responsible for the documents '
                                      'you store, your right to store them, '
                                      'the security of your device, your '
                                      'recovery passphrase, and maintaining '
                                      'verified encrypted backups. Do not '
                                      'store unlawful material or information '
                                      'you are not authorized to possess.',
                                ),
                                _AgreementSection(
                                  title: '3. No password recovery',
                                  body:
                                      'OwnKeep cannot recover or reset a lost '
                                      'recovery passphrase. Losing the '
                                      'passphrase, vault files, device, or all '
                                      'valid backups can permanently make the '
                                      'data inaccessible.',
                                ),
                                _AgreementSection(
                                  title: '4. OCR and suggestions',
                                  body:
                                      'OCR, extracted fields, categories, '
                                      'reminders, and other suggestions can be '
                                      'incomplete or incorrect. Verify '
                                      'important information against the '
                                      'original document. OwnKeep does not '
                                      'provide legal, medical, financial, tax, '
                                      'or professional advice.',
                                ),
                                _AgreementSection(
                                  title: '5. Availability and risk',
                                  body:
                                      'Software, devices, storage media, '
                                      'operating systems, and third-party '
                                      'providers can fail. To the maximum '
                                      'extent permitted by applicable law, '
                                      'OwnKeep is provided without a guarantee '
                                      'of uninterrupted operation or freedom '
                                      'from every defect, loss, malware event, '
                                      'or hardware failure.',
                                ),
                                _AgreementSection(
                                  title: '6. Limitation and legal rights',
                                  body:
                                      'To the maximum extent permitted by '
                                      'applicable law, the OwnKeep provider '
                                      'will not be liable for indirect, '
                                      'incidental, special, or consequential '
                                      'loss arising from use of the software '
                                      'or loss of locally controlled data. '
                                      'Nothing in this agreement excludes '
                                      'liability or consumer, privacy, or '
                                      'statutory rights that cannot lawfully '
                                      'be excluded or limited.',
                                ),
                                _AgreementSection(
                                  title: '7. Your choice',
                                  body:
                                      'Do not create a vault if you do not '
                                      'agree. You may stop using OwnKeep and '
                                      'delete its local data, subject to your '
                                      'device and backup-provider controls.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _acceptedAgreement,
                        onChanged: _busy
                            ? null
                            : (value) => setState(
                                () => _acceptedAgreement = value ?? false,
                              ),
                        title: Text(
                          'I have read and agree to the User Agreement.'.tr,
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _acceptedRecoveryRisk,
                        onChanged: _busy
                            ? null
                            : (value) => setState(
                                () => _acceptedRecoveryRisk = value ?? false,
                              ),
                        title: Text(
                          'I understand that I control my passphrase and '
                                  'backups, and lost access may be permanent.'
                              .tr,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _canContinue ? _continue : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text('Agree and Continue'.tr),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgreementSection extends StatelessWidget {
  const _AgreementSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.tr,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(body.tr),
      ],
    ),
  );
}
