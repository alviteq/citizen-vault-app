#include "native_channels.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <bcrypt.h>
#include <shlobj.h>
#include <wincrypt.h>

#include <chrono>
#include <filesystem>
#include <fstream>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Security.Credentials.UI.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>

#include "utils.h"

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResult;

std::optional<std::string> StringArgument(const EncodableMap& arguments,
                                          const char* key) {
  const auto value = arguments.find(EncodableValue(key));
  if (value == arguments.end()) return std::nullopt;
  const auto* text = std::get_if<std::string>(&value->second);
  if (text == nullptr || text->empty()) return std::nullopt;
  return *text;
}

std::filesystem::path PathFromUtf8(const std::string& value) {
  return std::filesystem::u8path(value);
}

bool IsRegularFile(const std::filesystem::path& path) {
  std::error_code error;
  return std::filesystem::is_regular_file(path, error) && !error;
}

bool IsInsidePrivateStorage(const std::filesystem::path& input) {
  std::error_code error;
  const auto path = std::filesystem::weakly_canonical(input, error);
  if (error) return false;
  wchar_t local_app_data[MAX_PATH] = {};
  const auto local_available =
      SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_LOCAL_APPDATA, nullptr,
                                 SHGFP_TYPE_CURRENT, local_app_data));
  wchar_t temporary[MAX_PATH] = {};
  const auto temporary_length = GetTempPathW(MAX_PATH, temporary);
  const std::filesystem::path roots[] = {
      local_available ? std::filesystem::path(local_app_data)
                      : std::filesystem::path(),
      temporary_length > 0 ? std::filesystem::path(temporary)
                           : std::filesystem::path(),
  };
  for (const auto& root_value : roots) {
    if (root_value.empty()) continue;
    const auto root = std::filesystem::weakly_canonical(root_value, error);
    if (error) continue;
    auto path_iterator = path.begin();
    auto root_iterator = root.begin();
    while (path_iterator != path.end() && root_iterator != root.end() &&
           _wcsicmp(path_iterator->c_str(), root_iterator->c_str()) == 0) {
      ++path_iterator;
      ++root_iterator;
    }
    if (root_iterator == root.end()) return true;
  }
  return false;
}

bool IsSafeFilename(const std::string& value) {
  return !value.empty() && value.size() <= 255 && value != "." &&
         value != ".." && value.find_first_of("/\\") == std::string::npos &&
         value.find('\0') == std::string::npos;
}

std::optional<std::vector<uint8_t>> BytesArgument(
    const EncodableMap& arguments, const char* key) {
  const auto value = arguments.find(EncodableValue(key));
  if (value == arguments.end()) return std::nullopt;
  const auto* bytes = std::get_if<std::vector<uint8_t>>(&value->second);
  if (bytes == nullptr) return std::nullopt;
  return *bytes;
}

std::vector<uint8_t> ProtectForCurrentUser(
    const std::vector<uint8_t>& plaintext, const std::string& alias) {
  DATA_BLOB input = {
      static_cast<DWORD>(plaintext.size()),
      const_cast<BYTE*>(plaintext.data()),
  };
  auto alias_bytes = std::vector<uint8_t>(alias.begin(), alias.end());
  DATA_BLOB entropy = {
      static_cast<DWORD>(alias_bytes.size()),
      alias_bytes.data(),
  };
  DATA_BLOB output = {};
  if (!CryptProtectData(&input, L"OwnKeep device envelope", &entropy, nullptr,
                        nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output)) {
    throw std::runtime_error("DPAPI protection failed");
  }
  std::vector<uint8_t> protected_bytes(output.pbData,
                                       output.pbData + output.cbData);
  SecureZeroMemory(output.pbData, output.cbData);
  LocalFree(output.pbData);
  return protected_bytes;
}

