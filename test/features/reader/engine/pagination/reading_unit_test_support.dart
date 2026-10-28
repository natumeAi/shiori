import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_section.dart';
import 'package:shiori/features/reader/data/layout/section_rendition.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';

import '../../contract_test_values.dart';
import '../../data/worker/import_test_support.dart';

ReadingUnitSection unitSection(
  int index, {
  String? side,
  String spread = 'auto',
  bool fixed = true,
  bool linear = true,
  int pages = 1,
  double width = 320,
  double height = 240,
  int? spine,
  String? layoutKey,
}) => ReadingUnitSection(
  page: contractPage(section: index, spine: spine, id: 'EPUB/p$index.xhtml'),
  href: 'EPUB/p$index.xhtml',
  rendition: resolveSectionRendition(
    package: {
      'layout': fixed ? 'pre-paginated' : 'reflowable',
      'spread': spread,
      'pageSpread': ?side,
    },
  ),
  layoutKey: layoutKey ?? 'layout-$index',
  linear: linear,
  reflowPageCount: pages,
  dimensions: fixed
      ? ResolvedDimensions(
          size: AuthoredPageSize(width, height),
          source: DimensionSource.viewportMeta,
          reason: 'Synthetic viewport',
        )
      : null,
);

SourceDocument navigationDocument() => const SourceParser().parse(
  sourcePage(
    body:
        '<p id="target">Target text</p><p id="target space">Second target</p>',
  ),
);
