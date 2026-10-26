import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/storage/directory_access.dart';

void main() {
  const privatePath = '/private/directory-lookup-sensitive-path';
  test('successful lookup preserves the directory', () async {
    final directory = Directory('synthetic-directory');
    expect(
      await DirectoryAccess.resolve(() async => directory),
      same(directory),
    );
  });

  final failures = <Object>[
    const FileSystemException(
      'Cannot access $privatePath',
      privatePath,
      OSError('Blocked $privatePath', 1),
    ),
    PlatformException(
      code: privatePath,
      message: privatePath,
      details: {'path': privatePath},
      stacktrace: privatePath,
    ),
    MissingPluginException(privatePath),
    MissingPlatformDirectoryException(privatePath),
  ];
  for (final original in failures) {
    for (final asynchronous in [false, true]) {
      test(
        '${original.runtimeType} redacts all fields (async=$asynchronous)',
        () async {
          final records = <LogRecord>[];
          final previousLevel = Logger.root.level;
          Logger.root.level = Level.ALL;
          final subscription = Logger.root.onRecord.listen(records.add);
          addTearDown(() async {
            await subscription.cancel();
            Logger.root.level = previousLevel;
          });
          final syntheticStack = StackTrace.fromString(
            'lookup at $privatePath',
          );
          Future<Directory> lookup() {
            if (asynchronous) return Future.error(original, syntheticStack);
            Error.throwWithStackTrace(original, syntheticStack);
          }

          final filesystem = original is FileSystemException;
          final classification = filesystem
              ? 'directory_filesystem_unavailable'
              : original is MissingPluginException
              ? 'directory_plugin_unavailable'
              : 'directory_platform_unavailable';
          await expectLater(
            DirectoryAccess.resolve(lookup),
            throwsA(
              predicate<Object>((error) {
                expect(error, isNot(same(original)));
                expect(error.toString(), isNot(contains(privatePath)));
                if (filesystem) {
                  expect(error, isA<FileSystemException>());
                  final sanitized = error as FileSystemException;
                  expect(sanitized.message, classification);
                  expect(sanitized.path, isEmpty);
                  expect(sanitized.osError, isNull);
                } else {
                  expect(error, isA<ParseException>());
                  final cause = (error as ParseException).cause;
                  expect(cause, isA<FormatException>());
                  expect(cause.toString(), 'FormatException: $classification');
                  expect(cause, isNot(same(original)));
                }
                return true;
              }),
            ),
          );
          expect(records, hasLength(1));
          final record = records.single;
          expect(record.loggerName, 'DirectoryAccess');
          expect(record.message, classification);
          expect(record.error, isNull);
          expect(record.stackTrace, isNull);
          expect(record.object, isNull);
          for (final field in [
            record.level,
            record.message,
            record.object,
            record.loggerName,
            record.time,
            record.sequenceNumber,
            record.error,
            record.stackTrace,
            record.zone,
            record,
          ]) {
            expect(field.toString(), isNot(contains(privatePath)));
          }
        },
      );
    }
  }
}
