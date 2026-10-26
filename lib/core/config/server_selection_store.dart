import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/config/stored_server.dart';
import 'package:shiori/core/config/validated_snapshot.dart';

/// Small persistence port; implementations map failures to
/// SelectionStorageException. There is deliberately no server-delete command.
abstract interface class ServerSelectionStore {
  Future<StoredServer?> readServer(ServerKey key);
  Future<ServerKey?> readActiveServer();

  /// Atomically upsert endpoint + snapshot + active key. Preserve creation
  /// time on reactivation, update last-use time, and roll back all on failure.
  /// Once dispatched, this transaction is not cancelable.
  Future<void> commitActivation({
    required ServerEndpoint endpoint,
    required ServerKey key,
    required ValidatedSnapshot snapshot,
  });

  Future<ValidatedSnapshot?> readCurrentSnapshot(ServerKey key);
  Future<void> touchLastUsed(ServerKey key);
}
