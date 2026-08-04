import 'package:test/test.dart';
import 'package:vault_backup/vault_backup.dart';

void main() {
  test('declares the milestone four API version', () {
    expect(VaultBackupPackage.apiVersion, '0.5.0');
  });
}
