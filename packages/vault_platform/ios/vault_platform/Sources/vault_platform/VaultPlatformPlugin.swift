import CryptoKit
import Flutter
import Security

public final class VaultPlatformPlugin: NSObject, FlutterPlugin {
  private static let channelName = "citizen_vault/security"
  private static let service = "app.citizenvault.device-envelope"
  private static let aad = Data("citizen-vault/device-envelope/v1".utf8)
  private static let aliasPattern = try! NSRegularExpression(
    pattern: "^[A-Za-z0-9._-]{1,128}$"
  )

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(VaultPlatformPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "secureRandom":
        try secureRandom(call, result: result)
      case "wrapDeviceKey":
        try wrapDeviceKey(call, result: result)
      case "unwrapDeviceKey":
        try unwrapDeviceKey(call, result: result)
      case "deleteDeviceKey":
        try deleteDeviceKey(call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch let error as NativeSecurityError {
      result(FlutterError(code: error.code, message: error.message, details: nil))
    } catch {
      result(
        FlutterError(
          code: "PLATFORM_SECURITY_UNAVAILABLE",
          message: "Platform security operation failed",
          details: nil
        )
      )
    }
  }

  private func secureRandom(_ call: FlutterMethodCall, result: FlutterResult) throws {
    let arguments = try dictionary(call.arguments)
    guard let length = arguments["length"] as? Int, (1...(1024 * 1024)).contains(length)
    else { throw NativeSecurityError.invalidArguments }
    var bytes = Data(count: length)
    let status = bytes.withUnsafeMutableBytes { buffer in
      SecRandomCopyBytes(kSecRandomDefault, length, buffer.baseAddress!)
    }
    guard status == errSecSuccess else { throw NativeSecurityError.entropyUnavailable }
    result(FlutterStandardTypedData(bytes: bytes))
  }

  private func wrapDeviceKey(_ call: FlutterMethodCall, result: FlutterResult) throws {
    let arguments = try dictionary(call.arguments)
    let alias = try validatedAlias(arguments["keyAlias"])
    var masterKey = try data(arguments["masterKey"])
    guard masterKey.count == 32 else { throw NativeSecurityError.invalidArguments }
    let masterKeyLength = masterKey.count
    defer { masterKey.resetBytes(in: 0..<masterKeyLength) }
    let invalidated = arguments["invalidatedByBiometricEnrollment"] as? Bool ?? true
    guard try !keyExists(alias: alias) else {
      throw NativeSecurityError.aliasExists
    }

    var keyData = Data(count: 32)
    let keyLength = keyData.count
    let randomStatus = keyData.withUnsafeMutableBytes { buffer in
      SecRandomCopyBytes(kSecRandomDefault, keyLength, buffer.baseAddress!)
    }
    guard randomStatus == errSecSuccess else { throw NativeSecurityError.entropyUnavailable }
    defer { keyData.resetBytes(in: 0..<keyData.count) }

    var accessError: Unmanaged<CFError>?
    let flags: SecAccessControlCreateFlags = invalidated ? .biometryCurrentSet : .userPresence
    guard let access = SecAccessControlCreateWithFlags(
      nil,
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      flags,
      &accessError
    ) else { throw NativeSecurityError.platformUnavailable }

    let addQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: alias,
      kSecAttrAccessControl as String: access,
      kSecValueData as String: keyData,
    ]
    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
    guard addStatus == errSecSuccess else { throw mapStatus(addStatus) }

    do {
      let sealed = try AES.GCM.seal(
        masterKey,
        using: SymmetricKey(data: keyData),
        authenticating: Self.aad
      )
      result([
        "nonce": FlutterStandardTypedData(bytes: Data(sealed.nonce)),
        "ciphertext": FlutterStandardTypedData(bytes: sealed.ciphertext),
        "authenticationTag": FlutterStandardTypedData(bytes: sealed.tag),
        "createdAtEpochMilliseconds": Int64(Date().timeIntervalSince1970 * 1000),
        // Secure Enclave does not directly store AES symmetric key bytes.
        "hardwareBacked": false,
      ])
    } catch {
      try? delete(alias: alias)
      throw error
    }
  }