std::vector<uint8_t> UnprotectForCurrentUser(
    const std::vector<uint8_t>& ciphertext, const std::string& alias) {
  DATA_BLOB input = {
      static_cast<DWORD>(ciphertext.size()),
      const_cast<BYTE*>(ciphertext.data()),
  };
  auto alias_bytes = std::vector<uint8_t>(alias.begin(), alias.end());
  DATA_BLOB entropy = {
      static_cast<DWORD>(alias_bytes.size()),
      alias_bytes.data(),
  };
  DATA_BLOB output = {};
  if (!CryptUnprotectData(&input, nullptr, &entropy, nullptr, nullptr,
                          CRYPTPROTECT_UI_FORBIDDEN, &output)) {
    throw std::runtime_error("DPAPI authentication failed");
  }
  std::vector<uint8_t> plaintext(output.pbData, output.pbData + output.cbData);
  SecureZeroMemory(output.pbData, output.cbData);
  LocalFree(output.pbData);
  return plaintext;
}

std::wstring SuggestedPath(const std::string& filename) {
  wchar_t downloads[MAX_PATH] = {};
  if (SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_PERSONAL, nullptr,
                                 SHGFP_TYPE_CURRENT, downloads))) {
    return (std::filesystem::path(downloads) /
            PathFromUtf8(filename)).wstring();
  }
  return PathFromUtf8(filename).wstring();
}

bool ExportFile(HWND window, const std::filesystem::path& source,
                const std::string& suggested_name) {
  if (!IsRegularFile(source) || !IsSafeFilename(suggested_name)) return false;
  std::wstring destination = SuggestedPath(suggested_name);
  destination.resize(32768, L'\0');
  OPENFILENAMEW dialog = {};
  dialog.lStructSize = sizeof(dialog);
  dialog.hwndOwner = window;
  dialog.lpstrFile = destination.data();
  dialog.nMaxFile = static_cast<DWORD>(destination.size());
  dialog.lpstrFilter = L"All files\0*.*\0\0";
  dialog.Flags = OFN_OVERWRITEPROMPT | OFN_PATHMUSTEXIST;
  if (!GetSaveFileNameW(&dialog)) return false;
  return CopyFileW(source.c_str(), dialog.lpstrFile, FALSE) != 0;
}

winrt::fire_and_forget RecognizeImage(
    std::filesystem::path source, std::string language,
    std::unique_ptr<MethodResult<EncodableValue>> result) {
  const winrt::apartment_context platform_thread;
  co_await winrt::resume_background();
  try {
  const auto file =
        co_await winrt::Windows::Storage::StorageFile::GetFileFromPathAsync(
            source.wstring());
  const auto stream =
        co_await file.OpenAsync(winrt::Windows::Storage::FileAccessMode::Read);
  const auto decoder =
        co_await winrt::Windows::Graphics::Imaging::BitmapDecoder::CreateAsync(
            stream);
  const auto bitmap =
        co_await decoder.GetSoftwareBitmapAsync(
            winrt::Windows::Graphics::Imaging::BitmapPixelFormat::Bgra8,
            winrt::Windows::Graphics::Imaging::BitmapAlphaMode::Premultiplied);

  auto engine =
      winrt::Windows::Media::Ocr::OcrEngine::TryCreateFromLanguage(
          winrt::Windows::Globalization::Language(
              winrt::to_hstring(language)));
  if (engine == nullptr) {
    engine =
        winrt::Windows::Media::Ocr::OcrEngine::TryCreateFromUserProfileLanguages();
  }
  if (engine == nullptr) throw std::runtime_error("OCR engine unavailable");
    const auto recognized = co_await engine.RecognizeAsync(bitmap);
    const auto text = Utf8FromUtf16(recognized.Text().c_str());
    co_await platform_thread;
    result->Success(EncodableValue(text));
  } catch (...) {
    co_await platform_thread;
    result->Error("OCR_FAILED", "Text recognition failed");
  }
}

