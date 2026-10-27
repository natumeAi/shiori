import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/pagination/page_plan.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';

/// Deterministic prepared output; excludes elapsed microseconds and native
/// handles. Also used to compare with a pre-seam host capture under build/.
Map<String, Object?> resourceParitySnapshot(PreparedSection section) => {
  'identity': section.identity.key,
  'base': section.sectionBase,
  'fonts': section.fontChains,
  'nodeBlock': section.nodeBlock.map((key, value) => MapEntry('$key', value)),
  'imageBlock': section.imageBlock.map((key, value) => MapEntry('$key', value)),
  'differences': section.model.differences,
  'unsupported': [
    for (final item in section.unsupported)
      [item.code, item.nodeIndex, item.textFlows, item.detail],
  ],
  'costs': [
    for (final cost in section.paragraphCosts) [cost.codeUnits, cost.lines],
  ],
  'blocks': [
    for (final laid in section.blocks)
      {
        'type': laid.block.runtimeType.toString(),
        'geometry': [
          laid.x,
          laid.width,
          laid.height,
          laid.intrinsicWidth,
          laid.intrinsicHeight,
        ],
        'pages': laid.linePage,
        'lines': [
          for (final line in laid.paragraph?.lines ?? [])
            [
              line.start,
              line.end,
              line.top,
              line.bottom,
              line.baseline,
              line.left,
              line.width,
            ],
        ],
        'paragraph': laid.paragraph == null
            ? null
            : [laid.paragraph!.layoutWidth, laid.paragraph!.height],
        if (laid.block case final TextBlock block)
          'map': [
            for (final entry in block.map.entries)
              [
                entry.kind.name,
                entry.paraStart,
                entry.paraEnd,
                entry.nodeIndex,
                entry.sourceStart,
                entry.sourceEnd,
              ],
          ],
        if (laid.block case final ImageBlock block)
          'image': [
            block.kind.name,
            block.resourcePath,
            block.anchorNodeIndex,
            block.hintWidth,
            block.hintHeight,
            block.partialFeatures,
          ],
      },
  ],
  'pages': [
    for (final page in section.pages)
      {
        'index': page.index,
        'identity': page.map.identity,
        'spans': [
          for (final span in page.map.spans)
            [span.nodeIndex, span.start, span.end],
        ],
        'images': page.map.imageNodes,
        'first': page.map.first == null
            ? null
            : [page.map.first!.nodeIndex, page.map.first!.offset],
        'last': page.map.last == null
            ? null
            : [page.map.last!.nodeIndex, page.map.last!.offset],
        'fragments': [
          for (final fragment in page.fragments)
            [
              fragment.blockIndex,
              fragment.top,
              fragment.height,
              ...switch (fragment) {
                TextFragment() => [
                  fragment.firstLine,
                  fragment.endLine,
                  fragment.sliceTop,
                ],
                BoxFragment() => [fragment.left, fragment.width],
              },
            ],
        ],
      },
  ],
};
