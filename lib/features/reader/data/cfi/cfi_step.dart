/// One Foliate CFI step. NaN is retained for its permissive malformed grammar.
///
/// Only [index] is required; the other fields exist when the grammar produced
/// them, mirroring the properties of the reference's step objects.
final class CfiStep {
  CfiStep({
    required this.index,
    this.id,
    this.offset,
    this.temporal,
    List<num>? spatial,
    List<String>? text,
    this.side,
  }) : spatial = spatial == null ? null : List.unmodifiable(spatial),
       text = text == null ? null : List.unmodifiable(text);

  final num index;
  final String? id;
  final num? offset;
  final num? temporal;
  final List<num>? spatial;
  final List<String>? text;
  final String? side;

  /// The reference's `JSON.stringify` shape: absent fields are omitted and
  /// non-finite numbers become null.
  Map<String, Object?> toJson() => {
    'index': _jsonNumber(index),
    if (id != null) 'id': id,
    if (offset != null) 'offset': _jsonNumber(offset),
    if (temporal != null) 'temporal': _jsonNumber(temporal),
    if (spatial case final values?)
      'spatial': values.map(_jsonNumber).toList(growable: false),
    if (text != null) 'text': text,
    if (side != null) 'side': side,
  };
}

num? _jsonNumber(num? value) => value != null && value.isFinite ? value : null;
