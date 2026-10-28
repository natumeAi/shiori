import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/canonical/canonical_text.dart';
import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';

import '../worker/import_test_support.dart';

Map<String, dynamic> read(String name) => jsonDecode(
  File('test/fixtures/reader/fixed_layout/$name.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  final corpus = read('corpus'), oracle = read('oracle');
  final cases = (corpus['cases'] as List).cast<Map<String, dynamic>>();
  final observations = {
    for (final c in (oracle['cases'] as List).cast<Map<String, dynamic>>())
      c['id']: c,
  };
  test('the measured WebKit corpus pins every row and variant', () {
    expect(oracle['engine'], 'webkit');
    expect(oracle['referenceDirty'], false);
    expect(
      oracle['corpusSHA256'],
      sha256
          .convert(
            File('test/fixtures/reader/fixed_layout/corpus.json')
                .readAsBytesSync(),
          )
          .toString(),
    );
    expect(cases, hasLength(52));
    final rows = cases.map((c) => c['row']).toSet();
    expect(rows, hasLength(13));
    for (final row in rows) {
      expect(
        cases.where((c) => c['row'] == row).map((c) => c['variant']).toSet(),
        {'positive', 'boundary', 'nested', 'unsupported'},
      );
    }
    for (final c in cases) {
      final measured = observations[c['id']]!;
      expect(
        sha256.convert(utf8.encode(c['source'] as String)).toString(),
        c['sha256'],
      );
      expect(measured['sourceSHA256'], c['sha256']);
      expect(measured['fontLoaded'], true, reason: c['id'] as String);
    }
    final paintRows = {
      'filters',
      'clip-mask',
      'svg-text',
      'foreign-object',
      'cascade',
      'box',
      'paint',
      'stacking',
      'text',
      'dimensions',
      'svg-graphics',
    };
    for (final c in cases) {
      final measured = observations[c['id']]!;
      final needsPaint =
          c.containsKey('fallbackCharacters') ||
          paintRows.contains(c['row']) && c['variant'] != 'unsupported';
      expect(measured.containsKey('pngBase64'), needsPaint, reason: c['id']);
      expect(measured.containsKey('paintStability'), needsPaint);
      if (!needsPaint) continue;
      expect(base64Decode(measured['pngBase64'] as String).take(8), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]);
      expect(measured['paintStability']['twoAnimationFramesIdentical'], true);
    }
    final probes = (oracle['svgTextProbes'] as List)
        .cast<Map<String, dynamic>>();
    expect(probes.map((p) => p['adjustment']), [
      'none',
      'spacing',
      'spacingAndGlyphs',
    ]);
    for (final probe in probes) {
      expect(base64Decode(probe['pngBase64'] as String).take(8), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]);
      expect(probe['paintStability']['twoAnimationFramesIdentical'], true);
    }
  });
  test('unsupported dimensions and cascade exercise applied constructs', () {
    final positive = cases.singleWhere((c) => c['id'] == 'dimensions-positive');
    final unsupported = cases.singleWhere(
      (c) => c['id'] == 'dimensions-unsupported',
    );
    expect(unsupported['expectedCapability'], 'unsupported');
    expect(unsupported['sha256'], isNot(positive['sha256']));
    final dimensions = observations['dimensions-unsupported']!['dimensions'];
    expect(dimensions['rootWidth'], '50%');
    expect(dimensions['rootHeight'], '75%');
    expect(dimensions['computedSize'], ['160px', '180px']);
    expect(dimensions['clientBox'], [0, 0, 160, 180]);
    expect(dimensions['screenCTM'], [.5, 0, 0, .5, 0, 30]);
    final declaration =
        observations['cascade-unsupported']!['appliedDeclaration'];
    expect(declaration['elementMatches'], true);
    expect(declaration['matchingTopLevelRules'], 1);
    expect(declaration['cssSupported'], false);
    expect(declaration['retainedValues'], ['']);
    expect(declaration['computedValue'], '');
  });
  test('measured cluster controls conserve every body text node and UTF16', () {
    void checkRun(Map<String, dynamic> run) {
      final text = run['text'] as String;
      final ranges = (run['clusterMap'] as List).cast<List<dynamic>>();
      expect(run['clusterSource'], 'webkit-measured-ligature-control');
      final evidence = run['clusterEvidence'] as Map;
      expect(evidence['control'], 'font-variant-ligatures:none');
      expect(evidence['boundaryUnit'], 'source-UTF16');
      expect(evidence['normalBoundaryAdvances'], hasLength(text.length + 1));
      expect(evidence['disabledBoundaryAdvances'], hasLength(text.length + 1));
      for (final span in evidence['ligatureSpans'] as List) {
        expect(
          ((span['normalAdvance'] as num) - (span['disabledAdvance'] as num))
              .abs(),
          greaterThan(1e-6),
        );
        expect(ranges, contains(equals(span['range'])));
      }
      var offset = 0;
      for (final range in ranges) {
        expect(range, hasLength(2));
        expect(range.first, offset);
        expect(range.last as int, greaterThan(offset));
        offset = range.last as int;
      }
      expect(offset, text.length);
      if (text.contains('e\u0301')) expect(ranges, contains(equals([6, 8])));
    }

    for (final c in cases.where((c) => c.containsKey('textRuns'))) {
      final measured = observations[c['id']]!;
      final texts = measured['texts'] as List;
      expect(c['textRuns'], hasLength(texts.length), reason: c['id']);
      for (final run in (c['textRuns'] as List).cast<Map<String, dynamic>>()) {
        checkRun(run);
        expect(texts[run['textNodeIndex']]['fixtureRun'], run);
        if (run['kind'] == 'svg-text') {
          final svg = measured['svgTexts'][run['svgTextIndex']];
          expect(svg['fixtureRun'], run);
          final control = svg['ligatureControl'];
          final vertical =
              c['variant'] == 'unsupported' && run['svgTextIndex'] == 0;
          expect(
            control['disabledLength'],
            vertical
                ? control['normalLength']
                : greaterThan(control['normalLength'] as num),
          );
          expect(
            run['clusterMap'],
            vertical
                ? isNot(contains(equals([3, 5])))
                : contains(equals([3, 5])),
          );
        } else if (run['text'] == 'Ab fi') {
          expect(run['clusterMap'], contains(equals([3, 5])));
        }
      }
    }
    final flow =
        (cases.singleWhere((c) => c['id'] == 'box-positive')['textRuns']
                as List)
            .singleWhere((r) => r['text'] == 'nested flow');
    expect(flow['clusterMap'], contains(equals([7, 9])));
    final fl = (flow['clusterEvidence']['ligatureSpans'] as List).single;
    expect(fl['range'], [7, 9]);
    expect(fl['normalAdvance'], 11.357421875);
    expect(fl['disabledAdvance'], 11.796875);
    final probes = corpus['svgTextProbes'] as List;
    expect(probes, hasLength(3));
    for (var i = 0; i < probes.length; i++) {
      final probe = probes[i] as Map<String, dynamic>;
      checkRun(probe);
      expect(probe['clusterMap'], contains(equals([3, 5])));
      for (final key in probe.keys) {
        expect(oracle['svgTextProbes'][i][key], probe[key]);
      }
    }
  });
  test('fallback is confined to one existing text variant and gated in A5', () {
    final fallback = cases
        .where((c) => c.containsKey('fallbackCharacters'))
        .single;
    expect(fallback['id'], 'text-boundary');
    expect(fallback['fallbackCharacters'], [
      {
        'codePoint': 'U+1F600',
        'textNodeIndex': 0,
        'utf16': [0, 2],
      },
    ]);
    for (final c in cases) {
      expect((c['source'] as String).contains('\u{1f600}'), c == fallback);
    }
    expect(fallback['geometryGate'], 'device-gated (A5)');
    expect(fallback['pixelGate'], 'device-gated (A5)');
    expect(
      observations[fallback['id']]!['fallbackCharacters'],
      fallback['fallbackCharacters'],
    );
  });
  test('foreignObject baselines use fractional element geometry', () {
    for (final c in cases.where((c) => c['row'] == 'foreign-object')) {
      final texts = observations[c['id']]!['texts'] as List;
      final nestedOffset = c['variant'] == 'nested' ? 9 : 0;
      for (var i = 0; i < 2; i++) {
        final baseline = texts[i]['baseline'];
        expect(
          baseline['method'],
          'zero-size-inline-block-baseline/getBoundingClientRect',
        );
        expect(baseline['coordinateSpace'], 'viewport-css-px');
        expect(baseline['available'], true);
        expect(baseline['y'], 70 + nestedOffset + i * 3);
        expect(baseline['fractionalTranslationDeltaY'], .375);
        expect(
          texts[i]['advance']['prefixWidths'],
          hasLength((texts[i]['utf16Length'] as int) + 1),
        );
      }
      expect(texts[1]['baseline']['x'] % 1, isNot(0));
      if (c['variant'] == 'unsupported') {
        expect(texts[2]['fixtureRun']['rendered'], false);
        expect(texts[2]['baseline']['available'], false);
        expect(texts[2]['baseline']['y'], isNull);
      }
    }
  });
  for (final c in cases) {
    test(
      '${c['id']} conserves browser body text, namespaces and UTF16 CFIs',
      () {
        final doc = const SourceParser().parse(c['source'] as String);
        final bodyNodes = <SourceNode>[];
        void walk(int index) {
          final node = doc.node(index);
          if (node.kind == SourceNodeKind.text) bodyNodes.add(node);
          for (final child in node.children) {
            walk(child);
          }
        }

        walk(doc.bodyIndex!);
        final measured = (observations[c['id']]!['projectedTexts'] as List)
            .cast<Map<String, dynamic>>();
        expect(bodyNodes.map((n) => n.text), measured.map((m) => m['text']));
        expect(
          bodyNodes.map((n) => doc.node(n.parentIndex!).namespaceUri),
          measured.map((m) => m['namespace']),
        );
        for (final node in bodyNodes) {
          final value = node.text!;
          for (var offset = 0; offset <= value.length; offset++) {
            final point = SourcePosition(nodeIndex: node.index, offset: offset);
            final local = Cfi.export(doc, point);
            final expectedText = measured[bodyNodes.indexOf(node)];
            expect(local, (expectedText['cfis'] as List)[offset]['cfi']);
            final resolved = Cfi.resolveLocal(doc, local);
            expect(resolved.start.nodeIndex, point.nodeIndex);
            expect(resolved.start.offset, point.offset);
          }
        }
        final canonical = CanonicalIndex.build(doc);
        expect(canonical.version, 1);
        for (final entry in canonical.entries) {
          int? index = entry.nodeIndex;
          while (index != null) {
            final node = doc.node(index);
            expect(node.namespaceUri, isNot('http://www.w3.org/2000/svg'));
            index = node.parentIndex;
          }
        }
        if (c['row'] == 'foreign-object' || c['row'] == 'svg-text') {
          expect(
            canonical.length,
            0,
            reason: 'canonical v1 excludes the entire SVG subtree',
          );
        }
      },
    );
  }
  test(
    'all raw OPFs cross the worker with effective layout and spine identity',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'shiori-fixed-corpus-',
      );
      final worker = await PublicationWorker.spawn();
      try {
        for (final c in cases) {
          final publication = c['publication'] as Map<String, dynamic>;
          final sequence = (publication['sequence'] as List)
              .cast<Map<String, dynamic>>();
          final entries = importEntries();
          entries.remove('EPUB/s0.xhtml');
          entries['EPUB/package.opf'] = publication['packageSource'] as String;
          for (var i = 0; i < sequence.length; i++) {
            entries['EPUB/p$i.xhtml'] = c['source'] as String;
          }
          final file = writeImport(directory, entries, name: c['id'] as String);
          final result = await worker.prepare(file.path, identityFor(file));
          expect(
            result.layoutFacts.packageRendition['layout'],
            publication['layout'],
          );
          expect(
            result.layoutFacts.packageRendition['orientation'],
            publication['orientation'],
          );
          expect(
            result.layoutFacts.packageRendition['spread'],
            publication['spread'],
          );
          expect(result.layoutFacts.sections, hasLength(sequence.length));
          for (var i = 0; i < sequence.length; i++) {
            final facts = result.layoutFacts.sections[i];
            expect(
              facts.mode,
              sequence[i]['layout'] == 'pre-paginated'
                  ? PublicationLayoutMode.fixed
                  : PublicationLayoutMode.reflowable,
            );
            expect(facts.rendition['pageSpread'], sequence[i]['side']);
          }
          expect(result.firstSection.canonicalVersion, 1);
        }
      } finally {
        await worker.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
}
