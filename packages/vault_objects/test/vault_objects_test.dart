import 'package:test/test.dart';
import 'package:vault_objects/vault_objects.dart';

void main() {
  test('declares the milestone six object-store API version', () {
    expect(VaultObjectsPackage.apiVersion, '0.7.0');
  });
}
