import 'package:test/test.dart';
import 'package:vault_notifications/vault_notifications.dart';

void main() {
  test('declares the milestone eight API version', () {
    expect(VaultNotificationsPackage.apiVersion, '0.9.0');
  });
}
