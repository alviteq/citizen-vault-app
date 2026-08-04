import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Narrow, injectable on-device biometric prompt boundary.
abstract interface class BiometricAuthenticator {
  /// Whether at least one biometric is enrolled and available.
  Future<bool> isAvailable();

  /// Requests biometric-only authentication for a vault operation.
  Future<bool> authenticate();
}

/// Flutter-team local authentication adapter.
final class PlatformBiometricAuthenticator implements BiometricAuthenticator {
  /// Creates the production adapter.
  PlatformBiometricAuthenticator({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;
  static const MethodChannel _macOsChannel = MethodChannel(
    'citizen_vault/biometrics',
  );

  @override
  Future<bool> isAvailable() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        return await _macOsChannel.invokeMethod<bool>('isAvailable') ?? false;
      }
      final available = await _authentication.getAvailableBiometrics();
      return available.isNotEmpty ||
          await _authentication.canCheckBiometrics;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      try {
        return await _macOsChannel.invokeMethod<bool>(
              'authenticate',
              <String, Object>{
                'reason': 'Use Touch ID to unlock OwnKeep',
              },
            ) ??
            false;
      } on PlatformException {
        return false;
      }
    }
    return _authentication.authenticate(
      localizedReason: 'Use biometrics to unlock OwnKeep',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}
