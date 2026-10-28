// Hand-written, x64 C ABI subset. No ffigen, libclang or new dependency.
import 'dart:ffi';
import 'dart:io';

const harfBuzzProbeDirectory =
    'build/third_party/harfbuzz-14.6.0/extracted/harfbuzz-win64';
const harfBuzzProbeLibrary = '$harfBuzzProbeDirectory/libharfbuzz-0.dll';

// Pinned MinGW import chain: HB -> GLib -> intl -> Windows system DLLs.
// Retain module owners for the process, just like DynamicLibrary.open(HB).
final _dependencyModules = <DynamicLibrary>[];
DynamicLibrary _openHarfBuzz() {
  for (final name in [
    'libintl-8.dll',
    'libglib-2.0-0.dll',
  ].skip(_dependencyModules.length)) {
    _dependencyModules.add(
      DynamicLibrary.open(File('$harfBuzzProbeDirectory/$name').absolute.path),
    );
  }
  return DynamicLibrary.open(File(harfBuzzProbeLibrary).absolute.path);
}

final class HbFeature extends Struct {
  @Uint32()
  external int tag;
  @Uint32()
  external int value;
  @Uint32()
  external int start;
  @Uint32()
  external int end;
}

final class HbInfo extends Struct {
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

final class HbPosition extends Struct {
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

typedef HbPoint = Void Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
  Float,
  Float,
  Pointer<Void>,
);
typedef HbQuad = Void Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
  Float,
  Float,
  Float,
  Float,
  Pointer<Void>,
);
typedef HbCubic = Void Function(
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
typedef HbClose = Void Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
);
typedef HbSetPoint = Void Function(
  Pointer<Void>,
  Pointer<NativeFunction<HbPoint>>,
  Pointer<Void>,
  Pointer<Void>,
);
typedef HbSetQuad = Void Function(
  Pointer<Void>,
  Pointer<NativeFunction<HbQuad>>,
  Pointer<Void>,
  Pointer<Void>,
);
typedef HbSetCubic = Void Function(
  Pointer<Void>,
  Pointer<NativeFunction<HbCubic>>,
  Pointer<Void>,
  Pointer<Void>,
);
typedef HbSetClose = Void Function(
  Pointer<Void>,
  Pointer<NativeFunction<HbClose>>,
  Pointer<Void>,
  Pointer<Void>,
);
typedef HbDestroy = Void Function(Pointer<Void>);

bool sizeOfHbMismatch() =>
    sizeOf<HbInfo>() != 20 ||
    sizeOf<HbPosition>() != 20 ||
    sizeOf<HbFeature>() != 16;