void HandleOcr(const MethodCall<EncodableValue>& call,
               std::unique_ptr<MethodResult<EncodableValue>> result) {
  if (call.method_name() != "recognizeText") {
    result->NotImplemented();
    return;
  }
  const auto* arguments = std::get_if<EncodableMap>(call.arguments());
  if (arguments == nullptr) {
    result->Error("INVALID_SOURCE", "OCR source unavailable");
    return;
  }
  const auto path = StringArgument(*arguments, "path");
  const auto language = StringArgument(*arguments, "language");
  if (!path || !language || !IsRegularFile(PathFromUtf8(*path)) ||
      !IsInsidePrivateStorage(PathFromUtf8(*path))) {
    result->Error("INVALID_SOURCE", "OCR source unavailable");
    return;
  }
  RecognizeImage(PathFromUtf8(*path), *language, std::move(result));
}

void HandleFiles(HWND window, const MethodCall<EncodableValue>& call,
                 std::unique_ptr<MethodResult<EncodableValue>> result) {
  const auto* arguments = std::get_if<EncodableMap>(call.arguments());
  if (arguments == nullptr) {
    result->Error("INVALID_SOURCE", "File arguments unavailable");
    return;
  }
  if (call.method_name() == "availableBytes") {
    const auto path = StringArgument(*arguments, "path");
    if (!path) {
      result->Error("INVALID_PATH", "Storage path unavailable");
      return;
    }
    ULARGE_INTEGER available = {};
    if (!GetDiskFreeSpaceExW(PathFromUtf8(*path).c_str(), &available, nullptr,
                             nullptr)) {
      result->Error("STORAGE_UNAVAILABLE", "Storage capacity unavailable");
      return;
    }
    result->Success(
        EncodableValue(static_cast<int64_t>(available.QuadPart)));
    return;
  }

  const auto source_path = StringArgument(*arguments, "sourcePath");
  if (!source_path || !IsRegularFile(PathFromUtf8(*source_path)) ||
      !IsInsidePrivateStorage(PathFromUtf8(*source_path))) {
    result->Error("INVALID_SOURCE", "Export source unavailable");
    return;
  }
  std::string suggested_name;
  if (call.method_name() == "exportArchive") {
    suggested_name = "OwnKeep Backup.cvault";
  } else if (call.method_name() == "exportDocument") {
    const auto name = StringArgument(*arguments, "suggestedName");
    if (!name || !IsSafeFilename(*name)) {
      result->Error("INVALID_SOURCE", "Document name unavailable");
      return;
    }
    suggested_name = *name;
  } else {
    result->NotImplemented();
    return;
  }
  result->Success(
      EncodableValue(ExportFile(window, PathFromUtf8(*source_path),
                                suggested_name)));
}

winrt::fire_and_forget HandleAuthenticatedSecurity(
    std::string method, EncodableMap arguments,
    std::unique_ptr<MethodResult<EncodableValue>> result) {
  const winrt::apartment_context platform_thread;
  try {
    const auto availability =
        co_await winrt::Windows::Security::Credentials::UI::UserConsentVerifier::
            CheckAvailabilityAsync();
    if (availability !=
        winrt::Windows::Security::Credentials::UI::
            UserConsentVerifierAvailability::Available) {
      result->Error("PLATFORM_SECURITY_UNAVAILABLE",
                    "Windows Hello is unavailable");
      co_return;
    }
    const auto verification =
        co_await winrt::Windows::Security::Credentials::UI::UserConsentVerifier::
            RequestVerificationAsync(L"Unlock OwnKeep");
    if (verification !=
        winrt::Windows::Security::Credentials::UI::
            UserConsentVerificationResult::Verified) {
      result->Error("AUTH_REQUIRED", "Windows Hello verification required");
      co_return;
    }
    co_await winrt::resume_background();
    const auto alias = StringArgument(arguments, "keyAlias");
    if (!alias) throw std::runtime_error("Invalid alias");
    if (method == "wrapDeviceKey") {
      auto master_key = BytesArgument(arguments, "masterKey");
      if (!master_key || master_key->size() != 32) {
        throw std::runtime_error("Invalid master key");
      }
      const auto ciphertext = ProtectForCurrentUser(*master_key, *alias);
      SecureZeroMemory(master_key->data(), master_key->size());
      const auto created_at =
          std::chrono::duration_cast<std::chrono::milliseconds>(
              std::chrono::system_clock::now().time_since_epoch())
              .count();
      EncodableMap response = {
          {EncodableValue("nonce"), EncodableValue(std::vector<uint8_t>{})},
          {EncodableValue("ciphertext"), EncodableValue(ciphertext)},
          {EncodableValue("authenticationTag"),
           EncodableValue(std::vector<uint8_t>{})},
          {EncodableValue("createdAtEpochMilliseconds"),
           EncodableValue(static_cast<int64_t>(created_at))},
          {EncodableValue("hardwareBacked"), EncodableValue(false)},
      };
      co_await platform_thread;
      result->Success(EncodableValue(response));
      co_return;
    }
    const auto ciphertext = BytesArgument(arguments, "ciphertext");
    if (!ciphertext || ciphertext->empty()) {
      throw std::runtime_error("Invalid envelope");
    }
    auto plaintext = UnprotectForCurrentUser(*ciphertext, *alias);
    co_await platform_thread;
    result->Success(EncodableValue(plaintext));
    SecureZeroMemory(plaintext.data(), plaintext.size());
  } catch (...) {
    co_await platform_thread;
    result->Error("AUTHENTICATION_FAILED",
                  "Device envelope operation failed");
  }
}