  private func unwrapDeviceKey(_ call: FlutterMethodCall, result: FlutterResult) throws {
    let arguments = try dictionary(call.arguments)
    let alias = try validatedAlias(arguments["keyAlias"])
    let nonce = try data(arguments["nonce"])
    let ciphertext = try data(arguments["ciphertext"])
    let tag = try data(arguments["authenticationTag"])
    guard nonce.count == 12, ciphertext.count == 32, tag.count == 16
    else { throw NativeSecurityError.invalidArguments }
    guard var keyData = try readKey(
      alias: alias,
      prompt: "Unlock OwnKeep",
      returnNotFound: false
    ) else { throw NativeSecurityError.keyNotFound }
    defer { keyData.resetBytes(in: 0..<keyData.count) }

    do {
      let box = try AES.GCM.SealedBox(
        nonce: AES.GCM.Nonce(data: nonce),
        ciphertext: ciphertext,
        tag: tag
      )
      let plaintext = try AES.GCM.open(
        box,
        using: SymmetricKey(data: keyData),
        authenticating: Self.aad
      )
      result(FlutterStandardTypedData(bytes: plaintext))
    } catch {
      throw NativeSecurityError.authenticationFailed
    }
  }

  private func deleteDeviceKey(_ call: FlutterMethodCall, result: FlutterResult) throws {
    let arguments = try dictionary(call.arguments)
    try delete(alias: validatedAlias(arguments["keyAlias"]))
    result(nil)
  }

  private func delete(alias: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: alias,
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound
    else { throw mapStatus(status) }
  }

  private func readKey(
    alias: String,
    prompt: String?,
    returnNotFound: Bool
  ) throws -> Data? {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: alias,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    if let prompt { query[kSecUseOperationPrompt as String] = prompt }
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound && returnNotFound { return nil }
    guard status == errSecSuccess, let value = item as? Data else {
      throw mapStatus(status)
    }
    return value
  }

  private func keyExists(alias: String) throws -> Bool {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: alias,
      kSecReturnAttributes as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
    ]
    let status = SecItemCopyMatching(query as CFDictionary, nil)
    if status == errSecSuccess { return true }
    if status == errSecItemNotFound { return false }
    throw mapStatus(status)
  }

  private func dictionary(_ value: Any?) throws -> [String: Any] {
    guard let result = value as? [String: Any] else {
      throw NativeSecurityError.invalidArguments
    }
    return result
  }

  private func data(_ value: Any?) throws -> Data {
    guard let typed = value as? FlutterStandardTypedData else {
      throw NativeSecurityError.invalidArguments
    }
    return typed.data
  }

  private func validatedAlias(_ value: Any?) throws -> String {
    guard let alias = value as? String else { throw NativeSecurityError.invalidArguments }
    let range = NSRange(location: 0, length: alias.utf16.count)
    guard Self.aliasPattern.firstMatch(in: alias, range: range)?.range == range else {
      throw NativeSecurityError.invalidArguments
    }
    return alias
  }

  private func mapStatus(_ status: OSStatus) -> NativeSecurityError {
    switch status {
    case errSecItemNotFound: return .keyNotFound
    case errSecAuthFailed, errSecInteractionNotAllowed, errSecUserCanceled:
      return .authenticationRequired
    default: return .platformUnavailable
    }
  }
}

private enum NativeSecurityError: Error {
  case invalidArguments
  case entropyUnavailable
  case aliasExists
  case keyNotFound
  case platformKeyInvalidated
  case authenticationRequired
  case authenticationFailed
  case platformUnavailable

  var code: String {
    switch self {
    case .keyNotFound: return "KEY_NOT_FOUND"
    case .platformKeyInvalidated: return "PLATFORM_KEY_INVALIDATED"
    case .authenticationRequired: return "AUTH_REQUIRED"
    case .authenticationFailed: return "AUTHENTICATION_FAILED"
    case .entropyUnavailable: return "ENTROPY_UNAVAILABLE"
    default: return "PLATFORM_SECURITY_UNAVAILABLE"
    }
  }

  var message: String {
    switch self {
    case .keyNotFound: return "Device key not found"
    case .platformKeyInvalidated: return "Device key invalidated"
    case .authenticationRequired: return "Local authentication required"
    case .authenticationFailed: return "Device envelope rejected"
    case .entropyUnavailable: return "Secure random unavailable"
    default: return "Platform security operation failed"
    }
  }
}
