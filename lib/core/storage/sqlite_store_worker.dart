part of 'sqlite_store.dart';

void _runStore(_Bootstrap bootstrap) {
  Database? db;
  final requests = ReceivePort();
  try {
    if (Isolate.current.controlPort == bootstrap.root) {
      throw const StorageException(StorageFailure.protocol);
    }
    db = _openDatabase(bootstrap.path, bootstrap.hooks);
  } catch (error) {
    requests.close();
    bootstrap.replies.send(
      _OpenFailed(
        error is StorageException
            ? error
            : const StorageException(StorageFailure.open),
      ),
    );
    return;
  }
  final connection = db;
  bootstrap.replies.send(_Ready(requests.sendPort));
  // Each event executes synchronously to completion. There are no async SQL
  // callbacks that could interleave transactions or pass a connection outside.
  requests.listen((Object? message) {
    if (message is! _Request) return;
    final operation = message.operation;
    try {
      if (Isolate.current.controlPort == bootstrap.root) {
        throw const StorageException(StorageFailure.protocol);
      }
      if (operation is _Close || operation is _ExitForTesting) {
        StorageException? failure;
        try {
          connection.close();
        } catch (_) {
          failure = const StorageException(StorageFailure.command);
        }
        requests.close();
        if (operation is _Close) {
          bootstrap.replies.send(_Reply(message.id, null, failure));
        } else {
          // Exercise onError followed by onExit without exposing a native
          // handle or leaving a test database locked on Windows.
          scheduleMicrotask(
            () => throw const StorageException(StorageFailure.workerExit),
          );
          return;
        }
        Isolate.exit();
      }
      final value = _dispatch(connection, operation, bootstrap.hooks);
      bootstrap.replies.send(_Reply(message.id, value));
    } catch (error) {
      bootstrap.replies.send(
        _Reply(
          message.id,
          null,
          error is StorageException
              ? error
              : const StorageException(StorageFailure.command),
        ),
      );
    }
  });
}
