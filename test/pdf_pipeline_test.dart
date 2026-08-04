import 'package:citizen_vault_app/src/ocr/ml_kit_latin_ocr_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_ingestion/vault_ingestion.dart';
import 'package:vault_objects/vault_objects.dart';

void main() {
  test('PDF imports request a thumbnail and advertise offline OCR', () async {
    final lease = IngestionJobLease(
      jobId: 'job',
      documentId: 'document',
      originalObjectId: ObjectId.parse(
        '0123456789ABCDEFGHJKMNPQRS',
      ),
      logicalFilename: 'statement.pdf',
      mimeType: 'application/pdf',
      workerId: 'test',
      attemptCount: 1,
      leaseExpiresAt: DateTime.utc(2030),
    );

    expect(lease.requiresThumbnail, isTrue);
    expect(
      (await const MlKitLatinOcrEngine().capabilities()).supportsMimeType(
        'application/pdf',
      ),
      isTrue,
    );
  });
}
