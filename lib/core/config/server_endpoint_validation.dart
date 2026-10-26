part of 'server_endpoint.dart';

/// Stable reasons for localized form feedback; never carries submitted text.
enum ServerEndpointIssue {
  scheme,
  host,
  userInfo,
  query,
  fragment,
  percentEscape,
  backslash,
  port,
  ipv6ZoneIdentifier,
  invalidAddress,
}

/// Exactly one of [endpoint] and [issue] is present.
final class ServerEndpointValidation {
  const ServerEndpointValidation.valid(ServerEndpoint this.endpoint)
    : issue = null;

  const ServerEndpointValidation.invalid(ServerEndpointIssue this.issue)
    : endpoint = null;

  final ServerEndpoint? endpoint;
  final ServerEndpointIssue? issue;
}
