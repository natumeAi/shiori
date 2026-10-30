import 'dart:async';
import 'dart:collection';

import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';

/// A pending delivery's eviction pin. Release after use or after installing a
/// surface pin; each request owns its own lease, including coalesced requests.
final class ReflowSectionLease {
  ReflowSectionLease._(this.section, this._release);
  final PreparedSection section;
  void Function()? _release;
  void release() {
    final release = _release;
    _release = null;
    release?.call();
  }
}

/// Shared retained-section owner for reflow and mixed publications. Composition
/// keeps only pagination metadata; all live paragraphs remain charged here.
final class ReflowSectionCache {
  ReflowSectionCache({required this.prepare, required this.budget});
  static const capacity = 4;
  final Future<PreparedSection?> Function(int) prepare;
  final SceneResourceBudget budget;
  bool Function(PreparedSection)? pinned;
  final _sections = <int, PreparedSection>{};
  final _charges = <int, SceneResourceLease>{};
  final _pending = <int, Future<PreparedSection?>>{};
  final _deliveryPins = <int, int>{};
  Future<void> _tail = Future.value();
  bool _closed = false;
  Map<int, PreparedSection> get sections => UnmodifiableMapView(_sections);

  /// Compatibility delivery: synchronous completion lets an awaiting borrower
  /// install its surface pin before this delivery's lease is released. Use
  /// [borrow] when ownership must span another asynchronous operation.
  Future<PreparedSection?> load(int index) {
    final borrowed = borrow(index);
    final delivery = Completer<PreparedSection?>.sync();
    unawaited(
      borrowed.then<void>((lease) {
        try {
          delivery.complete(_closed ? null : lease?.section);
        } finally {
          lease?.release();
        }
      }, onError: delivery.completeError),
    );
    return delivery.future;
  }

  /// Protect the requested slot synchronously, before any queued miss can run.
  Future<ReflowSectionLease?> borrow(int index) {
    if (_closed) return Future.value(null);
    _deliveryPins.update(index, (n) => n + 1, ifAbsent: () => 1);
    var released = false;
    void release() {
      if (released) return;
      released = true;
      final count = _deliveryPins[index]!;
      if (count == 1) {
        _deliveryPins.remove(index);
      } else {
        _deliveryPins[index] = count - 1;
      }
    }

    final cached = _sections.remove(index);
    final Future<PreparedSection?> work;
    if (cached != null) {
      _sections[index] = cached;
      work = Future.value(cached);
    } else {
      work = _pending.putIfAbsent(index, () {
        final work = _tail.then((_) => _load(index));
        _tail = work.then<void>(
          (_) => Future<void>.delayed(Duration.zero),
          onError: (Object _, StackTrace _) {},
        );
        return work.whenComplete(() {
          _pending.remove(index);
        });
      });
    }
    return work.then(
      (section) {
        if (_closed || section == null) {
          release();
          return null;
        }
        return ReflowSectionLease._(section, release);
      },
      onError: (Object error, StackTrace stack) {
        release();
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  Future<PreparedSection?> _load(int index) async {
    if (_closed) return null;
    // Make room before preparing another section, including the incoming one.
    if (_sections.length == capacity) {
      final candidates = _sections.entries.where(
        (entry) =>
            !_deliveryPins.containsKey(entry.key) &&
            !(pinned?.call(entry.value) ?? false),
      );
      if (candidates.isEmpty) {
        throw const SceneAdmissionException(
          SceneAdmissionFailure.resourceExhausted,
          resource: SceneResource.paragraphs,
        );
      }
      _evict(candidates.first.key);
    }
    final section = await prepare(index);
    if (section == null) return null;
    if (_closed) {
      section.dispose();
      return null;
    }
    try {
      final paragraphs = section.blocks
          .where((b) => b.paragraph != null)
          .length;
      final text = section.model.blocks.whereType<TextBlock>().fold<int>(
        0,
        (sum, block) => sum + block.text.length,
      );
      // Retained source/model storage and native paragraph payload are charged
      // independently of pictures and unit/source-slot reservations in the pool.
      final charge = budget.reserve({
        SceneResource.sourceNodes: section.document.nodes.length,
        SceneResource.sourceBytes:
            section.document.nodes.length * 256 + text * 2,
        SceneResource.paragraphs: paragraphs,
        SceneResource.textCodeUnits: text,
      });
      _sections[index] = section;
      _charges[index] = charge;
      return section;
    } on Object {
      section.dispose();
      rethrow;
    }
  }

  void _evict(int index) {
    _sections.remove(index)?.dispose();
    _charges.remove(index)?.release();
  }

  Future<void> drain() => _tail;

  /// Call after the borrowing session has drained its surface/section pins.
  /// In-flight loads observe closure and dispose their result before returning.
  void dispose() {
    if (_closed) return;
    _closed = true;
    for (final index in _sections.keys.toList()) {
      _evict(index);
    }
  }
}
