import 'package:test/test.dart';
import 'package:vault_database/vault_database.dart';

void main() {
  test('declares the milestone eight API version', () {
    expect(VaultDatabasePackage.apiVersion, '1.0.0');
  });
}
