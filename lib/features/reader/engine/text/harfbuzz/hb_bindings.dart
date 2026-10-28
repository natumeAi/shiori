part of 'harfbuzz.dart';

final class HarfBuzzBindings {
  factory HarfBuzzBindings({HarfBuzzLibrarySource? source}) {
    _control();
    source ??= Platform.isIOS
        ? HarfBuzzLibrarySource.process()
        : HarfBuzzLibrarySource.windowsHost();
    return HarfBuzzBindings._(source._open(), source.prefix);
  }
  HarfBuzzBindings._(this._library, this.prefix) {
    if (sizeOf<_HbInfo>() != 20 ||
        sizeOf<_HbPosition>() != 20 ||
        sizeOf<_HbFeature>() != 16) {
      throw const HarfBuzzException(HarfBuzzFailure.incompatibleVersion);
    }
    // Resolve eagerly: a partially bound module never allocates native owners.
    for (final name in _required) {
      _address(name);
    }
    final pointer = _address('hb_version_string')
        .cast<NativeFunction<Pointer<Uint8> Function()>>()
        .asFunction<Pointer<Uint8> Function()>()();
    final bytes = <int>[];
    for (var i = 0; i < 64 && pointer[i] != 0; i++) {
      bytes.add(pointer[i]);
    }
    version = utf8.decode(bytes);
    if (version != '14.6.0') {
      throw const HarfBuzzException(HarfBuzzFailure.incompatibleVersion);
    }
    final allocator = Platform.isWindows
        ? DynamicLibrary.open('ucrtbase.dll')
        : DynamicLibrary.process();
    _malloc = allocator
        .lookupFunction<
          Pointer<Void> Function(IntPtr),
          Pointer<Void> Function(int)
        >('malloc');
    _free = allocator.lookupFunction<_DestroyN, _DestroyD>('free');
  }
  final DynamicLibrary _library;
  final String prefix;
  late final String version;
  final _symbols = <String, Pointer<Void>>{};
  late final Pointer<Void> Function(int) _malloc;
  late final _DestroyD _free;
  static const _required = [
    'hb_version_string',
    'hb_blob_create',
    'hb_blob_get_length',
    'hb_blob_destroy',
    'hb_face_create',
    'hb_face_get_upem',
    'hb_face_get_glyph_count',
    'hb_face_destroy',
    'hb_font_create',
    'hb_font_destroy',
    'hb_ot_font_set_funcs',
    'hb_font_set_scale',
    'hb_buffer_create',
    'hb_buffer_destroy',
    'hb_buffer_pre_allocate',
    'hb_buffer_add_utf16',
    'hb_buffer_set_direction',
    'hb_buffer_set_script',
    'hb_buffer_set_language',
    'hb_buffer_set_cluster_level',
    'hb_language_from_string',
    'hb_shape',
    'hb_buffer_allocation_successful',
    'hb_buffer_get_glyph_infos',
    'hb_buffer_get_glyph_positions',
    'hb_draw_funcs_create',
    'hb_draw_funcs_destroy',
    'hb_draw_funcs_set_move_to_func',
    'hb_draw_funcs_set_line_to_func',
    'hb_draw_funcs_set_quadratic_to_func',
    'hb_draw_funcs_set_cubic_to_func',
    'hb_draw_funcs_set_close_path_func',
    'hb_font_draw_glyph',
  ];
  Pointer<Void> _address(String name) => _symbols.putIfAbsent(name, () {
    try {
      return _library.lookup<Void>('$prefix$name');
    } catch (_) {
      throw HarfBuzzException(
        HarfBuzzFailure.missingSymbol,
        symbol: '$prefix$name',
      );
    }
  });
  late final _blobCreate = _address('hb_blob_create')
      .cast<
        NativeFunction<
          Pointer<Void> Function(
            Pointer<Uint8>,
            Uint32,
            Int32,
            Pointer<Void>,
            Pointer<Void>,
          )
        >
      >()
      .asFunction<
        Pointer<Void> Function(
          Pointer<Uint8>,
          int,
          int,
          Pointer<Void>,
          Pointer<Void>,
        )
      >();
  late final _blobLength = _address('hb_blob_get_length')
      .cast<NativeFunction<_GetUintN>>()
      .asFunction<_GetUintD>();
  late final _faceCreate = _address('hb_face_create')
      .cast<NativeFunction<Pointer<Void> Function(Pointer<Void>, Uint32)>>()
      .asFunction<Pointer<Void> Function(Pointer<Void>, int)>();
  late final _upem = _address('hb_face_get_upem')
      .cast<NativeFunction<_GetUintN>>()
      .asFunction<_GetUintD>();
  late final _glyphCount = _address('hb_face_get_glyph_count')
      .cast<NativeFunction<_GetUintN>>()
      .asFunction<_GetUintD>();
  late final _fontCreate = _address('hb_font_create')
      .cast<NativeFunction<_ObjectN>>()
      .asFunction<_ObjectD>();
  late final _fontFuncs = _address('hb_ot_font_set_funcs')
      .cast<NativeFunction<_DestroyN>>()
      .asFunction<_DestroyD>();
  late final _fontScale = _address('hb_font_set_scale')
      .cast<NativeFunction<Void Function(Pointer<Void>, Int32, Int32)>>()
      .asFunction<void Function(Pointer<Void>, int, int)>();
  late final _bufferCreate = _address('hb_buffer_create')
      .cast<NativeFunction<_CreateN>>()
      .asFunction<_CreateD>();
  late final _preAllocate = _address('hb_buffer_pre_allocate')
      .cast<NativeFunction<Int32 Function(Pointer<Void>, Uint32)>>()
      .asFunction<int Function(Pointer<Void>, int)>();
  late final _bufferAdd = _address('hb_buffer_add_utf16')
      .cast<
        NativeFunction<
          Void Function(Pointer<Void>, Pointer<Uint16>, Int32, Uint32, Int32)
        >
      >()
      .asFunction<
        void Function(Pointer<Void>, Pointer<Uint16>, int, int, int)
      >();
  late final _direction = _address('hb_buffer_set_direction')
      .cast<NativeFunction<_SetIntN>>()
      .asFunction<_SetIntD>();
  late final _script = _address('hb_buffer_set_script')
      .cast<NativeFunction<_SetUintN>>()
      .asFunction<_SetUintD>();
  late final _language = _address('hb_buffer_set_language')
      .cast<NativeFunction<_SetObjectN>>()
      .asFunction<_SetObjectD>();
  late final _clusterLevel = _address('hb_buffer_set_cluster_level')
      .cast<NativeFunction<_SetIntN>>()
      .asFunction<_SetIntD>();
  late final _languageFromString = _address('hb_language_from_string')
      .cast<NativeFunction<Pointer<Void> Function(Pointer<Uint8>, Int32)>>()
      .asFunction<Pointer<Void> Function(Pointer<Uint8>, int)>();
  late final _shape = _address('hb_shape')
      .cast<
        NativeFunction<
          Void Function(
            Pointer<Void>,
            Pointer<Void>,
            Pointer<_HbFeature>,
            Uint32,
          )
        >
      >()
      .asFunction<
        void Function(Pointer<Void>, Pointer<Void>, Pointer<_HbFeature>, int)
      >();
  late final _allocationOk = _address('hb_buffer_allocation_successful')
      .cast<NativeFunction<Int32 Function(Pointer<Void>)>>()
      .asFunction<int Function(Pointer<Void>)>();
  late final _infos = _address('hb_buffer_get_glyph_infos')
      .cast<
        NativeFunction<
          Pointer<_HbInfo> Function(Pointer<Void>, Pointer<Uint32>)
        >
      >()
      .asFunction<Pointer<_HbInfo> Function(Pointer<Void>, Pointer<Uint32>)>();
  late final _positions = _address('hb_buffer_get_glyph_positions')
      .cast<
        NativeFunction<
          Pointer<_HbPosition> Function(Pointer<Void>, Pointer<Uint32>)
        >
      >()
      .asFunction<
        Pointer<_HbPosition> Function(Pointer<Void>, Pointer<Uint32>)
      >();
  late final _drawCreate = _address('hb_draw_funcs_create')
      .cast<NativeFunction<_CreateN>>()
      .asFunction<_CreateD>();
  late final _setMove = _address('hb_draw_funcs_set_move_to_func')
      .cast<NativeFunction<_SetPointN>>()
      .asFunction<_SetPointD>();
  late final _setLine = _address('hb_draw_funcs_set_line_to_func')
      .cast<NativeFunction<_SetPointN>>()
      .asFunction<_SetPointD>();
  late final _setQuad = _address('hb_draw_funcs_set_quadratic_to_func')
      .cast<NativeFunction<_SetQuadN>>()
      .asFunction<_SetQuadD>();
  late final _setCubic = _address('hb_draw_funcs_set_cubic_to_func')
      .cast<NativeFunction<_SetCubicN>>()
      .asFunction<_SetCubicD>();
  late final _setClose = _address('hb_draw_funcs_set_close_path_func')
      .cast<NativeFunction<_SetCloseN>>()
      .asFunction<_SetCloseD>();
  late final _drawGlyph = _address('hb_font_draw_glyph')
      .cast<
        NativeFunction<
          Void Function(Pointer<Void>, Uint32, Pointer<Void>, Pointer<Void>)
        >
      >()
      .asFunction<
        void Function(Pointer<Void>, int, Pointer<Void>, Pointer<Void>)
      >();
  void _destroy(String kind, Pointer<Void> value) =>
      _address('hb_${kind}_destroy')
          .cast<NativeFunction<_DestroyN>>()
          .asFunction<_DestroyD>()(value);
}
