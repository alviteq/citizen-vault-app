import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:vault_domain/vault_domain.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

/// Native picker boundary used only while registering an encrypted original.
abstract interface class ImportPicker {
  /// Selects one supported document file.
  Future<IngestionCandidate?> pickFile();

  /// Selects one image from the gallery.
  Future<IngestionCandidate?> pickGalleryImage();

  /// Captures one image using the camera.
  Future<IngestionCandidate?> captureImage();

  /// Recovers image results lost during Android activity destruction.
  Future<List<IngestionCandidate>> recoverLostImages();
}

/// `file_selector` and `image_picker` adapter with no persisted physical paths.
final class DeviceImportPicker implements ImportPicker {
  /// Creates the native picker adapter.
  DeviceImportPicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<IngestionCandidate?> pickFile() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: 'Documents',
          extensions: <String>[
            'pdf',
            'jpg',
            'jpeg',
            'png',
            'webp',
            'gif',
            'bmp',
            'tif',
            'tiff',
            'heic',
            'heif',
            'txt',
            'doc',
            'docx',
            'xls',
            'xlsx',
            'ppt',
            'pptx',
            'csv',
          ],
        ),
      ],
    );
    return file == null
        ? null
        : _fromXFile(file, DocumentImportSource.filePicker);
  }

  @override
  Future<IngestionCandidate?> pickGalleryImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      return file == null
          ? null
          : _fromXFile(file, DocumentImportSource.gallery);
    } catch (_) {
      // Desktop platforms use the native file chooser as their gallery.
      return pickFile();
    }
  }

  @override
  Future<IngestionCandidate?> captureImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        requestFullMetadata: false,
      );
      return file == null
          ? null
          : _fromXFile(file, DocumentImportSource.camera);
    } catch (e) {
      // Fallback to file picker if camera is unsupported (e.g. macOS desktop without delegate)
      return pickFile();
    }
  }

  @override
  Future<List<IngestionCandidate>> recoverLostImages() async {
    LostDataResponse response;
    try {
      response = await _imagePicker.retrieveLostData();
    } catch (_) {
      return const <IngestionCandidate>[];
    }
    if (response.isEmpty || response.files == null) {
      return const <IngestionCandidate>[];
    }
    final output = <IngestionCandidate>[];
    for (final file in response.files!) {
      output.add(await _fromXFile(file, DocumentImportSource.gallery));
    }
    return output;
  }

  static Future<IngestionCandidate> _fromXFile(
    XFile file,
    DocumentImportSource source,
  ) async {
    final length = await file.length();
    final mimeType = file.mimeType ?? lookupMimeType(file.name) ?? '';
    return IngestionCandidate(
      logicalFilename: file.name,
      mimeType: mimeType.toLowerCase(),
      length: length,
      source: source,
      openRead: file.openRead,
    );
  }
}
