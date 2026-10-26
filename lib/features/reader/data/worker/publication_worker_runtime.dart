import 'dart:isolate';

import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/epub/epub_loader.dart';
import 'package:shiori/features/reader/data/epub/epub_package.dart';
import 'package:shiori/features/reader/data/worker/publication_snapshot.dart';
import 'package:shiori/features/reader/data/worker/publication_tag.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_protocol.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_test_hooks.dart';

final class PublicationWorkerBootstrap {
  const PublicationWorkerBootstrap(
    this.replies,
    this.rootControl,
    this.limits,
    this.maxResourceBytes,
    this.hooks,
  );
  final SendPort replies;
  final SendPort rootControl;
  final EpubLimits limits;
  final int maxResourceBytes;
  final PublicationWorkerTestHooks? hooks;
}

/// Top-level entry point avoids accidentally capturing root-side state.
Future<void> runPublicationWorker(PublicationWorkerBootstrap bootstrap) async {
  final requests = ReceivePort();
  final owner = _PublicationOwner(bootstrap);
  bootstrap.replies.send(requests.sendPort);
  try {
    await for (final message in requests) {
      if (message is! PublicationRequest) {
        throw const PublicationWorkerException(
          PublicationWorkerFailure.protocol,
        );
      }
      final hooks = bootstrap.hooks;
      if (hooks != null) {
        final gate = hooks.pauseRequests && message is! ClosePublication
            ? ReceivePort()
            : null;
        hooks.events.send(
          PublicationWorkerRequestEvent(
            message,
            gate?.sendPort,
            bootstrap.replies,
            Isolate.current.controlPort,
          ),
        );
        if (gate != null) {
          final action = await gate.first;
          gate.close();
          if (action == PublicationWorkerTestAction.crash) {
            throw const PublicationWorkerException(
              PublicationWorkerFailure.workerError,
            );
          }
        }
      }
      bootstrap.replies.send(owner.execute(message));
      if (message is ClosePublication) break;
    }
  } finally {
    owner.close();
    requests.close();
  }
}

final class _PublicationOwner {
  _PublicationOwner(this.bootstrap);
  final PublicationWorkerBootstrap bootstrap;
  EpubArchive? _archive;
  EpubSectionLoader? _loader;
  PublicationSnapshot? _snapshot;
  PublicationTag? _tag;
  int? _generation;

  void _work(PublicationWorkerWork work) {
    // This check runs in release builds too. Every archive/parser call below
    // is synchronous, so its entire call tree stays on this isolate.
    if (Isolate.current.controlPort == bootstrap.rootControl) {
      throw const PublicationWorkerException(PublicationWorkerFailure.protocol);
    }
    bootstrap.hooks?.events.send(
      PublicationWorkerWorkEvent(work, Isolate.current.controlPort),
    );
  }

  PublicationResponse execute(PublicationRequest request) {
    try {
      return _execute(request);
    } on PublicationWorkerException catch (error) {
      return PublicationFailed(
        request.id,
        request.tag,
        request.generation,
        error,
      );
    } on Object {
      // Never send parser objects, paths, archive handles or private prose as
      // an exception cause. Bad files remain recoverable on the same worker.
      return PublicationFailed(
        request.id,
        request.tag,
        request.generation,
        const ParseException(FormatException('Invalid publication input')),
      );
    }
  }

  PublicationResponse _execute(PublicationRequest request) {
    final id = request.id;
    final tag = request.tag;
    final generation = request.generation;
    if (request is ClosePublication) {
      close();
      return PublicationClosed(id, tag, generation);
    }
    if (request is OpenPublication) {
      close();
      try {
        _work(PublicationWorkerWork.archiveOpen);
        _archive = EpubArchive.openFile(request.path, limits: bootstrap.limits);
        _work(PublicationWorkerWork.packageParse);
        final package = readEpubPackage(_archive!);
        final snapshot = PublicationSnapshot(package);
        if (snapshot.sections.isEmpty) {
          throw const ParseException(FormatException('No readable sections'));
        }
        _loader = EpubSectionLoader(_archive!, package);
        _snapshot = snapshot;
        _tag = tag;
        _generation = generation;
        return PublicationOpened(id, tag, generation, snapshot);
      } on Object {
        close();
        rethrow;
      }
    }
    if (_archive == null || _tag != tag || _generation != generation) {
      throw const PublicationWorkerException(PublicationWorkerFailure.notOpen);
    }
    switch (request) {
      case LoadPublicationSection(:final index):
        _work(PublicationWorkerWork.sectionParse);
        final item = _snapshot!.sections[index].item;
        final document = _loader!.project(item).document;
        return PublicationSectionLoaded(id, tag, generation, document);
      case ReadPublicationResource(:final path):
        _work(PublicationWorkerWork.resourceRead);
        if (_archive!.size(path) > bootstrap.maxResourceBytes) {
          throw const PublicationWorkerException(
            PublicationWorkerFailure.resourceTooLarge,
          );
        }
        final bytes = _archive!.bytes(path);
        if (bytes != null && bytes.length > bootstrap.maxResourceBytes) {
          throw const PublicationWorkerException(
            PublicationWorkerFailure.resourceTooLarge,
          );
        }
        return PublicationResourceRead(
          id,
          tag,
          generation,
          bytes == null ? null : TransferableTypedData.fromList([bytes]),
          bytes?.length ?? 0,
        );
      default:
        throw const PublicationWorkerException(
          PublicationWorkerFailure.protocol,
        );
    }
  }

  void close() {
    if (_archive != null) {
      _work(PublicationWorkerWork.archiveClose);
      _archive!.close();
    }
    _archive = null;
    _loader = null;
    _snapshot = null;
    _tag = null;
    _generation = null;
  }
}
