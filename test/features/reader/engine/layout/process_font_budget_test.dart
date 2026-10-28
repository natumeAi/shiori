import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';

void main() {
  test(
    'concurrent books share reservation and permanent registration',
    () async {
      final budget = ProcessFontBudget(maxBytes: 3, maxFaces: 1);
      final native = Completer<void>();
      var calls = 0;
      Future<void> register(Uint8List bytes, String alias) {
        calls++;
        expect(budget.pendingBytes, 3);
        expect(budget.pendingFaces, 1);
        return native.future;
      }

      final first = budget.load(
        _bytes(1),
        face: '0/400/normal',
        register: register,
      );
      final second = budget.load(
        _bytes(1),
        face: '0/400/normal',
        register: register,
      );
      expect(identical(first, second), isTrue);
      expect(calls, 1);
      expect(
        () => budget.load(_bytes(2), face: '0/400/normal', register: register),
        throwsA(_exhausted),
      );
      native.complete();
      expect(await first, await second);
      expect(budget.pendingBytes, 0);
      expect(budget.registeredBytes, 3);
      expect(budget.registeredFaces, 1);
      expect(budget.bytes, 3);
      expect(budget.peakBytes, 3);
      expect(budget.peakFaces, 1);
      expect(
        await budget.load(_bytes(1), face: '0/400/normal', register: register),
        await first,
      );
      expect(calls, 1);
    },
  );
  test('different bytes or face descriptor get distinct identities', () async {
    final budget = ProcessFontBudget(maxBytes: 9, maxFaces: 3);
    final aliases = <String>{};
    Future<void> register(Uint8List bytes, String alias) async {
      aliases.add(alias);
    }

    await budget.load(_bytes(1), face: '0/400/normal', register: register);
    await budget.load(_bytes(1), face: '1/400/normal', register: register);
    await budget.load(_bytes(2), face: '0/400/normal', register: register);
    expect(aliases, hasLength(3));
    expect(budget.registeredBytes, 9);
    expect(budget.registeredFaces, 3);
  });
  test(
    'pending different faces consume admission before native work',
    () async {
      final budget = ProcessFontBudget(maxBytes: 6, maxFaces: 2);
      final native = Completer<void>();
      var calls = 0;
      Future<void> register(Uint8List bytes, String alias) {
        calls++;
        return native.future;
      }

      final first = budget.load(_bytes(1), face: 'a', register: register);
      final second = budget.load(_bytes(2), face: 'a', register: register);
      expect(
        () => budget.load(_bytes(3), face: 'a', register: register),
        throwsA(_exhausted),
      );
      expect(calls, 2);
      expect(budget.pendingBytes, 6);
      native.complete();
      await Future.wait([first, second]);
      expect(budget.registeredBytes, 6);
      expect(budget.pendingFaces, 0);
    },
  );
  test('byte and face bounds independently refuse native work', () async {
    var calls = 0;
    Future<void> register(Uint8List bytes, String alias) async {
      calls++;
    }

    final bytes = ProcessFontBudget(maxBytes: 5, maxFaces: 10);
    await bytes.load(_bytes(1), face: 'a', register: register);
    expect(
      () => bytes.load(_bytes(2), face: 'a', register: register),
      throwsA(_exhausted),
    );
    final faces = ProcessFontBudget(maxBytes: 100, maxFaces: 1);
    await faces.load(_bytes(1), face: 'a', register: register);
    expect(
      () => faces.load(_bytes(2), face: 'a', register: register),
      throwsA(_exhausted),
    );
    expect(calls, 2);
    expect(bytes.bytes, 3);
    expect(faces.faces, 1);
  });
  test(
    'confirmed rejection releases one shared reservation and permits retry',
    () async {
      final budget = ProcessFontBudget(maxBytes: 3, maxFaces: 1);
      final native = Completer<void>();
      var calls = 0;
      Future<void> register(Uint8List bytes, String alias) {
        calls++;
        return native.future;
      }

      final first = budget.load(_bytes(1), face: 'a', register: register);
      final second = budget.load(_bytes(1), face: 'a', register: register);
      final failures = [
        expectLater(first, throwsA(isA<ProcessFontRegistrationRejected>())),
        expectLater(second, throwsA(isA<ProcessFontRegistrationRejected>())),
      ];
      native.completeError(const ProcessFontRegistrationRejected());
      await Future.wait(failures);
      expect(calls, 1);
      expect(budget.bytes, 0);
      expect(budget.faces, 0);
      expect(budget.pendingBytes, 0);
      expect(budget.uncertainBytes, 0);
      await budget.load(
        _bytes(1),
        face: 'a',
        register: (_, _) async {
          calls++;
        },
      );
      expect(calls, 2);
      expect(budget.bytes, 3);
    },
  );
  test(
    'uncertain native failure stays charged and retry cannot unload it',
    () async {
      final budget = ProcessFontBudget(maxBytes: 3, maxFaces: 1);
      var calls = 0;
      Future<void> register(Uint8List bytes, String alias) {
        calls++;
        throw StateError('unknown native state');
      }

      await expectLater(
        budget.load(_bytes(1), face: 'a', register: register),
        throwsStateError,
      );
      await expectLater(
        budget.load(_bytes(1), face: 'a', register: register),
        throwsStateError,
      );
      expect(calls, 1);
      expect(budget.pendingBytes, 0);
      expect(budget.registeredBytes, 0);
      expect(budget.uncertainBytes, 3);
      expect(budget.uncertainFaces, 1);
      expect(
        () => budget.load(_bytes(2), face: 'a', register: register),
        throwsA(_exhausted),
      );
    },
  );
  test('cancel before admission starts no registration', () {
    final budget = ProcessFontBudget();
    final cancel = PublicationCancellation()..cancel();
    expect(
      () => budget.load(
        _bytes(1),
        face: 'a',
        cancellation: cancel,
        register: (_, _) async {
          fail('must not register');
        },
      ),
      throwsA(isA<ProcessFontLoadCanceled>()),
    );
    expect(budget.bytes, 0);
    expect(budget.faces, 0);
  });
  test(
    'cancel one waiter preserves registration for the continuing book',
    () async {
      final budget = ProcessFontBudget(maxBytes: 3, maxFaces: 1);
      final native = Completer<void>();
      final cancel = PublicationCancellation();
      var calls = 0;
      Future<void> register(Uint8List bytes, String alias) {
        calls++;
        return native.future;
      }

      final departed = budget.load(
        _bytes(1),
        face: 'a',
        cancellation: cancel,
        register: register,
      );
      final continuing = budget.load(_bytes(1), face: 'a', register: register);
      final failure = expectLater(
        departed,
        throwsA(isA<ProcessFontLoadCanceled>()),
      );
      cancel.cancel();
      cancel.cancel();
      await failure;
      expect(budget.pendingBytes, 3);
      expect(
        () => budget.load(_bytes(2), face: 'a', register: register),
        throwsA(_exhausted),
      );
      native.complete();
      await continuing;
      expect(budget.registeredBytes, 3);
      expect(budget.pendingBytes, 0);
      expect(calls, 1);
      expect(budget.bytes, 3);
    },
  );
  test(
    'all departed waiters drain rejection and release without unhandled error',
    () async {
      final budget = ProcessFontBudget();
      final native = Completer<void>();
      final cancel = PublicationCancellation();
      final departed = budget.load(
        _bytes(1),
        face: 'a',
        cancellation: cancel,
        register: (_, _) => native.future,
      );
      final failure = expectLater(
        departed,
        throwsA(isA<ProcessFontLoadCanceled>()),
      );
      cancel.cancel();
      await failure;
      expect(budget.pendingBytes, 3);
      native.completeError(const ProcessFontRegistrationRejected());
      await Future<void>.delayed(Duration.zero);
      expect(budget.bytes, 0);
      expect(budget.pendingFaces, 0);
    },
  );
  test('invalid input and motion callback cannot start native work', () {
    expect(() => ProcessFontBudget(maxBytes: 0), throwsArgumentError);
    expect(() => ProcessFontBudget(maxFaces: 0), throwsArgumentError);
    final budget = ProcessFontBudget();
    Future<void> register(Uint8List bytes, String alias) async {
      fail('must not register');
    }

    expect(
      () => budget.load(Uint8List(0), face: 'a', register: register),
      throwsArgumentError,
    );
    expect(
      () => budget.load(_bytes(1), face: ' ', register: register),
      throwsArgumentError,
    );
    expect(
      () => ReaderWorkGuard.callback(
        () => budget.load(_bytes(1), face: 'a', register: register),
      ),
      throwsAssertionError,
    );
    expect(budget.bytes, 0);
  });
}

Uint8List _bytes(int seed) => Uint8List.fromList([seed, 2, 3]);
Matcher get _exhausted => isA<SceneAdmissionException>().having(
  (e) => e.failure,
  'failure',
  SceneAdmissionFailure.processFontExhausted,
);
