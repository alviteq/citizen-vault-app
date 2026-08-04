#include "native_channels.h"

#include <fcntl.h>
#include <libsecret/secret.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <sys/random.h>
#include <sys/stat.h>
#include <sys/statvfs.h>

#include <cstring>
#include <string>
#include <vector>

namespace {

constexpr char kOcrChannel[] = "app.citizenvault/ocr";
constexpr char kFileChannel[] = "citizen_vault/files";
constexpr char kSecurityChannel[] = "citizen_vault/security";
constexpr char kEnvelopeAad[] = "citizen-vault/device-envelope/v1";

const SecretSchema* envelope_schema() {
  static SecretSchema schema = {};
  static gsize initialized = 0;
  if (g_once_init_enter(&initialized)) {
    schema.name = "app.citizenvault.device-envelope";
    schema.flags = SECRET_SCHEMA_NONE;
    schema.attributes[0].name = "alias";
    schema.attributes[0].type = SECRET_SCHEMA_ATTRIBUTE_STRING;
    g_once_init_leave(&initialized, 1);
  }
  return &schema;
}

const gchar* string_argument(FlValue* arguments, const gchar* key) {
  if (arguments == nullptr || fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  FlValue* value = fl_value_lookup_string(arguments, key);
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_STRING
             ? fl_value_get_string(value)
             : nullptr;
}

FlValue* bytes_argument(FlValue* arguments, const gchar* key) {
  if (arguments == nullptr || fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  FlValue* value = fl_value_lookup_string(arguments, key);
  return value != nullptr &&
                 fl_value_get_type(value) == FL_VALUE_TYPE_UINT8_LIST
             ? value
             : nullptr;
}

void respond_error(FlMethodCall* call, const gchar* code,
                   const gchar* message) {
  g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
      fl_method_error_response_new(code, message, nullptr));
  fl_method_call_respond(call, response, nullptr);
}

void respond_success(FlMethodCall* call, FlValue* value = nullptr) {
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  fl_method_call_respond(call, response, nullptr);
}

bool is_regular_private_file(const gchar* input) {
  if (input == nullptr) return false;
  g_autofree gchar* path = g_canonicalize_filename(input, nullptr);
  struct stat info = {};
  if (stat(path, &info) != 0 || !S_ISREG(info.st_mode)) return false;
  const gchar* roots[] = {
      g_get_user_data_dir(),
      g_get_user_cache_dir(),
      g_get_tmp_dir(),
  };
  for (const gchar* root_value : roots) {
    g_autofree gchar* root = g_canonicalize_filename(root_value, nullptr);
    const gsize length = strlen(root);
    if (strncmp(path, root, length) == 0 &&
        (path[length] == '\0' || path[length] == G_DIR_SEPARATOR)) {
      return true;
    }
  }
  return false;
}

bool safe_filename(const gchar* name) {
  if (name == nullptr) return false;
  const gsize length = strlen(name);
  return length > 0 && length <= 255 && strcmp(name, ".") != 0 &&
         strcmp(name, "..") != 0 && strchr(name, '/') == nullptr &&
         strchr(name, '\\') == nullptr;
}

bool valid_alias(const gchar* alias) {
  if (alias == nullptr) return false;
  const gsize length = strlen(alias);
  if (length < 1 || length > 128) return false;
  for (gsize index = 0; index < length; index++) {
    const gchar value = alias[index];
    if (!(g_ascii_isalnum(value) || value == '.' || value == '_' ||
          value == '-')) {
      return false;
    }
  }
  return true;
}

bool has_cvault_suffix(const gchar* path) {
  if (path == nullptr) return false;
  g_autofree gchar* lower = g_ascii_strdown(path, -1);
  return g_str_has_suffix(lower, ".cvault");
}

const gchar* tesseract_language(const gchar* language) {
  if (g_strcmp0(language, "hi") == 0) return "hin";
  if (g_strcmp0(language, "mr") == 0) return "mar";
  if (g_strcmp0(language, "ta") == 0) return "tam";
  if (g_strcmp0(language, "te") == 0) return "tel";
  if (g_strcmp0(language, "kn") == 0) return "kan";
  if (g_strcmp0(language, "ml") == 0) return "mal";
  if (g_strcmp0(language, "bn") == 0) return "ben";
  return "eng";
}

void handle_ocr(FlMethodCall* call) {
  if (strcmp(fl_method_call_get_name(call), "recognizeText") != 0) {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(call, response, nullptr);
    return;
  }
  FlValue* arguments = fl_method_call_get_args(call);
  const gchar* path = string_argument(arguments, "path");
  const gchar* language = string_argument(arguments, "language");
  if (!is_regular_private_file(path) || language == nullptr) {
    respond_error(call, "INVALID_SOURCE", "OCR source unavailable");
    return;
  }
  g_autofree gchar* executable = g_find_program_in_path("tesseract");
  if (executable == nullptr) {
    respond_error(call, "OCR_PROVIDER_UNAVAILABLE",
                  "Install the Tesseract OCR package");
    return;
  }
  gchar* argv[] = {
      executable,
      const_cast<gchar*>(path),
      const_cast<gchar*>("stdout"),
      const_cast<gchar*>("-l"),
      const_cast<gchar*>(tesseract_language(language)),
      const_cast<gchar*>("--psm"),
      const_cast<gchar*>("6"),
      nullptr,
  };
  g_autofree gchar* output = nullptr;
  gint status = 0;
  g_autoptr(GError) error = nullptr;
  if (!g_spawn_sync(nullptr, argv, nullptr, G_SPAWN_STDERR_TO_DEV_NULL, nullptr,
                    nullptr, &output, nullptr, &status, &error) ||
      !g_spawn_check_wait_status(status, &error)) {
    respond_error(call, "OCR_FAILED", "Text recognition failed");
    return;
  }
  g_autoptr(FlValue) value = fl_value_new_string(output == nullptr ? "" : output);
  respond_success(call, value);
}

void export_file(FlMethodCall* call, GtkWindow* window, bool archive) {
  FlValue* arguments = fl_method_call_get_args(call);
  const gchar* source = string_argument(arguments, "sourcePath");
  const gchar* name = archive ? "OwnKeep Backup.cvault"
                              : string_argument(arguments, "suggestedName");
  if (!is_regular_private_file(source) || !safe_filename(name) ||
      (archive && !has_cvault_suffix(source))) {
    respond_error(call, "INVALID_SOURCE", "Export source unavailable");
    return;
  }
  GtkWidget* dialog = gtk_file_chooser_dialog_new(
      "Save OwnKeep file", window, GTK_FILE_CHOOSER_ACTION_SAVE, "_Cancel",
      GTK_RESPONSE_CANCEL, "_Save", GTK_RESPONSE_ACCEPT, nullptr);
  gtk_file_chooser_set_do_overwrite_confirmation(GTK_FILE_CHOOSER(dialog), TRUE);
  gtk_file_chooser_set_current_name(GTK_FILE_CHOOSER(dialog), name);
  if (gtk_dialog_run(GTK_DIALOG(dialog)) != GTK_RESPONSE_ACCEPT) {
    gtk_widget_destroy(dialog);
    g_autoptr(FlValue) value = fl_value_new_bool(false);
    respond_success(call, value);
    return;
  }
  g_autofree gchar* destination =
      gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
  gtk_widget_destroy(dialog);
  g_autoptr(GFile) source_file = g_file_new_for_path(source);
  g_autoptr(GFile) destination_file = g_file_new_for_path(destination);
  g_autoptr(GError) error = nullptr;
  if (!g_file_copy(source_file, destination_file, G_FILE_COPY_OVERWRITE,
                   nullptr, nullptr, nullptr, &error)) {
    respond_error(call, "EXPORT_UNAVAILABLE", "Export failed");
    return;
  }
  g_autoptr(FlValue) value = fl_value_new_bool(true);
  respond_success(call, value);
}

void handle_files(FlMethodCall* call, GtkWindow* window) {
  const gchar* method = fl_method_call_get_name(call);
  if (strcmp(method, "exportArchive") == 0) {
    export_file(call, window, true);
    return;
  }
  if (strcmp(method, "exportDocument") == 0) {
    export_file(call, window, false);
    return;
  }
  if (strcmp(method, "availableBytes") == 0) {
    const gchar* path =
        string_argument(fl_method_call_get_args(call), "path");
    struct statvfs capacity = {};
    if (path == nullptr || statvfs(path, &capacity) != 0) {
      respond_error(call, "STORAGE_UNAVAILABLE",
                    "Storage capacity unavailable");
      return;
    }
    const guint64 bytes =
        static_cast<guint64>(capacity.f_bavail) * capacity.f_frsize;
    g_autoptr(FlValue) value =
        fl_value_new_int(static_cast<int64_t>(bytes));
    respond_success(call, value);
    return;
  }
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(call, response, nullptr);
}

bool aes_gcm_encrypt(const guint8* plaintext, gsize plaintext_length,
                     const guint8* key, std::vector<guint8>* nonce,
                     std::vector<guint8>* ciphertext,
                     std::vector<guint8>* tag) {
  nonce->resize(12);
  ciphertext->resize(plaintext_length);
  tag->resize(16);
  if (RAND_bytes(nonce->data(), nonce->size()) != 1) return false;
  EVP_CIPHER_CTX* context = EVP_CIPHER_CTX_new();
  if (context == nullptr) return false;
  int length = 0;
  int output_length = 0;
  bool ok =
      EVP_EncryptInit_ex(context, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) ==
          1 &&
      EVP_CIPHER_CTX_ctrl(context, EVP_CTRL_GCM_SET_IVLEN, nonce->size(),
                          nullptr) == 1 &&
      EVP_EncryptInit_ex(context, nullptr, nullptr, key, nonce->data()) == 1 &&
      EVP_EncryptUpdate(
          context, nullptr, &length,
          reinterpret_cast<const guint8*>(kEnvelopeAad),
          strlen(kEnvelopeAad)) == 1 &&
      EVP_EncryptUpdate(context, ciphertext->data(), &length, plaintext,
                        plaintext_length) == 1;
  output_length = length;
  ok = ok && EVP_EncryptFinal_ex(context, ciphertext->data() + output_length,
                                 &length) == 1;
  output_length += length;
  ciphertext->resize(output_length);
  ok = ok && EVP_CIPHER_CTX_ctrl(context, EVP_CTRL_GCM_GET_TAG, tag->size(),
                                 tag->data()) == 1;
  EVP_CIPHER_CTX_free(context);
  return ok;
}

bool aes_gcm_decrypt(const guint8* ciphertext, gsize ciphertext_length,
                     const guint8* key, const guint8* nonce,
                     gsize nonce_length, const guint8* tag, gsize tag_length,
                     std::vector<guint8>* plaintext) {
  if (nonce_length != 12 || tag_length != 16) return false;
  plaintext->resize(ciphertext_length);
  EVP_CIPHER_CTX* context = EVP_CIPHER_CTX_new();
  if (context == nullptr) return false;
  int length = 0;
  int output_length = 0;
  bool ok =
      EVP_DecryptInit_ex(context, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) ==
          1 &&
      EVP_CIPHER_CTX_ctrl(context, EVP_CTRL_GCM_SET_IVLEN, nonce_length,
                          nullptr) == 1 &&
      EVP_DecryptInit_ex(context, nullptr, nullptr, key, nonce) == 1 &&
      EVP_DecryptUpdate(
          context, nullptr, &length,
          reinterpret_cast<const guint8*>(kEnvelopeAad),
          strlen(kEnvelopeAad)) == 1 &&
      EVP_DecryptUpdate(context, plaintext->data(), &length, ciphertext,
                        ciphertext_length) == 1;
  output_length = length;
  ok = ok && EVP_CIPHER_CTX_ctrl(context, EVP_CTRL_GCM_SET_TAG, tag_length,
                                 const_cast<guint8*>(tag)) == 1 &&
       EVP_DecryptFinal_ex(context, plaintext->data() + output_length,
                           &length) == 1;
  output_length += length;
  plaintext->resize(output_length);
  EVP_CIPHER_CTX_free(context);
  return ok;
}

gchar* lookup_key(const gchar* alias, GError** error) {
  return secret_password_lookup_sync(envelope_schema(), nullptr, error, "alias",
                                     alias, nullptr);
}

void handle_security(FlMethodCall* call) {
  const gchar* method = fl_method_call_get_name(call);
  FlValue* arguments = fl_method_call_get_args(call);
  if (strcmp(method, "secureRandom") == 0) {
    FlValue* length_value =
        arguments == nullptr ? nullptr
                             : fl_value_lookup_string(arguments, "length");
    const int64_t length =
        length_value == nullptr ? 0 : fl_value_get_int(length_value);
    if (length < 1 || length > 1024 * 1024) {
      respond_error(call, "ENTROPY_UNAVAILABLE", "Invalid random length");
      return;
    }
    std::vector<guint8> bytes(length);
    if (getrandom(bytes.data(), bytes.size(), 0) != length) {
      respond_error(call, "ENTROPY_UNAVAILABLE", "Secure random unavailable");
      return;
    }
    g_autoptr(FlValue) value =
        fl_value_new_uint8_list(bytes.data(), bytes.size());
    respond_success(call, value);
    return;
  }
  const gchar* alias = string_argument(arguments, "keyAlias");
  if (!valid_alias(alias)) {
    respond_error(call, "PLATFORM_SECURITY_UNAVAILABLE", "Invalid key alias");
    return;
  }
  if (strcmp(method, "deleteDeviceKey") == 0) {
    g_autoptr(GError) error = nullptr;
    const gboolean cleared =
        secret_password_clear_sync(envelope_schema(), nullptr, &error, "alias",
                                   alias, nullptr);
    if (!cleared && error != nullptr) {
      respond_error(call, "PLATFORM_SECURITY_UNAVAILABLE",
                    "System keyring unavailable");
      return;
    }
    respond_success(call);
    return;
  }
  if (strcmp(method, "wrapDeviceKey") == 0) {
    FlValue* master = bytes_argument(arguments, "masterKey");
    if (master == nullptr || fl_value_get_length(master) != 32) {
      respond_error(call, "PLATFORM_SECURITY_UNAVAILABLE",
                    "Invalid master key");
      return;
    }
    std::vector<guint8> key(32);
    if (getrandom(key.data(), key.size(), 0) !=
        static_cast<ssize_t>(key.size())) {
      respond_error(call, "ENTROPY_UNAVAILABLE", "Secure random unavailable");
      return;
    }
    g_autofree gchar* encoded =
        g_base64_encode(key.data(), static_cast<gsize>(key.size()));
    g_autoptr(GError) error = nullptr;
    if (!secret_password_store_sync(
            envelope_schema(), SECRET_COLLECTION_DEFAULT, "OwnKeep vault key",
            encoded, nullptr, &error, "alias", alias, nullptr)) {
      OPENSSL_cleanse(key.data(), key.size());
      respond_error(call, "PLATFORM_SECURITY_UNAVAILABLE",
                    "System keyring unavailable");
      return;
    }
    std::vector<guint8> nonce;
    std::vector<guint8> ciphertext;
    std::vector<guint8> tag;
    const bool encrypted = aes_gcm_encrypt(
        fl_value_get_uint8_list(master), fl_value_get_length(master),
        key.data(), &nonce, &ciphertext, &tag);
    OPENSSL_cleanse(key.data(), key.size());
    if (!encrypted) {
      secret_password_clear_sync(envelope_schema(), nullptr, nullptr, "alias",
                                 alias, nullptr);
      respond_error(call, "PLATFORM_SECURITY_UNAVAILABLE",
                    "Envelope encryption failed");
      return;
    }
    g_autoptr(FlValue) response = fl_value_new_map();
    fl_value_set_string_take(
        response, "nonce",
        fl_value_new_uint8_list(nonce.data(), nonce.size()));
    fl_value_set_string_take(
        response, "ciphertext",
        fl_value_new_uint8_list(ciphertext.data(), ciphertext.size()));
    fl_value_set_string_take(
        response, "authenticationTag",
        fl_value_new_uint8_list(tag.data(), tag.size()));
    fl_value_set_string_take(
        response, "createdAtEpochMilliseconds",
        fl_value_new_int(g_get_real_time() / 1000));
    fl_value_set_string_take(response, "hardwareBacked",
                             fl_value_new_bool(false));
    fl_value_set_string_take(response, "requiresAuthentication",
                             fl_value_new_bool(false));
    respond_success(call, response);
    return;
  }
  if (strcmp(method, "unwrapDeviceKey") == 0) {
    FlValue* nonce = bytes_argument(arguments, "nonce");
    FlValue* ciphertext = bytes_argument(arguments, "ciphertext");
    FlValue* tag = bytes_argument(arguments, "authenticationTag");
    g_autoptr(GError) error = nullptr;
    g_autofree gchar* encoded = lookup_key(alias, &error);
    if (encoded == nullptr) {
      respond_error(call, "KEY_NOT_FOUND", "System keyring entry unavailable");
      return;
    }
    gsize key_length = 0;
    g_autofree guchar* key = g_base64_decode(encoded, &key_length);
    std::vector<guint8> plaintext;
    const bool decrypted =
        key_length == 32 && nonce != nullptr && ciphertext != nullptr &&
        tag != nullptr &&
        aes_gcm_decrypt(
            fl_value_get_uint8_list(ciphertext),
            fl_value_get_length(ciphertext), key,
            fl_value_get_uint8_list(nonce), fl_value_get_length(nonce),
            fl_value_get_uint8_list(tag), fl_value_get_length(tag),
            &plaintext);
    OPENSSL_cleanse(key, key_length);
    if (!decrypted || plaintext.size() != 32) {
      respond_error(call, "AUTHENTICATION_FAILED",
                    "Envelope authentication failed");
      return;
    }
    g_autoptr(FlValue) value =
        fl_value_new_uint8_list(plaintext.data(), plaintext.size());
    respond_success(call, value);
    OPENSSL_cleanse(plaintext.data(), plaintext.size());
    return;
  }
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(call, response, nullptr);
}

void ocr_handler(FlMethodChannel*, FlMethodCall* call, gpointer) {
  handle_ocr(call);
}

void file_handler(FlMethodChannel*, FlMethodCall* call, gpointer user_data) {
  handle_files(call, GTK_WINDOW(user_data));
}

void security_handler(FlMethodChannel*, FlMethodCall* call, gpointer) {
  handle_security(call);
}

}  // namespace

void register_native_channels(FlView* view, GtkWindow* window) {
  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) ocr =
      fl_method_channel_new(messenger, kOcrChannel, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(ocr, ocr_handler, nullptr, nullptr);
  g_autoptr(FlMethodChannel) files =
      fl_method_channel_new(messenger, kFileChannel, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(files, file_handler, window,
                                            nullptr);
  g_autoptr(FlMethodChannel) security =
      fl_method_channel_new(messenger, kSecurityChannel, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(security, security_handler, nullptr,
                                            nullptr);
}
