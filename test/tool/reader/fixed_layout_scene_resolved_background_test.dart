import 'package:flutter_test/flutter_test.dart';

import '../../../tool/reader/fixed_layout_scene_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('scene harness supplies the resolved background archive key', () async {
    final report = await FixedLayoutSceneHarness().run();
    for (final id in ['paint-positive', 'paint-nested']) {
      final c = (report['cases'] as List).cast<Map>().singleWhere(
        (c) => c['id'] == id,
      );
      expect((c['capability'] as Map)['complete'], true, reason: id);
      expect((c['geometry'] as Map)['pass'], true, reason: id);
      expect((c['pixels'] as Map)['pass'], true, reason: id);
    }
  });
}
