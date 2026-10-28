part of 'harfbuzz.dart';

final class _HbFeature extends Struct {
  @Uint32()
  external int tag;
  @Uint32()
  external int value;
  @Uint32()
  external int start;
  @Uint32()
  external int end;
}

final class _HbInfo extends Struct {
  @Uint32()
  external int codepoint;
  @Uint32()
  external int mask;
  @Uint32()
  external int cluster;
  @Uint32()
  external int var1;
  @Uint32()
  external int var2;
}

final class _HbPosition extends Struct {
  @Int32()
  external int xAdvance;
  @Int32()
  external int yAdvance;
  @Int32()
  external int xOffset;
  @Int32()
  external int yOffset;
  @Uint32()
  external int reserved;
}

typedef _DestroyN = Void Function(Pointer<Void>);
typedef _DestroyD = void Function(Pointer<Void>);
typedef _CreateN = Pointer<Void> Function();
typedef _CreateD = Pointer<Void> Function();
typedef _ObjectN = Pointer<Void> Function(Pointer<Void>);
typedef _ObjectD = Pointer<Void> Function(Pointer<Void>);
typedef _SetIntN = Void Function(Pointer<Void>, Int32);
typedef _SetIntD = void Function(Pointer<Void>, int);
typedef _SetUintN = Void Function(Pointer<Void>, Uint32);
typedef _SetUintD = void Function(Pointer<Void>, int);
typedef _GetUintN = Uint32 Function(Pointer<Void>);
typedef _GetUintD = int Function(Pointer<Void>);
typedef _SetObjectN = Void Function(Pointer<Void>, Pointer<Void>);
typedef _SetObjectD = void Function(Pointer<Void>, Pointer<Void>);

typedef _Point = Void Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
  Float,
  Float,
  Pointer<Void>,
);
typedef _Quad = Void Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
  Float,
  Float,
  Float,
  Float,
  Pointer<Void>,
);
typedef _Cubic = Void Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
  Float,
  Float,
  Float,
  Float,
  Float,
  Float,
  Pointer<Void>,
);
typedef _Close = Void Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
);
typedef _SetPointN = Void Function(
  Pointer<Void>,
  Pointer<NativeFunction<_Point>>,
  Pointer<Void>,
  Pointer<Void>,
);
typedef _SetPointD = void Function(
  Pointer<Void>,
  Pointer<NativeFunction<_Point>>,
  Pointer<Void>,
  Pointer<Void>,
);
typedef _SetQuadN = Void Function(
  Pointer<Void>,
  Pointer<NativeFunction<_Quad>>,
  Pointer<Void>,
  Pointer<Void>,
);
typedef _SetQuadD = void Function(
  Pointer<Void>,
  Pointer<NativeFunction<_Quad>>,
  Pointer<Void>,
  Pointer<Void>,
);
typedef _SetCubicN = Void Function(
  Pointer<Void>,
  Pointer<NativeFunction<_Cubic>>,
  Pointer<Void>,
  Pointer<Void>,
);
typedef _SetCubicD = void Function(
  Pointer<Void>,
  Pointer<NativeFunction<_Cubic>>,
  Pointer<Void>,
  Pointer<Void>,
);
typedef _SetCloseN = Void Function(
  Pointer<Void>,
  Pointer<NativeFunction<_Close>>,
  Pointer<Void>,
  Pointer<Void>,
);
typedef _SetCloseD = void Function(
  Pointer<Void>,
  Pointer<NativeFunction<_Close>>,
  Pointer<Void>,
  Pointer<Void>,
);
