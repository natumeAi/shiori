/// Session retirement is control flow: never retry or publish it as UI error.
final class RequestCancelled implements Exception {
  const RequestCancelled();
}
