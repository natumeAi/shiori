// A0b measurement pins: provenance-only oracle regeneration is permitted.
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Object? _measured(Object? value) {
  if (value is Map) {
    return SplayTreeMap<String, Object?>.from({
      for (final key in value.keys.cast<String>())
        if (key != 'clusterSource' &&
            key != 'clusterConfirmation' &&
            !key.toLowerCase().contains('provenance') &&
            !key.toLowerCase().contains('evidence'))
          key: _measured(value[key]),
    });
  }
  if (value is List) return value.map(_measured).toList();
  return value;
}

String svgTextContentHash(Map<String, Object?> data) {
  final cases = (data['cases'] as List).cast<Map>().where(
    (c) =>
        c['row'] == 'svg-text' || (c['id'] as String).startsWith('svg-text-'),
  );
  return sha256
      .convert(
        utf8.encode(
          jsonEncode(
            _measured({
              'cases': cases.toList(),
              'svgTextProbes': data['svgTextProbes'],
            }),
          ),
        ),
      )
      .toString();
}

Map<String, String> currentSvgTextContentHashes() => {
  for (final name in ['corpus', 'oracle'])
    name: svgTextContentHash(
      jsonDecode(
        File('test/fixtures/reader/fixed_layout/$name.json').readAsStringSync(),
      ) as Map<String, Object?>,
    ),
};

void main() => stdout.writeln(jsonEncode(currentSvgTextContentHashes()));
