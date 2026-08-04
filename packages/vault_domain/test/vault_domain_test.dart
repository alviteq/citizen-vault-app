import 'package:test/test.dart';
import 'package:vault_domain/vault_domain.dart';

void main() {
  test('declares the milestone eight domain API version', () {
    expect(VaultDomainPackage.apiVersion, '1.0.0');
  });

  test('processing progress reflects durable states', () {
    expect(DocumentProcessingStatus.queued.progress, 0.2);
    expect(DocumentProcessingStatus.processing.progress, 0.6);
    expect(DocumentProcessingStatus.ready.progress, 1);
    expect(DocumentProcessingStatus.failed.isTerminal, isTrue);
  });
}
