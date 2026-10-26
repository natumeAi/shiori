/// Preserve opaque codes, never server messages. Callers must not log the code.
Object? serverErrorCode(Object? body) {
  if (body is! Map<String, Object?>) return null;
  if (body.containsKey('code')) return body['code'];
  final error = body['error'];
  return error is Map<String, Object?> ? error['code'] : null;
}
