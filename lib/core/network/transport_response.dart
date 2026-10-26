/// HTTP facts without Dio or request/endpoint metadata.
final class TransportResponse<T> {
  TransportResponse({
    required this.statusCode,
    required Map<String, List<String>> headers,
    required this.body,
  }) : headers = Map.unmodifiable(
         headers.map(
           (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
         ),
       );

  final int statusCode;
  final Map<String, List<String>> headers;
  final T body;
}