final class HbApi {
  HbApi() : library = _openHarfBuzz();
  final DynamicLibrary library;
  final _crt = DynamicLibrary.open('ucrtbase.dll');
  late final malloc = _crt
      .lookupFunction<
        Pointer<Void> Function(IntPtr),
        Pointer<Void> Function(int)
      >('malloc');
  late final free = _crt
      .lookupFunction<HbDestroy, void Function(Pointer<Void>)>('free');
  late final version = library
      .lookupFunction<Pointer<Uint8> Function(), Pointer<Uint8> Function()>(
        'hb_version_string',
      );
  late final blobCreate = library
      .lookupFunction<
        Pointer<Void> Function(
          Pointer<Uint8>,
          Uint32,
          Int32,
          Pointer<Void>,
          Pointer<Void>,
        ),
        Pointer<Void> Function(
          Pointer<Uint8>,
          int,
          int,
          Pointer<Void>,
          Pointer<Void>,
        )
      >('hb_blob_create');
  late final faceCreate = library
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Uint32),
        Pointer<Void> Function(Pointer<Void>, int)
      >('hb_face_create');
  late final faceUpem = library
      .lookupFunction<
        Uint32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('hb_face_get_upem');
  late final fontCreate = library
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)
      >('hb_font_create');
  late final fontFuncs = library
      .lookupFunction<HbDestroy, void Function(Pointer<Void>)>(
        'hb_ot_font_set_funcs',
      );
  late final fontScale = library
      .lookupFunction<
        Void Function(Pointer<Void>, Int32, Int32),
        void Function(Pointer<Void>, int, int)
      >('hb_font_set_scale');
  late final bufferCreate = library
      .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
        'hb_buffer_create',
      );
  late final bufferAdd = library
      .lookupFunction<
        Void Function(Pointer<Void>, Pointer<Uint16>, Int32, Uint32, Int32),
        void Function(Pointer<Void>, Pointer<Uint16>, int, int, int)
      >('hb_buffer_add_utf16');
  late final direction = library
      .lookupFunction<
        Void Function(Pointer<Void>, Int32),
        void Function(Pointer<Void>, int)
      >('hb_buffer_set_direction');
  late final script = library
      .lookupFunction<
        Void Function(Pointer<Void>, Uint32),
        void Function(Pointer<Void>, int)
      >('hb_buffer_set_script');
  late final languageFromString = library
      .lookupFunction<
        Pointer<Void> Function(Pointer<Uint8>, Int32),
        Pointer<Void> Function(Pointer<Uint8>, int)
      >('hb_language_from_string');
  late final language = library
      .lookupFunction<
        Void Function(Pointer<Void>, Pointer<Void>),
        void Function(Pointer<Void>, Pointer<Void>)
      >('hb_buffer_set_language');
  late final clusterLevel = library
      .lookupFunction<
        Void Function(Pointer<Void>, Int32),
        void Function(Pointer<Void>, int)
      >('hb_buffer_set_cluster_level');
  late final shape = library
      .lookupFunction<
        Void Function(Pointer<Void>, Pointer<Void>, Pointer<Void>, Uint32),
        void Function(Pointer<Void>, Pointer<Void>, Pointer<Void>, int)
      >('hb_shape');
  late final allocationSuccessful = library
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('hb_buffer_allocation_successful');
  late final infos = library
      .lookupFunction<
        Pointer<HbInfo> Function(Pointer<Void>, Pointer<Uint32>),
        Pointer<HbInfo> Function(Pointer<Void>, Pointer<Uint32>)
      >('hb_buffer_get_glyph_infos');
  late final positions = library
      .lookupFunction<
        Pointer<HbPosition> Function(Pointer<Void>, Pointer<Uint32>),
        Pointer<HbPosition> Function(Pointer<Void>, Pointer<Uint32>)
      >('hb_buffer_get_glyph_positions');
  late final drawCreate = library
      .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
        'hb_draw_funcs_create',
      );
  late final setMove = library
      .lookupFunction<
        HbSetPoint,
        void Function(
          Pointer<Void>,
          Pointer<NativeFunction<HbPoint>>,
          Pointer<Void>,
          Pointer<Void>,
        )
      >('hb_draw_funcs_set_move_to_func');
  late final setLine = library
      .lookupFunction<
        HbSetPoint,
        void Function(
          Pointer<Void>,
          Pointer<NativeFunction<HbPoint>>,
          Pointer<Void>,
          Pointer<Void>,
        )
      >('hb_draw_funcs_set_line_to_func');
  late final setQuad = library
      .lookupFunction<
        HbSetQuad,
        void Function(
          Pointer<Void>,
          Pointer<NativeFunction<HbQuad>>,
          Pointer<Void>,
          Pointer<Void>,
        )
      >('hb_draw_funcs_set_quadratic_to_func');
  late final setCubic = library
      .lookupFunction<
        HbSetCubic,
        void Function(
          Pointer<Void>,
          Pointer<NativeFunction<HbCubic>>,
          Pointer<Void>,
          Pointer<Void>,
        )
      >('hb_draw_funcs_set_cubic_to_func');
  late final setClose = library
      .lookupFunction<
        HbSetClose,
        void Function(
          Pointer<Void>,
          Pointer<NativeFunction<HbClose>>,
          Pointer<Void>,
          Pointer<Void>,
        )
      >('hb_draw_funcs_set_close_path_func');
  late final drawGlyph = library
      .lookupFunction<
        Void Function(Pointer<Void>, Uint32, Pointer<Void>, Pointer<Void>),
        void Function(Pointer<Void>, int, Pointer<Void>, Pointer<Void>)
      >('hb_font_draw_glyph');

  void destroy(String kind, Pointer<Void> object) =>
      library.lookupFunction<HbDestroy, void Function(Pointer<Void>)>(
        'hb_${kind}_destroy',
      )(object);
}

/// Counts explicit handles and payload, not allocator metadata or opaque HB caches.
final class HbLedger {
  final live = <String, int>{},
      peaks = <String, int>{},
      created = <String, int>{};
  final bytes = <String, int>{}, bytePeaks = <String, int>{};
  void take(String kind, [int payload = 0]) {
    live[kind] = (live[kind] ?? 0) + 1;
    created[kind] = (created[kind] ?? 0) + 1;
    if (live[kind]! > (peaks[kind] ?? 0)) peaks[kind] = live[kind]!;
    bytes[kind] = (bytes[kind] ?? 0) + payload;
    if (bytes[kind]! > (bytePeaks[kind] ?? 0)) bytePeaks[kind] = bytes[kind]!;
  }

  void release(String kind, [int payload = 0]) {
    if ((live[kind] ?? 0) <= 0 || (bytes[kind] ?? 0) < payload) {
      throw StateError('Unbalanced $kind');
    }
    live[kind] = live[kind]! - 1;
    bytes[kind] = (bytes[kind] ?? 0) - payload;
  }

  Map<String, Object?> snapshot() => {
    'created': Map.of(created),
    'live': Map.of(live),
    'peakCounts': Map.of(peaks),
    'livePayloadBytes': Map.of(bytes),
    'peakPayloadBytes': Map.of(bytePeaks),
    'opaqueNativeBytes':
        'unmeasured: HB caches/capacity, Path, Paragraph, GPU, VM, DLLs',
  };
}
