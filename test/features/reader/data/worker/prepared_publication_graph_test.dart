import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'import_test_support.dart';

void main() {
  test('PreparedPublication contains only immutable values, with no lazy objects in any field', () async {
    final directory = Directory.systemTemp.createTempSync(
      'shiori-import-graph-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = writeImport(
      directory,
      importEntries(
        layout: 'pre-paginated',
        sources: [
          sourcePage(body: complexFixedBody, head: viewportHead),
          sourcePage(),
        ],
      ),
    );
    // Mirrors are available in the standalone Dart VM, not Flutter's runtime.
    // Keep its source as data so Flutter's SDK analyzer does not compile it.
    final script = File('${directory.path}/audit.dart')
      ..writeAsStringSync(
        File(
          'test/features/reader/data/worker/prepared_publication_transfer_probe.dart.txt',
        ).readAsStringSync(),
      );
    final result = await Process.run(Platform.isWindows ? 'dart.bat' : 'dart', [
      '--packages=${File('.dart_tool/package_config.json').absolute.path}',
      script.path,
      file.path,
    ], runInShell: Platform.isWindows);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(
      result.stdout,
      contains('immutable fields audited; lazy book/archive refused'),
    );
    expect(file.existsSync(), isFalse);
  });
}
