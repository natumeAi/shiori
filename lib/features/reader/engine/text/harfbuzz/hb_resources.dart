part of 'harfbuzz.dart';

/// Inject the reader's existing shared scene ledger, never a per-book duplicate.
/// Native handles use sourceNodes; malloc/scratch use sourceBytes; outline verbs
/// and double coordinates use vectorOperations/vectorBytes. Opaque HB caches,
/// allocator overhead and actual Path backing/RSS are not measured by this.
final class HarfBuzzResources {
  HarfBuzzResources(this.budget);
  final SceneResourceBudget budget;
  final _live = <String, int>{},
      _created = <String, int>{},
      _destroyed = <String, int>{};
  Map<String, int> get live => Map.unmodifiable(_live);
  Map<String, int> get created => Map.unmodifiable(_created);
  Map<String, int> get destroyed => Map.unmodifiable(_destroyed);

  _HbCharge _reserve(String kind, Map<SceneResource, int> request) {
    _control();
    final lease = budget.reserve(request);
    _live[kind] = (_live[kind] ?? 0) + 1;
    _created[kind] = (_created[kind] ?? 0) + 1;
    return _HbCharge(lease, () {
      _live[kind] = _live[kind]! - 1;
      _destroyed[kind] = (_destroyed[kind] ?? 0) + 1;
    });
  }

  _HbHandle _handle(
    String kind,
    Pointer<Void> Function() create,
    void Function(Pointer<Void>) destroy, {
    int workspaceBytes = 1024,
  }) {
    final charge = _reserve(kind, {
      SceneResource.sourceNodes: 1,
      SceneResource.sourceBytes: workspaceBytes,
    });
    try {
      final pointer = create();
      if (pointer == nullptr) {
        throw const HarfBuzzException(HarfBuzzFailure.allocation);
      }
      return _HbHandle(pointer, destroy, charge);
    } catch (_) {
      charge.release();
      rethrow;
    }
  }

  _HbMemory _allocate(HarfBuzzBindings api, int bytes) {
    final charge = _reserve('malloc', {SceneResource.sourceBytes: bytes});
    try {
      final pointer = api._malloc(bytes);
      if (pointer == nullptr) {
        throw const HarfBuzzException(HarfBuzzFailure.allocation);
      }
      return _HbMemory(pointer, api._free, charge);
    } catch (_) {
      charge.release();
      rethrow;
    }
  }
}

final class _HbCharge {
  _HbCharge(this.lease, this.onRelease);
  final SceneResourceLease lease;
  void Function()? onRelease;
  void release() {
    _control();
    final action = onRelease;
    if (action == null) return;
    onRelease = null;
    lease.release();
    action();
  }
}

final class _HbHandle {
  _HbHandle(this.pointer, this.destroy, this.charge);
  final Pointer<Void> pointer;
  final void Function(Pointer<Void>) destroy;
  final _HbCharge charge;
  bool _disposed = false;
  void dispose() {
    _control();
    if (_disposed) return;
    _disposed = true;
    destroy(pointer);
    charge.release();
  }
}

final class _HbMemory {
  _HbMemory(this.pointer, this.free, this.charge);
  final Pointer<Void> pointer;
  final void Function(Pointer<Void>) free;
  final _HbCharge charge;
  bool _disposed = false;
  void dispose() {
    _control();
    if (_disposed) return;
    _disposed = true;
    free(pointer);
    charge.release();
  }
}
