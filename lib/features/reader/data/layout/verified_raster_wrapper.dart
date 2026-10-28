import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';

/// The intrinsic dimensions must come from the resource named by the sole img.
/// Arbitrary images in content never supply page dimensions.
final class VerifiedRasterWrapper {
  VerifiedRasterWrapper._(this.size, this.resource);
  final AuthoredPageSize size;
  final String resource;

  static VerifiedRasterWrapper? verify({
    required SourceDocument document,
    required String resource,
    required String mediaType,
    required AuthoredPageSize intrinsicSize,
  }) {
    final body = document.bodyIndex;
    if (body == null ||
        resource.isEmpty ||
        !const {
          'image/png',
          'image/jpeg',
          'image/gif',
          'image/webp',
          'image/bmp',
        }.contains(mediaType)) {
      return null;
    }
    final children = document
        .node(body)
        .children
        .map(document.node)
        .where(
          (node) =>
              node.kind != SourceNodeKind.comment &&
              !(node.kind == SourceNodeKind.text &&
                  (node.text ?? '').trim().isEmpty),
        )
        .toList();
    if (children.length != 1) return null;
    final image = children.single;
    if (image.localName != 'img' ||
        image.attribute('src') != resource ||
        image.namespaceUri != 'http://www.w3.org/1999/xhtml') {
      return null;
    }
    return VerifiedRasterWrapper._(intrinsicSize, resource);
  }

  @override
  bool operator ==(Object other) =>
      other is VerifiedRasterWrapper &&
      size == other.size &&
      resource == other.resource;
  @override
  int get hashCode => Object.hash(size, resource);
}
