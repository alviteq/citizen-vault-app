import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  UIDocumentPickerDelegate
{
  private var fileChannel: FlutterMethodChannel?
  private var ocrChannel: FlutterMethodChannel?
  private var pendingExportResult: FlutterResult?
  private var pendingExportCleanup: URL?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "citizen_vault/files",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    fileChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "UNAVAILABLE", message: "File bridge unavailable", details: nil))
        return
      }
      switch call.method {
      case "exportArchive":
        self.exportArchive(call: call, result: result)
      case "exportDocument":
        self.exportDocument(call: call, result: result)
      case "availableBytes":
        self.availableBytes(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let ocr = FlutterMethodChannel(
      name: "app.citizenvault/ocr",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    ocrChannel = ocr
    ocr.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "UNAVAILABLE", message: "OCR bridge unavailable", details: nil))
        return
      }
      switch call.method {
      case "recognizeText":
        self.recognizeText(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
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
        let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        DispatchQueue.main.async { result(text) }
      }
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      let locale = Locale(identifier: language)
      let preferred = locale.identifier
      if (try? request.supportedRecognitionLanguages())?.contains(preferred) == true {
        request.recognitionLanguages = [preferred]
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

  private func exportArchive(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
      let sourcePath = arguments["sourcePath"] as? String,
      let source = validatedPrivateFile(sourcePath),
      source.pathExtension.lowercased() == "cvault"
    else {
      result(FlutterError(code: "INVALID_SOURCE", message: "Backup source unavailable", details: nil))
      return
    }
    startExport(source: source, cleanupDirectory: nil, result: result)
  }

  private func exportDocument(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
      let sourcePath = arguments["sourcePath"] as? String,
      let suggestedName = arguments["suggestedName"] as? String,
      let mimeType = arguments["mimeType"] as? String,
      let source = validatedPrivateFile(sourcePath),
      isSafeSuggestedName(suggestedName),
      allowedDocumentMimeTypes.contains(mimeType)
    else {
      result(FlutterError(code: "INVALID_SOURCE", message: "Document source unavailable", details: nil))
      return
    }
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ownkeep-export-\(UUID().uuidString)", isDirectory: true)
    let exportURL = directory.appendingPathComponent(suggestedName, isDirectory: false)
    do {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: false
      )
      try FileManager.default.copyItem(at: source, to: exportURL)
      startExport(source: exportURL, cleanupDirectory: directory, result: result)
    } catch {
      try? FileManager.default.removeItem(at: directory)
      result(FlutterError(code: "EXPORT_UNAVAILABLE", message: "Document export unavailable", details: nil))
    }
  }

  private func startExport(
    source: URL,
    cleanupDirectory: URL?,
    result: @escaping FlutterResult
  ) {
    guard pendingExportResult == nil else {
      if let cleanupDirectory {
        try? FileManager.default.removeItem(at: cleanupDirectory)
      }
      result(FlutterError(code: "EXPORT_BUSY", message: "Another export is active", details: nil))
      return
    }
    guard let presenter = activeViewController() else {
      if let cleanupDirectory {
        try? FileManager.default.removeItem(at: cleanupDirectory)
      }
      result(FlutterError(code: "EXPORT_UNAVAILABLE", message: "Document provider unavailable", details: nil))
      return
    }
    pendingExportResult = result
    pendingExportCleanup = cleanupDirectory
    let picker = UIDocumentPickerViewController(forExporting: [source], asCopy: true)
    picker.delegate = self
    picker.shouldShowFileExtensions = true
    presenter.present(picker, animated: true)
  }

  private func availableBytes(call: FlutterMethodCall, result: FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String,
      let directory = validatedPrivateDirectory(path)
    else {
      result(FlutterError(code: "INVALID_PATH", message: "Storage path unavailable", details: nil))
      return
    }
    do {
      let values = try directory.resourceValues(
        forKeys: [.volumeAvailableCapacityForImportantUsageKey]
      )
      guard let capacity = values.volumeAvailableCapacityForImportantUsage, capacity >= 0 else {
        throw CocoaError(.fileReadUnknown)
      }
      result(capacity)
    } catch {
      result(FlutterError(code: "STORAGE_UNAVAILABLE", message: "Storage capacity unavailable", details: nil))
    }
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    let result = pendingExportResult
    pendingExportResult = nil
    cleanupPendingExport()
    result?(true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let result = pendingExportResult
    pendingExportResult = nil
    cleanupPendingExport()
    result?(false)
  }

  private func cleanupPendingExport() {
    if let directory = pendingExportCleanup {
      try? FileManager.default.removeItem(at: directory)
    }
    pendingExportCleanup = nil
  }

  private func validatedPrivateFile(_ path: String) -> URL? {
    let url = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
    guard isInsidePrivateStorage(url),
      FileManager.default.fileExists(atPath: url.path),
      (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    else { return nil }
    return url
  }

  private func validatedPrivateDirectory(_ path: String) -> URL? {
    let url = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
    guard isInsidePrivateStorage(url),
      (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    else { return nil }
    return url
  }

  private func isInsidePrivateStorage(_ url: URL) -> Bool {
    let manager = FileManager.default
    let roots = [
      manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
      manager.urls(for: .cachesDirectory, in: .userDomainMask).first,
      URL(fileURLWithPath: NSTemporaryDirectory()),
    ].compactMap { $0?.resolvingSymlinksInPath().standardizedFileURL }
    return roots.contains { root in
      url.path == root.path || url.path.hasPrefix(root.path + "/")
    }
  }

  private func isSafeSuggestedName(_ name: String) -> Bool {
    !name.isEmpty && name.utf8.count <= 255 && name != "." && name != ".."
      && !name.contains("/") && !name.contains("\\") && !name.contains("\0")
  }

  private let allowedDocumentMimeTypes: Set<String> = [
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif",
    "image/bmp",
    "image/tiff",
    "image/heic",
    "image/heif",
    "text/plain",
    "text/csv",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.ms-powerpoint",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  ]

  private func activeViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController
    var current = root
    while let presented = current?.presentedViewController {
      current = presented
    }
    return current
  }
}
