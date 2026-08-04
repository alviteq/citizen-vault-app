import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vault_platform/vault_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native CSPRNG returns distinct 256-bit values', (tester) async {
    const random = PlatformCryptographicRandom();
    final first = await random.secureBytes(32);
    final second = await random.secureBytes(32);

    expect(first, hasLength(32));
    expect(second, hasLength(32));
    expect(first, isNot(equals(second)));
  });
}
