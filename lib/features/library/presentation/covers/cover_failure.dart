/// Content-free placeholder reasons; none carry an endpoint or response body.
enum CoverFailure {
  missing,
  invalidPath,
  oversized,
  nonImage,
  cacheBusy,
  network,
  unavailable,
  cancelled,
}
