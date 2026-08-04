import 'package:test/test.dart';
import 'package:vault_ingestion/vault_ingestion.dart';

void main() {
  group('EmergencyStorageManager (Milestone 20 Gate)', () {
    late EmergencyStorageManager manager;

    setUp(() {
      manager = EmergencyStorageManager();
    });

    test('initializes with default minimized medical record', () {
      final env = manager.envelope;
      expect(env.medicalRecord.fullName, 'Taraka Srikakolapu');
      expect(env.medicalRecord.bloodGroup, 'O +ve');
      expect(env.contacts.length, greaterThanOrEqualTo(2));
    });

    test('records emergency access events in access log', () {
      expect(manager.envelope.accessLog, isEmpty);

      manager.recordAccessEvent();

      expect(manager.envelope.accessLog.length, 1);
    });

    test('resets emergency storage cleanly', () {
      manager.recordAccessEvent();
      expect(manager.envelope.accessLog, isNotEmpty);

      manager.resetEmergencyStorage();

      expect(manager.envelope.accessLog, isEmpty);
    });
  });
}
