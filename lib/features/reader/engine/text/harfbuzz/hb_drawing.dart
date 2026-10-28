part of 'harfbuzz.dart';

final class _HbOutline {
  _HbOutline(ui.Path path, this.operations, this.bytes, this.charge)
    : _path = path;
  ui.Path? _path;
  ui.Path get path =>
      _path ?? (throw const HarfBuzzException(HarfBuzzFailure.disposed));
  final int operations, bytes;
  final _HbCharge charge;
  bool _disposed = false;
  void dispose() {
    _control();
    if (_disposed) return;
    _disposed = true;
    _path
        ?.reset(); // Path has no dispose; backing reclamation remains GC-owned.
    _path = null;
    charge.release();
  }
}

/// Synchronous isolateLocal callbacks. First pass counts complete contours;
/// reserve before Path construction, then emit the identical complete outline.
final class _HbDrawing {
  _HbDrawing(this.api, this.resources, this.factor) {
    funcs = resources._handle(
      'draw_funcs',
      api._drawCreate,
      (p) => api._destroy('draw_funcs', p),
    );
    try {
      _callbacksCharge = resources._reserve('callbacks', {
        SceneResource.sourceNodes: 5,
        SceneResource.sourceBytes: 5 * 256,
      });
      move = NativeCallable<_Point>.isolateLocal((
        Pointer<Void> a,
        Pointer<Void> b,
        Pointer<Void> c,
        double x,
        double y,
        Pointer<Void> d,
      ) {
        _command(2, (p) => p.moveTo(x * factor, -y * factor));
      });
      line = NativeCallable<_Point>.isolateLocal((
        Pointer<Void> a,
        Pointer<Void> b,
        Pointer<Void> c,
        double x,
        double y,
        Pointer<Void> d,
      ) {
        _command(2, (p) => p.lineTo(x * factor, -y * factor));
      });
      quad = NativeCallable<_Quad>.isolateLocal((
        Pointer<Void> a,
        Pointer<Void> b,
        Pointer<Void> c,
        double x1,
        double y1,
        double x2,
        double y2,
        Pointer<Void> d,
      ) {
        _command(
          4,
          (p) => p.quadraticBezierTo(
            x1 * factor,
            -y1 * factor,
            x2 * factor,
            -y2 * factor,
          ),
        );
      });
      cubic = NativeCallable<_Cubic>.isolateLocal((
        Pointer<Void> a,
        Pointer<Void> b,
        Pointer<Void> c,
        double x1,
        double y1,
        double x2,
        double y2,
        double x3,
        double y3,
        Pointer<Void> d,
      ) {
        _command(
          6,
          (p) => p.cubicTo(
            x1 * factor,
            -y1 * factor,
            x2 * factor,
            -y2 * factor,
            x3 * factor,
            -y3 * factor,
          ),
        );
      });
      closePath = NativeCallable<_Close>.isolateLocal((
        Pointer<Void> a,
        Pointer<Void> b,
        Pointer<Void> c,
        Pointer<Void> d,
      ) {
        _command(0, (p) => p.close());
      });
      api._setMove(funcs.pointer, move!.nativeFunction, nullptr, nullptr);
      api._setLine(funcs.pointer, line!.nativeFunction, nullptr, nullptr);
      api._setQuad(funcs.pointer, quad!.nativeFunction, nullptr, nullptr);
      api._setCubic(funcs.pointer, cubic!.nativeFunction, nullptr, nullptr);
      api._setClose(funcs.pointer, closePath!.nativeFunction, nullptr, nullptr);
    } catch (_) {
      dispose();
      rethrow;
    }
  }
  final HarfBuzzBindings api;
  final HarfBuzzResources resources;
  final double factor;
  late final _HbHandle funcs;
  _HbCharge? _callbacksCharge;
  NativeCallable<_Point>? move, line;
  NativeCallable<_Quad>? quad;
  NativeCallable<_Cubic>? cubic;
  NativeCallable<_Close>? closePath;
  ui.Path? _path;
  int _operations = 0, _bytes = 0;
  int _operationLimit = 100000, _byteLimit = 16 * 1024 * 1024;
  Object? _error;
  bool _disposed = false;

  void _command(int coordinates, void Function(ui.Path) emit) {
    if (_error != null) return;
    _operations++;
    _bytes += 1 + coordinates * 8;
    if (_operations > _operationLimit || _bytes > _byteLimit) {
      _error = const SceneAdmissionException(
        SceneAdmissionFailure.complexityExceeded,
      );
      return; // Never throw through C.
    }
    try {
      final path = _path;
      if (path != null) emit(path);
    } catch (error) {
      _error = error;
    }
  }

  _HbOutline outline(Pointer<Void> font, int glyph) {
    _control();
    _operations = _bytes = 0;
    _operationLimit = 100000;
    _byteLimit = 16 * 1024 * 1024;
    _error = null;
    _path = null;
    api._drawGlyph(font, glyph, funcs.pointer, nullptr);
    if (_error case final error?) {
      throw error;
    }
    final operations = _operations, bytes = _bytes;
    final charge = resources._reserve('outline', {
      SceneResource.vectorOperations: operations,
      SceneResource.vectorBytes: bytes,
      SceneResource.sourceNodes: 1,
    });
    ui.Path? path;
    try {
      path = ui.Path();
      _path = path;
      _operations = _bytes = 0;
      _operationLimit = operations;
      _byteLimit = bytes;
      api._drawGlyph(font, glyph, funcs.pointer, nullptr);
      if (_error case final error?) {
        throw error;
      }
      if (_operations != operations || _bytes != bytes) {
        throw const HarfBuzzException(HarfBuzzFailure.invalidShaping);
      }
      return _HbOutline(path, operations, bytes, charge);
    } catch (_) {
      path?.reset();
      charge.release();
      rethrow;
    } finally {
      _path = null;
    }
  }

  void dispose() {
    _control();
    if (_disposed) return;
    _disposed = true;
    funcs.dispose();
    for (final callback in <NativeCallable<Function>?>[
      move,
      line,
      quad,
      cubic,
      closePath,
    ]) {
      callback?.close();
    }
    _callbacksCharge?.release();
  }
}
