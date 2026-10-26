import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shiori/core/storage/app_directories.dart';

import '../../helpers/probe_storage_fixtures.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'platform directories wire caches to application cache lookup',
    () async {
      final calls = <String>[];
      final paths = {
        'getApplicationSupportDirectory': 'synthetic/support',
        'getApplicationDocumentsDirectory': 'synthetic/documents',
        'getApplicationCacheDirectory': 'synthetic/caches',
      };
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call.method);
        return paths[call.method];
      });
      final container = ProviderContainer.test(retry: (_, _) => null);
      final directories = container.read(appDirectoriesProvider);
      expect((await directories.applicationSupport()).path, paths.values.first);
      expect((await directories.documents()).path, 'synthetic/documents');
      expect((await directories.caches()).path, 'synthetic/caches');
      expect(calls, paths.keys.toList());
    },
  );

  test('missing platform caches is an error rather than a fallback', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => null,
    );
    final container = ProviderContainer.test(retry: (_, _) => null);
    await expectLater(
      container.read(appDirectoriesProvider).caches(),
      throwsA(isA<MissingPlatformDirectoryException>()),
    );
  });

  test(
    'directory fake can override all three locations through provider',
    () async {
      final fake = TestDirectories(Directory('synthetic'));
      final container = ProviderContainer.test(
        overrides: [appDirectoriesProvider.overrideWithValue(fake)],
        retry: (_, _) => null,
      );
      final directories = container.read(appDirectoriesProvider);
      expect(directories, same(fake));
      expect((await directories.caches()).path, 'synthetic/caches');
      expect(
        (await directories.applicationSupport()).path,
        'synthetic/support',
      );
      expect((await directories.documents()).path, 'synthetic/documents');
    },
  );
}