void HandleSecurity(const MethodCall<EncodableValue>& call,
                    std::unique_ptr<MethodResult<EncodableValue>> result) {
  const auto* arguments = std::get_if<EncodableMap>(call.arguments());
  if (arguments == nullptr) {
    result->Error("PLATFORM_SECURITY_UNAVAILABLE",
                  "Security arguments unavailable");
    return;
  }
  if (call.method_name() == "secureRandom") {
    const auto length_value = arguments->find(EncodableValue("length"));
    if (length_value == arguments->end()) {
      result->Error("ENTROPY_UNAVAILABLE", "Invalid random length");
      return;
    }
    const auto* length32 = std::get_if<int32_t>(&length_value->second);
    const auto* length64 = std::get_if<int64_t>(&length_value->second);
    const int64_t length =
        length32 != nullptr ? *length32 : (length64 != nullptr ? *length64 : 0);
    if (length < 1 || length > 1024 * 1024) {
      result->Error("ENTROPY_UNAVAILABLE", "Invalid random length");
      return;
    }
    std::vector<uint8_t> bytes(static_cast<size_t>(length));
    if (BCryptGenRandom(nullptr, bytes.data(),
                        static_cast<ULONG>(bytes.size()),
                        BCRYPT_USE_SYSTEM_PREFERRED_RNG) != 0) {
      result->Error("ENTROPY_UNAVAILABLE", "Secure random unavailable");
      return;
    }
    result->Success(EncodableValue(bytes));
    return;
  }
  if (call.method_name() == "deleteDeviceKey") {
    // DPAPI protects the envelope itself; no separate key record is retained.
    result->Success();
    return;
  }
  if (call.method_name() == "wrapDeviceKey" ||
      call.method_name() == "unwrapDeviceKey") {
    HandleAuthenticatedSecurity(call.method_name(), *arguments,
                                std::move(result));
    return;
  }
  result->NotImplemented();
}

}  // namespace

void RegisterNativeChannels(flutter::FlutterEngine* engine, HWND window) {
  const auto* codec = &flutter::StandardMethodCodec::GetInstance();
  auto ocr = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      engine->messenger(), "app.citizenvault/ocr", codec);
  ocr->SetMethodCallHandler(
      [](const auto& call, auto result) {
        HandleOcr(call, std::move(result));
      });
  auto files = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      engine->messenger(), "citizen_vault/files", codec);
  files->SetMethodCallHandler(
      [window](const auto& call, auto result) {
        HandleFiles(window, call, std::move(result));
      });
  auto security = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      engine->messenger(), "citizen_vault/security", codec);
  security->SetMethodCallHandler(
      [](const auto& call, auto result) {
        HandleSecurity(call, std::move(result));
      });

  // MethodChannel handlers stay registered with the engine after these
  // wrappers are destroyed.
}
