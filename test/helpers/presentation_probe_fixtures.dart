import 'package:shiori/features/diagnostics/data/presentation_probe.dart';

Map<String, Object?> presentationPayload(
  PresentationMode mode, {
  String? omission,
  int overflow = 0,
}) => {
  'mode': mode.name,
  'evidence': mode.evidence,
  'available': omission == null,
  'omission': omission,
  'inventory': <String, Object?>{
    'layerClass': mode == PresentationMode.b
        ? 'CAMetalLayer'
        : 'FlutterMetalLayer',
    'FLTUseFlutterMetalLayer': mode == PresentationMode.b ? false : null,
    'maximumFramesPerSecond': 120,
    'lowPowerMode': false,
    'thermalState': 0,
    'iosVersion': '26.0',
    'ringCapacity': 16384,
  },
  'samples': omission != null
      ? <Map<String, Object?>>[]
      : switch (mode) {
          PresentationMode.inventory => <Map<String, Object?>>[],
          PresentationMode.a1 => [
            {'kind': 'layer_commit', 'timestamp': 123.456},
          ],
          PresentationMode.a2 => [
            {'kind': 'layer_commit', 'timestamp': 123.456},
            {
              'kind': 'display_link',
              'timestamp': 123.45,
              'targetTimestamp': 123.458333,
            },
          ],
          PresentationMode.b => [
            {
              'kind': 'drawable',
              'timestamp': 123.456,
              'drawableId': '18446744073709551615',
              'presentedTime': 123.46,
            },
            {
              'kind': 'drawable',
              'timestamp': 123.465,
              'drawableId': '0',
              'presentedTime': 0.0,
            },
          ],
        },
  'overflow': overflow,
  'contentionDrops': overflow > 0 ? 1 : 0,
};
