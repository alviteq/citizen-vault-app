import Cocoa
import CryptoKit
import FlutterMacOS
import LocalAuthentication
import Security
import Vision

class MainFlutterWindow: NSWindow {
  private var ocrChannel: FlutterMethodChannel?
  private var fileChannel: FlutterMethodChannel?
  private var securityChannel: FlutterMethodChannel?
  private var biometricChannel: FlutterMethodChannel?
  private var authenticatedContext: LAContext?
  private let securityService = "app.citizenvault.device-envelope"
  private let envelopeAad = Data("citizen-vault/device-envelope/v1".utf8)

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.minSize = NSSize(width: 1024, height: 700)
    self.setContentSize(NSSize(width: 1280, height: 820))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureOcrChannel(flutterViewController)
    configureFileChannel(flutterViewController)
    configureSecurityChannel(flutterViewController)
    configureBiometricChannel(flutterViewController)

    super.awakeFromNib()
  }

  private func configureBiometricChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "citizen_vault/biometrics",
      binaryMessenger: controller.engine.binaryMessenger
    )
    biometricChannel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isAvailable":
        let context = LAContext()
        var error: NSError?
        result(
          context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
          )
        )
      case "authenticate":
        let arguments = call.arguments as? [String: Any]
        let reason = arguments?["reason"] as? String
          ?? "Use Touch ID to unlock OwnKeep"
        let context = LAContext()
        context.localizedCancelTitle = "Use vault passphrase"
        var error: NSError?
        guard context.canEvaluatePolicy(
          .deviceOwnerAuthenticationWithBiometrics,
          error: &error
        ) else {
          result(false)
          return
        }
        context.evaluatePolicy(
          .deviceOwnerAuthenticationWithBiometrics,
          localizedReason: reason
        ) { success, _ in
          DispatchQueue.main.async {
            self.authenticatedContext = success ? context : nil
            result(success)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureSecurityChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "citizen_vault/security",
      binaryMessenger: controller.engine.binaryMessenger
    )
    securityChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "PLATFORM_SECURITY_UNAVAILABLE", message: "Security bridge unavailable", details: nil))
        return
      }
      do {
        switch call.method {
        case "secureRandom": try self.secureRandom(call, result: result)
        case "wrapDeviceKey": try self.wrapDeviceKey(call, result: result)
        case "unwrapDeviceKey": try self.unwrapDeviceKey(call, result: result)
        case "deleteDeviceKey": try self.deleteDeviceKey(call, result: result)
        default: result(FlutterMethodNotImplemented)
        }
      } catch let error as DesktopSecurityError {
        NSLog("OwnKeep security bridge failure: %@", error.diagnostic)
        result(FlutterError(code: error.code, message: error.message, details: nil))
      } catch {
        NSLog("OwnKeep security bridge unexpected failure: %@", String(describing: error))
        result(FlutterError(code: "PLATFORM_SECURITY_UNAVAILABLE", message: "Security operation failed", details: nil))
      }
    }
  }

  private func secureRandom(_ call: FlutterMethodCall, result: FlutterResult) throws {
    let arguments = try securityArguments(call.arguments)
    guard let length = arguments["length"] as? Int,
      (1...(1024 * 1024)).contains(length)
    else { throw DesktopSecurityError.invalidArguments }
    var bytes = Data(count: length)
    let status = bytes.withUnsafeMutableBytes {
      SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!)
    }
    guard status == errSecSuccess else { throw DesktopSecurityError.entropyUnavailable }
    result(FlutterStandardTypedData(bytes: bytes))
  }

  private func wrapDeviceKey(_ call: FlutterMethodCall, result: FlutterResult) throws {
    let arguments = try securityArguments(call.arguments)
    let alias = try validatedAlias(arguments["keyAlias"])
    var masterKey = try securityData(arguments["masterKey"])
    guard masterKey.count == 32 else { throw DesktopSecurityError.invalidArguments }
    defer { masterKey.resetBytes(in: 0..<masterKey.count) }
    guard try !securityKeyExists(alias) else { throw DesktopSecurityError.aliasExists }

    var keyData = Data(count: 32)
    let keyLength = keyData.count
    let randomStatus = keyData.withUnsafeMutableBytes {
      SecRandomCopyBytes(kSecRandomDefault, keyLength, $0.baseAddress!)
    }
    guard randomStatus == errSecSuccess else { throw DesktopSecurityError.entropyUnavailable }
    defer { keyData.resetBytes(in: 0..<keyData.count) }

    var addQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: securityService,
      kSecAttrAccount as String: alias,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      kSecValueData as String: keyData,
      kSecUseDataProtectionKeychain as String: true,
    ]
    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
    addQuery.removeAll()
    guard addStatus == errSecSuccess else { throw securityStatus(addStatus) }

    do {
      let sealed = try AES.GCM.seal(
        masterKey,
        using: SymmetricKey(data: keyData),
        authenticating: envelopeAad
      )
      result([
        "nonce": Data(sealed.nonce).base64EncodedString(),
        "ciphertext": sealed.ciphertext.base64EncodedString(),
        "authenticationTag": sealed.tag.base64EncodedString(),
        "createdAtEpochMilliseconds": Int64(Date().timeIntervalSince1970 * 1000),
        "hardwareBacked": false,
      ])
    } catch {
      try? deleteSecurityKey(alias)
      throw error
    }
  }

  private func unwrapDeviceKey(_ call: FlutterMethodCall, result: FlutterResult) throws {
    let arguments = try securityArguments(call.arguments)
    let alias = try validatedAlias(arguments["keyAlias"])
    let nonce = try securityData(arguments["nonce"])
    let ciphertext = try securityData(arguments["ciphertext"])
    let tag = try securityData(arguments["authenticationTag"])
    guard nonce.count == 12, ciphertext.count == 32, tag.count == 16
    else { throw DesktopSecurityError.invalidArguments }
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: securityService,
      kSecAttrAccount as String: alias,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecUseDataProtectionKeychain as String: true,
    ]
    authenticatedContext = nil
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    query.removeAll()
    guard status == errSecSuccess, var keyData = item as? Data else {
      throw securityStatus(status)
    }
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
        authenticating: envelopeAad
      )
      result(FlutterStandardTypedData(bytes: plaintext))
    } catch {
      throw DesktopSecurityError.authenticationFailed
    }
  }

  private func deleteDeviceKey(_ call: FlutterMethodCall, result: FlutterResult) throws {
    let arguments = try securityArguments(call.arguments)
    try deleteSecurityKey(validatedAlias(arguments["keyAlias"]))
    result(nil)
  }

  private func securityArguments(_ value: Any?) throws -> [String: Any] {
    guard let arguments = value as? [String: Any] else {
      throw DesktopSecurityError.invalidArguments
    }
    return arguments
  }

  private func securityData(_ value: Any?) throws -> Data {
    guard let typed = value as? FlutterStandardTypedData else {
      throw DesktopSecurityError.invalidArguments
    }
    return typed.data
  }

  private func validatedAlias(_ value: Any?) throws -> String {
    guard let alias = value as? String,
      alias.range(of: #"^[A-Za-z0-9._-]{1,128}$"#, options: .regularExpression) != nil
    else { throw DesktopSecurityError.invalidArguments }
    return alias
  }

  private func securityKeyExists(_ alias: String) throws -> Bool {
    let status = SecItemCopyMatching([
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: securityService,
      kSecAttrAccount as String: alias,
      kSecReturnAttributes as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
      kSecUseDataProtectionKeychain as String: true,
    ] as CFDictionary, nil)
    if status == errSecSuccess { return true }
    if status == errSecItemNotFound { return false }
    throw securityStatus(status)
  }

  private func deleteSecurityKey(_ alias: String) throws {
    let status = SecItemDelete([
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: securityService,
      kSecAttrAccount as String: alias,
      kSecUseDataProtectionKeychain as String: true,
    ] as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound
    else { throw securityStatus(status) }
  }

  private func securityStatus(_ status: OSStatus) -> DesktopSecurityError {
    switch status {
    case errSecItemNotFound: return .keyNotFound
    case errSecAuthFailed, errSecInteractionNotAllowed, errSecUserCanceled:
      return .authenticationRequired
    default: return .osStatus(status)
    }
  }

  private func configureFileChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "citizen_vault/files",
      binaryMessenger: controller.engine.binaryMessenger
    )
    fileChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "UNAVAILABLE", message: "File bridge unavailable", details: nil))
        return
      }
      switch call.method {
      case "exportArchive":
        self.exportFile(call: call, archive: true, result: result)
      case "exportDocument":
        self.exportFile(call: call, archive: false, result: result)
      case "availableBytes":
        self.availableBytes(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func exportFile(
    call: FlutterMethodCall,
    archive: Bool,
    result: @escaping FlutterResult
  ) {
    guard let arguments = call.arguments as? [String: Any],
      let sourcePath = arguments["sourcePath"] as? String,
      let source = validatedPrivateFile(sourcePath)
    else {
      result(FlutterError(code: "INVALID_SOURCE", message: "Export source unavailable", details: nil))
      return
    }
    let suggestedName: String
    if archive {
      guard source.pathExtension.lowercased() == "cvault" else {
        result(FlutterError(code: "INVALID_SOURCE", message: "Backup source unavailable", details: nil))
        return
      }
      suggestedName = "OwnKeep Backup.cvault"
    } else {
      guard let name = arguments["suggestedName"] as? String,
        isSafeFilename(name)
      else {
        result(FlutterError(code: "INVALID_SOURCE", message: "Document name unavailable", details: nil))
        return
      }
      suggestedName = name
    }

    let panel = NSSavePanel()
    panel.nameFieldStringValue = suggestedName
    panel.canCreateDirectories = true
    guard panel.runModal() == .OK, let destination = panel.url else {
      result(false)
      return
    }
    do {
      if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
      }
      try FileManager.default.copyItem(at: source, to: destination)
      result(true)
    } catch {
      result(FlutterError(code: "EXPORT_UNAVAILABLE", message: "Export failed", details: nil))
    }
  }

  private func availableBytes(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String
    else {
      result(FlutterError(code: "INVALID_PATH", message: "Storage path unavailable", details: nil))
      return
    }
    let url = URL(fileURLWithPath: path).standardizedFileURL
    do {
      let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
      guard let bytes = values.volumeAvailableCapacityForImportantUsage, bytes >= 0 else {
        result(FlutterError(code: "STORAGE_UNAVAILABLE", message: "Storage capacity unavailable", details: nil))
        return
      }
      result(bytes)
    } catch {
      result(FlutterError(code: "STORAGE_UNAVAILABLE", message: "Storage capacity unavailable", details: nil))
    }
  }

  private func configureOcrChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "app.citizenvault/ocr",
      binaryMessenger: controller.engine.binaryMessenger
    )
    ocrChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "UNAVAILABLE", message: "OCR bridge unavailable", details: nil))
        return
      }
      guard call.method == "recognizeText" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.recognizeText(call: call, result: result)
    }
  }

  private func recognizeText(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String,
      let language = arguments["language"] as? String,
      let source = validatedPrivateFile(path)
    else {
      result(FlutterError(code: "INVALID_SOURCE", message: "OCR source unavailable", details: nil))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let request = VNRecognizeTextRequest { request, error in
        if error != nil {
          DispatchQueue.main.async {
            result(FlutterError(code: "OCR_FAILED", message: "Text recognition failed", details: nil))
          }
          return
        }
        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let text = observations
          .compactMap { $0.topCandidates(1).first?.string }
          .joined(separator: "\n")
        DispatchQueue.main.async { result(text) }
      }
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      let preferred = Locale(identifier: language).identifier
      if #available(macOS 12.0, *) {
        if (try? request.supportedRecognitionLanguages())?.contains(preferred) == true {
          request.recognitionLanguages = [preferred]
        } else {
          request.recognitionLanguages = ["en-US"]
        }
      } else {
        request.recognitionLanguages = ["en-US"]
      }

      do {
        try VNImageRequestHandler(url: source, options: [:]).perform([request])
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "OCR_FAILED", message: "Text recognition failed", details: nil))
        }
      }
    }
  }

  private func validatedPrivateFile(_ path: String) -> URL? {
    let url = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
    let manager = FileManager.default
    let roots = [
      manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
      manager.urls(for: .cachesDirectory, in: .userDomainMask).first,
      URL(fileURLWithPath: NSTemporaryDirectory()),
    ].compactMap { $0?.resolvingSymlinksInPath().standardizedFileURL }
    guard roots.contains(where: {
      url.path == $0.path || url.path.hasPrefix($0.path + "/")
    }),
      manager.fileExists(atPath: url.path),
      (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    else { return nil }
    return url
  }

  private func isSafeFilename(_ name: String) -> Bool {
    !name.isEmpty && name.utf8.count <= 255 && name != "." && name != ".."
      && !name.contains("/") && !name.contains("\\") && !name.contains("\0")
  }
}

private enum DesktopSecurityError: Error {
  case invalidArguments
  case entropyUnavailable
  case aliasExists
  case keyNotFound
  case authenticationRequired
  case authenticationFailed
  case platformUnavailable
  case osStatus(OSStatus)

  var code: String {
    switch self {
    case .keyNotFound: return "KEY_NOT_FOUND"
    case .authenticationRequired: return "AUTH_REQUIRED"
    case .authenticationFailed: return "AUTHENTICATION_FAILED"
    case .entropyUnavailable: return "ENTROPY_UNAVAILABLE"
    default: return "PLATFORM_SECURITY_UNAVAILABLE"
    }
  }

  var message: String {
    switch self {
    case .keyNotFound: return "Protected key is unavailable"
    case .authenticationRequired: return "Device authentication is required"
    case .authenticationFailed: return "Device authentication failed"
    case .entropyUnavailable: return "Secure random is unavailable"
    default: return "Platform security is unavailable"
    }
  }

  var diagnostic: String {
    switch self {
    case .osStatus(let status):
      return "Security framework status \(status)"
    default:
      return code
    }
  }
}
