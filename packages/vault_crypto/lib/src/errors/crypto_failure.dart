/// Base class for expected cryptographic failures.
sealed class VaultCryptoFailure implements Exception {
  /// Creates a safe failure with an optional internal cause.
  const VaultCryptoFailure(this.code, {this.cause});

  /// Stable machine-readable failure code.
  final String code;

  /// Internal cause. Callers must not expose it directly to users or logs.
  final Object? cause;

  @override
  String toString() => 'VaultCryptoFailure($code)';
}

/// The requested random bytes could not be obtained securely.
final class EntropyUnavailableFailure extends VaultCryptoFailure {
  /// Creates the failure.
  const EntropyUnavailableFailure({super.cause}) : super('entropy_unavailable');
}

/// A new recovery credential does not meet the local length/common policy.
final class WeakRecoveryCredentialFailure extends VaultCryptoFailure {
  /// Creates the failure with a safe [reason].
  const WeakRecoveryCredentialFailure(this.reason)
    : super('weak_recovery_credential');

  /// Stable reason from the credential policy.
  final String reason;
}

/// Imported parameters exceed the reviewed policy.
final class UnsafeKdfParametersFailure extends VaultCryptoFailure {
  /// Creates the failure for [parameter].
  const UnsafeKdfParametersFailure(this.parameter)
    : super('unsafe_kdf_parameters');

  /// Name of the rejected parameter. The untrusted value is not retained.
  final String parameter;
}

/// The recovery credential did not authenticate the envelope.
final class RecoveryEnvelopeAuthenticationFailure extends VaultCryptoFailure {
  /// Creates the failure.
  const RecoveryEnvelopeAuthenticationFailure({super.cause})
    : super('recovery_envelope_authentication_failed');
}

/// The envelope is malformed, unsupported, or non-canonical.
final class UnsupportedRecoveryEnvelopeFailure extends VaultCryptoFailure {
  /// Creates the failure with a stable [reason].
  const UnsupportedRecoveryEnvelopeFailure(this.reason, {super.cause})
    : super('unsupported_recovery_envelope');

  /// Safe reason code.
  final String reason;
}

/// A native device key no longer exists or was invalidated.
final class PlatformKeyInvalidatedFailure extends VaultCryptoFailure {
  /// Creates the failure.
  const PlatformKeyInvalidatedFailure({super.cause})
    : super('platform_key_invalidated');
}

/// Local authentication is required before using a device key.
final class DeviceAuthenticationRequiredFailure extends VaultCryptoFailure {
  /// Creates the failure.
  const DeviceAuthenticationRequiredFailure({super.cause})
    : super('device_authentication_required');
}

/// A device envelope failed authentication.
final class DeviceEnvelopeAuthenticationFailure extends VaultCryptoFailure {
  /// Creates the failure.
  const DeviceEnvelopeAuthenticationFailure({super.cause})
    : super('device_envelope_authentication_failed');
}

/// A platform security capability is unavailable.
final class PlatformSecurityUnavailableFailure extends VaultCryptoFailure {
  /// Creates the failure.
  const PlatformSecurityUnavailableFailure({super.cause})
    : super('platform_security_unavailable');
}
