part 'server_endpoint_validation.dart';

/// A validated HTTP(S) deployment root, including its directory prefix.
final class ServerEndpoint {
  ServerEndpoint._(this._root);

  final Uri _root;

  String get canonicalRoot => _root.toString();

  /// Display the canonical address without decoding reserved path characters.
  String get normalizedText => canonicalRoot;

  static final _scheme = RegExp(r'^https?://', caseSensitive: false);
  static final _invalidEscape = RegExp(r'%(?![0-9a-fA-F]{2})');
  static final _hostCharacters = RegExp(r'^[a-zA-Z0-9._~-]+$');
  static final _digits = RegExp(r'^[0-9]+$');
  static final _whitespaceOrControl = RegExp(r'[\s\x00-\x1f\x7f]');

  /// Validation is synchronous and content-free, even when [Uri] rejects input.
  static ServerEndpointValidation parse(String input) {
    final text = input.trim();
    if (!_scheme.hasMatch(text)) return const .invalid(.scheme);
    if (text.contains(r'\')) return const .invalid(.backslash);
    if (_invalidEscape.hasMatch(text)) return const .invalid(.percentEscape);
    if (text.contains('?')) return const .invalid(.query);
    if (text.contains('#')) return const .invalid(.fragment);

    final authorityStart = text.indexOf('://') + 3;
    final pathStart = text.indexOf('/', authorityStart);
    final authority = text.substring(
      authorityStart,
      pathStart < 0 ? text.length : pathStart,
    );
    if (authority.contains('@')) return const .invalid(.userInfo);
    if (authority.isEmpty || _whitespaceOrControl.hasMatch(authority)) {
      return const .invalid(.host);
    }

    String host;
    String? portText;
    if (authority.startsWith('[')) {
      final end = authority.indexOf(']');
      if (end < 0) return const .invalid(.host);
      host = authority.substring(0, end + 1);
      // Interface-local zone IDs are not portable deployment identities.
      if (host.contains('%')) return const .invalid(.ipv6ZoneIdentifier);
      final suffix = authority.substring(end + 1);
      if (suffix.isNotEmpty) {
        if (!suffix.startsWith(':')) return const .invalid(.port);
        portText = suffix.substring(1);
      }
    } else {
      final colon = authority.indexOf(':');
      host = colon < 0 ? authority : authority.substring(0, colon);
      if (colon >= 0) portText = authority.substring(colon + 1);
      if (host.isEmpty || !_hostCharacters.hasMatch(host)) {
        return const .invalid(.host);
      }
    }
    if (portText != null) {
      final port = int.tryParse(portText);
      if (!_digits.hasMatch(portText) ||
          port == null ||
          port < 1 ||
          port > 65535) {
        return const .invalid(.port);
      }
    }

    try {
      final uri = Uri.parse(text).normalizePath();
      if (!uri.hasAuthority || uri.host.isEmpty) {
        return const .invalid(.host);
      }
      final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
      final root = uri.replace(path: '$path/');
      return .valid(ServerEndpoint._(root));
    } on FormatException {
      return const .invalid(.invalidAddress);
    } on ArgumentError {
      return const .invalid(.invalidAddress);
    }
  }

  /// [segments] includes `api`; each element is data, never URI syntax.
  Uri api(List<String> segments) {
    if (segments.isEmpty ||
        segments.any((s) => s.isEmpty || s == '.' || s == '..')) {
      throw ArgumentError('Invalid API path segments');
    }
    return _root.resolve(segments.map(Uri.encodeComponent).join('/'));
  }

  /// Server `/covers/...` paths are relative to the deployment, not its origin.
  /// Rejections contain no supplied URL or path.
  Uri cover(String serverPath) {
    if (!serverPath.startsWith('/covers/') ||
        serverPath.contains(r'\') ||
        serverPath.contains('#') ||
        _invalidEscape.hasMatch(serverPath) ||
        _whitespaceOrControl.hasMatch(serverPath)) {
      throw const FormatException('Invalid server cover resource');
    }
    try {
      // Inspect decoded segments only for traversal. Never rebuild their path.
      final path = serverPath.split('?').first;
      for (final encoded in path.split('/')) {
        final segment = Uri.decodeComponent(encoded);
        if (segment.split(RegExp(r'[/\\]')).contains('..') ||
            segment.contains(r'\')) {
          throw const FormatException('Invalid server cover resource');
        }
      }
      final relative = Uri.parse(serverPath.substring(1));
      final resolved = _root.resolveUri(relative);
      if (relative.hasScheme ||
          relative.hasAuthority ||
          resolved.origin != _root.origin ||
          !resolved.path.startsWith('${_root.path}covers/')) {
        throw const FormatException('Invalid server cover resource');
      }
      return resolved;
    } on FormatException {
      throw const FormatException('Invalid server cover resource');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ServerEndpoint && canonicalRoot == other.canonicalRoot;

  @override
  int get hashCode => canonicalRoot.hashCode;
}
