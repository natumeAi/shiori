import 'dart:convert';
import 'dart:io';

import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_session.dart';

String fixture(String name) =>
    File('test/fixtures/server/$name').readAsStringSync();
Map<String, Object?> payload([String name = 'snapshot_typical.json']) =>
    jsonDecode(fixture(name)) as Map<String, Object?>;
Map<String, Object?> snapshot(Map<String, Object?> body) =>
    body['snapshot']! as Map<String, Object?>;
List<Map<String, Object?>> records(Map<String, Object?> body, String key) =>
    (snapshot(body)[key]! as List<Object?>).cast<Map<String, Object?>>();
ServerSession session() => ServerSession(
  endpoint: ServerEndpoint.parse('https://example.test/Reader/').endpoint!,
  generation: 1,
);
