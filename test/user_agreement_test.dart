import 'package:citizen_vault_app/src/vault/user_agreement_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('requires explicit agreement before vault setup can continue', (
    tester,
  ) async {
    var accepted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: UserAgreementScreen(onAccepted: () async => accepted = true),
      ),
    );

    final continueButton = find.widgetWithText(
      FilledButton,
      'Agree and Continue',
    );
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile).at(0));
    await tester.pump();
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile).at(1));
    await tester.pump();
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);

    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(accepted, isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(OwnKeepUserAgreement.receiptVersionKey),
      OwnKeepUserAgreement.version,
    );
    expect(
      DateTime.tryParse(
        preferences.getString(OwnKeepUserAgreement.receiptAcceptedAtKey) ?? '',
      ),
      isNotNull,
    );
  });
}
