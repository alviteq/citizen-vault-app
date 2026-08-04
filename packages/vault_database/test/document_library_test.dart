import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vault_crypto/vault_crypto.dart';
import 'package:vault_database/vault_database.dart';
import 'package:vault_domain/vault_domain.dart';

void main() {
  test(
    'document library filters, tags, and preferences remain encrypted',
    () async {
      final root = Directory.systemTemp.createTempSync('vault_library_test_');
      final key = SecretBytes(List<int>.generate(32, (index) => index + 1));
      final session = await EncryptedDatabaseOpener.open(
        file: File('${root.path}/vault.db'),
        databaseKey: key,
        runInBackground: false,
      );
      key.destroy();
      addTearDown(() async {
        await session.close();
        root.deleteSync(recursive: true);
      });
      await session.write((database) async {
        final timestamp = DateTime.utc(2026, 7, 25).millisecondsSinceEpoch;
        await database.customStatement(
          '''
        INSERT INTO documents(
          id, logical_filename, document_type, mime_type, source_type, status,
          primary_object_id, plaintext_sha256, plaintext_size, encrypted_size,
          imported_at, updated_at, integrity_status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
          <Object>[
            'document-1',
            'WQN2814184.pdf',
            'PASSPORT',
            'application/pdf',
            'FILE_PICKER',
            'READY',
            'object-1',
            Uint8List(32),
            100,
            200,
            timestamp,
            timestamp,
            'VERIFIED',
          ],
        );
        await database.customStatement(
          '''
        INSERT INTO document_text(
          id, document_id, page_number, raw_text, normalized_text,
          ocr_engine_id, ocr_engine_version, ocr_pipeline_version, created_at
        ) VALUES ('text-1', 'document-1', 1, 'Republic of India passport',
          'republic of india passport', 'fixture', '1', 1, ?)
        ''',
          <Object>[timestamp],
        );
        await database.customStatement(
          '''
        INSERT INTO extracted_fields(
          id, document_id, field_type, raw_value, normalized_value,
          extractor_id, extractor_version, created_at, updated_at
        ) VALUES ('field-1', 'document-1', 'FULL_NAME', 'Taraka Rao',
          'taraka rao', 'fixture', '1', ?, ?)
        ''',
          <Object>[timestamp, timestamp],
        );
        await database.indexDocument('document-1');
      });
      final library = SqlCipherDocumentLibrary(
        session: session,
        random: _FixedRandom(),
      );

      expect(
        await library.listDocuments(
          const DocumentLibraryFilter(query: 'Republic of India'),
        ),
        hasLength(1),
      );
      expect(
        await library.listDocuments(
          const DocumentLibraryFilter(query: 'India Republic'),
        ),
        hasLength(1),
      );
      expect(
        await library.listDocuments(
          const DocumentLibraryFilter(query: 'passp'),
        ),
        hasLength(1),
      );
      expect(
        await library.listDocuments(
          const DocumentLibraryFilter(query: 'w'),
        ),
        hasLength(1),
      );
      expect(
        await library.listDocuments(
          const DocumentLibraryFilter(query: 'WQN'),
        ),
        hasLength(1),
      );
      expect(
        await library.listDocuments(
          const DocumentLibraryFilter(query: 'Taraka Rao'),
        ),
        hasLength(1),
      );
      await library.replaceTags('document-1', <String>['Identity', 'Travel']);
      expect(
        await library.listDocuments(
          const DocumentLibraryFilter(query: 'identity'),
        ),
        hasLength(1),
      );
      await library.setFavourite('document-1', true);
      final item = (await library.listDocuments(
        const DocumentLibraryFilter(favouritesOnly: true),
      )).single;
      expect(
        item.tags.map((tag) => tag.name),
        containsAll(<String>[
          'Identity',
          'Travel',
        ]),
      );
      final initialTags = await library.listTags();
      final identity = initialTags.singleWhere((tag) => tag.name == 'Identity');
      final travel = initialTags.singleWhere((tag) => tag.name == 'Travel');
      await library.renameTag(identity.id, 'Personal ID');
      expect(
        (await library.document('document-1'))!.summary.tags.map(
          (tag) => tag.name,
        ),
        contains('Personal ID'),
      );
      await library.renameTag(travel.id, 'personal id');
      expect(await library.listTags(), hasLength(1));
      await library.deleteTag((await library.listTags()).single.id);
      expect((await library.document('document-1'))!.summary.tags, isEmpty);
      expect((await library.document('document-1'))!.textPages, hasLength(1));
      await library.rename('document-1', 'Indian Passport.pdf');
      expect(
        (await library.listDocuments(
          const DocumentLibraryFilter(),
        )).single.logicalFilename,
        'Indian Passport.pdf',
      );
      await library.moveToTrash('document-1');
      expect(
        await library.listDocuments(const DocumentLibraryFilter()),
        isEmpty,
      );
      final trashed = await library.listDocuments(
        const DocumentLibraryFilter(deletedOnly: true),
      );
      expect(trashed.single.isDeleted, isTrue);
      await library.restoreFromTrash('document-1');
      expect(
        await library.listDocuments(const DocumentLibraryFilter()),
        hasLength(1),
      );

      const preferences = VaultPreferencesView(
        useGrid: true,
        darkMode: true,
        defaultReminderOffsets: <int>[14, 1],
      );
      await library.savePreferences(preferences);
      final restored = await library.preferences();
      expect(restored.useGrid, isTrue);
      expect(restored.darkMode, isTrue);
      expect(restored.defaultReminderOffsets, <int>[14, 1]);
    },
  );
}

final class _FixedRandom implements CryptographicRandom {
  var _calls = 0;

  @override
  Future<Uint8List> secureBytes(int length) async {
    _calls += 1;
    return Uint8List.fromList(
      List<int>.generate(length, (index) => index + _calls),
    );
  }
}
