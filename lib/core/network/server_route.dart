import 'package:shiori/core/config/book_key.dart';

/// Fixed templates only: never derive log text from a URI or server content.
enum ServerRoute {
  health('api/health'),
  snapshot('api/library/snapshot'),
  book('api/books/{id}'),
  file('api/books/{id}/file'),
  cover('covers/{resource}'),
  unknown('{route}');

  const ServerRoute(this.template);
  final String template;

  static ServerRoute api(List<String> segments) {
    if (segments.length == 2 &&
        segments[0] == 'api' &&
        segments[1] == 'health') {
      return health;
    }
    if (segments.length == 3 &&
        segments[0] == 'api' &&
        segments[1] == 'library' &&
        segments[2] == 'snapshot') {
      return snapshot;
    }
    if ((segments.length == 3 || segments.length == 4) &&
        segments[0] == 'api' &&
        segments[1] == 'books') {
      final id = int.tryParse(segments[2]);
      if (id != null &&
          id >= 1 &&
          id <= BookKey.maxBookId &&
          id.toString() == segments[2]) {
        if (segments.length == 3) return book;
        if (segments[3] == 'file') return file;
      }
    }
    throw ArgumentError('Unsupported S3 read route');
  }
}
