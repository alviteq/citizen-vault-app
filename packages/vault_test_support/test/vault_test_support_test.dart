import 'package:test/test.dart';
import 'package:vault_test_support/vault_test_support.dart';

void main() {
  test('declares the cross-platform fixture API version', () {
    expect(VaultTestSupportPackage.apiVersion, '0.6.0');
  });

  test('deterministic random consumes bytes without cycling', () async {
    final random = DeterministicCryptographicRandom(<int>[1, 2, 3, 4]);
    expect(await random.secureBytes(2), <int>[1, 2]);
    expect(await random.secureBytes(2), <int>[3, 4]);
    await expectLater(random.secureBytes(1), throwsStateError);
  });
}
