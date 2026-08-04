import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_platform/vault_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('citizen_vault/security.test');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('declares the milestone one API version', () {
    expect(VaultPlatformPackage.apiVersion, '0.2.0');
  });

  test('platform random validates native output length', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'secureRandom');
          return Uint8List.fromList(<int>[1, 2, 3, 4]);
        });

    final bytes = await const PlatformCryptographicRandom(
      channel: channel,
    ).secureBytes(4);
    expect(bytes, <int>[1, 2, 3, 4]);
  });

  test('device store maps a native invalidation failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'PLATFORM_KEY_INVALIDATED');
        });
    const store = PlatformDeviceEnvelopeStore(channel: channel);
    final envelope = DeviceEnvelope(
      keyAlias: 'vault.test',
      nonce: List<int>.filled(12, 0),
      ciphertext: List<int>.filled(32, 0),
      authenticationTag: List<int>.filled(16, 0),
      requiresAuthentication: true,
      invalidatedByBiometricEnrollment: true,
      createdAt: DateTime.utc(2026),
      hardwareBacked: false,
    );

    await expectLater(
      store.unwrap(envelope),
      throwsA(isA<PlatformKeyInvalidatedFailure>()),
    );
  });

  test('device store parses a native wrapped envelope', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'wrapDeviceKey');
          return <String, Object>{
            'nonce': Uint8List.fromList(List<int>.filled(12, 1)),
            'ciphertext': Uint8List.fromList(List<int>.filled(32, 2)),
            'authenticationTag': Uint8List.fromList(List<int>.filled(16, 3)),
            'createdAtEpochMilliseconds': 0,
            'hardwareBacked': true,
            'requiresAuthentication': false,
          };
        });
    final key = SecretBytes(List<int>.filled(32, 7));
    addTearDown(key.destroy);

    final envelope =
        await const PlatformDeviceEnvelopeStore(
          channel: channel,
        ).wrap(
          keyAlias: 'vault.test',
          masterKey: key,
          invalidatedByBiometricEnrollment: true,
          authenticationValidity: const Duration(minutes: 5),
        );
    expect(envelope.hardwareBacked, isTrue);
    expect(envelope.requiresAuthentication, isFalse);
    expect(envelope.ciphertext, List<int>.filled(32, 2));
  });

  test('device store parses a macOS base64 wrapped envelope', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return <String, Object>{
            'nonce': base64Encode(List<int>.filled(12, 1)),
            'ciphertext': base64Encode(List<int>.filled(32, 2)),
            'authenticationTag': base64Encode(List<int>.filled(16, 3)),
            'createdAtEpochMilliseconds': 0,
            'hardwareBacked': false,
            'requiresAuthentication': true,
          };
        });
    final key = SecretBytes(List<int>.filled(32, 7));
    addTearDown(key.destroy);

    final envelope =
        await const PlatformDeviceEnvelopeStore(channel: channel).wrap(
          keyAlias: 'vault.test',
          masterKey: key,
          invalidatedByBiometricEnrollment: true,
          authenticationValidity: const Duration(minutes: 5),
        );
    expect(envelope.nonce, List<int>.filled(12, 1));
    expect(envelope.ciphertext, List<int>.filled(32, 2));
    expect(envelope.authenticationTag, List<int>.filled(16, 3));
  });
}
