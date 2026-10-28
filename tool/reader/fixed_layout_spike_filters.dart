// A0 experiment; run through the focused Flutter test on the host engine.
import 'dart:ui' as ui;

import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';

/// Executes the fixture's ordered graph using bounded native offscreen images.
/// The caller owns every allocation through [images], including intermediates.
Future<ui.Image> renderSpikeFilter(
  SourceDocument document,
  List<ui.Image> images,
  List<Map<String, Object?>> stages,
) async {
  final filter = document.nodes.firstWhere((n) => n.localName == 'filter');
  final source = document.getElementById('source')!;
  final region = ui.Rect.fromLTWH(
    _number(filter, 'x'),
    _number(filter, 'y'),
    _number(filter, 'width'),
    _number(filter, 'height'),
  );
  if (region != const ui.Rect.fromLTWH(0, 0, 320, 240) ||
      filter.attribute('filterUnits') != 'userSpaceOnUse') {
    throw const FormatException('Spike requires pinned finite region');
  }
  final linear = filter.attribute('color-interpolation-filters') == 'linearRGB';
  final results = <String, ui.Image>{};
  Future<ui.Image> image(void Function(ui.Canvas) paint) async {
    if (images.length >= 32) {
      throw StateError('Spike image admission exhausted');
    }
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, region)..clipRect(region);
    paint(canvas);
    final picture = recorder.endRecording();
    try {
      final value = await picture.toImage(320, 240);
      images.add(value);
      return value;
    } finally {
      picture.dispose();
    }
  }

  Future<ui.Image> convert(ui.Image input, ui.ColorFilter conversion) => image(
    (c) => c.drawImage(
      input,
      ui.Offset.zero,
      ui.Paint()..colorFilter = conversion,
    ),
  );
  var original = await image(
    (c) => c.drawRect(
      ui.Rect.fromLTWH(
        _number(source, 'x'),
        _number(source, 'y'),
        _number(source, 'width'),
        _number(source, 'height'),
      ),
      ui.Paint()..color = const ui.Color(0xffff0000),
    ),
  );
  if (linear) {
    original = await convert(
      original,
      const ui.ColorFilter.srgbToLinearGamma(),
    );
  }
  results['SourceGraphic'] = original;
  var previous = original;
  for (final index in filter.children) {
    final node = document.node(index);
    if (node.kind != SourceNodeKind.element) continue;
    final input = results[node.attribute('in')] ?? previous;
    final input2 = results[node.attribute('in2')] ?? original;
    final output = await image((canvas) {
      switch (node.localName) {
        case 'feGaussianBlur':
          final sigma = _number(node, 'stdDeviation');
          canvas.saveLayer(
            region,
            ui.Paint()
              ..imageFilter = ui.ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: ui.TileMode.decal,
              ),
          );
          canvas.drawImage(input, ui.Offset.zero, ui.Paint());
          canvas.restore();
        case 'feOffset':
          canvas.drawImage(
            input,
            ui.Offset(_number(node, 'dx'), _number(node, 'dy')),
            ui.Paint(),
          );
        case 'feColorMatrix':
          final values = node
              .attribute('values')!
              .trim()
              .split(RegExp(r'\s+'))
              .map(double.parse)
              .toList();
          if (values.length != 20) {
            throw const FormatException('Expected 20 matrix values');
          }
          // SVG offsets use normalized channels; dart:ui offsets use 0..255.
          for (final offset in [4, 9, 14, 19]) {
            values[offset] *= 255;
          }
          canvas.drawImage(
            input,
            ui.Offset.zero,
            ui.Paint()..colorFilter = ui.ColorFilter.matrix(values),
          );
        case 'feFlood':
          canvas.drawRect(
            region,
            ui.Paint()
              ..color = const ui.Color(0xff0000ff)
                  .withValues(alpha: _number(node, 'flood-opacity')),
          );
        case 'feComposite':
          if (node.attribute('operator') != 'in') {
            throw const FormatException('Unprobed composite');
          }
          canvas.drawImage(input2, ui.Offset.zero, ui.Paint());
          canvas.drawImage(
            input,
            ui.Offset.zero,
            ui.Paint()..blendMode = ui.BlendMode.srcIn,
          );
        case 'feBlend':
          if (node.attribute('mode') != 'screen') {
            throw const FormatException('Unprobed blend');
          }
          canvas.drawImage(input2, ui.Offset.zero, ui.Paint());
          canvas.drawImage(
            input,
            ui.Offset.zero,
            ui.Paint()..blendMode = ui.BlendMode.screen,
          );
        case 'feMerge':
          for (final child
              in node.children
                  .map(document.node)
                  .where((n) => n.localName == 'feMergeNode')) {
            final result = results[child.attribute('in')];
            if (result == null) {
              throw const FormatException('Missing merge input');
            }
            canvas.drawImage(result, ui.Offset.zero, ui.Paint());
          }
        default:
          throw FormatException('Unprobed filter primitive: ${node.localName}');
      }
    });
    previous = output;
    final name = node.attribute('result') ?? 'output';
    results[name] = output;
    stages.add({
      'primitive': node.localName,
      'result': name,
      'input': node.attribute('in'),
      'input2': node.attribute('in2'),
      'imageIndex': images.indexOf(output),
      'region': [0, 0, 320, 240],
      'colorSpace': linear ? 'linearRGB-native-gamma-layers' : 'sRGB',
    });
  }
  return linear
      ? convert(previous, const ui.ColorFilter.linearToSrgbGamma())
      : previous;
}

double _number(SourceNode node, String name) =>
    double.parse(node.attribute(name)!);
