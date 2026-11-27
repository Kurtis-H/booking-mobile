// Writes a Pact V4 contract file from interactions recorded in Dart tests.
//
// There is no maintained Pact library for current Flutter: pact_dart pins
// http ^0.13 (this app uses ^1.2), hasn't had a release in 19 months, and
// can't inject provider-state values. So the tests check the app's own
// client against each interaction, and this file writes the standard Pact
// JSON. The API verifies it with Pact's official verifier, which also
// rejects a malformed file.
import 'dart:convert';
import 'dart:io';

/// A Pact matching rule, in the V4 file format.
Map<String, Object> rule(Map<String, Object> matcher) => {
      'combine': 'AND',
      'matchers': [matcher],
    };

final integer = rule({'match': 'integer'});
final anyType = rule({'match': 'type'});
Map<String, Object> eachLike() => rule({'match': 'type', 'min': 1});
Map<String, Object> regex(String pattern) => rule({'match': 'regex', 'regex': pattern});

/// One request and response the app depends on.
class Interaction {
  Interaction({
    required this.description,
    this.state,
    required this.method,
    required this.path,
    this.pathExpression,
    this.query = const {},
    this.headers = const {},
    this.body,
    this.bodyExpressions = const {},
    required this.status,
    this.responseBody,
    this.responseRules = const {},
  });

  final String description;
  final String? state;
  final String method;

  /// The example path; [pathExpression] lets the provider swap in real ids.
  final String path;
  final String? pathExpression;
  final Map<String, String> query;
  final Map<String, String> headers;
  final Object? body;

  /// JSON path in the request body -> provider-state expression.
  final Map<String, String> bodyExpressions;
  final int status;
  final Object? responseBody;

  /// JSON path in the response body -> matching rule.
  final Map<String, Map<String, Object>> responseRules;

  Map<String, Object> toJson() {
    Map<String, Object> generator(String expression) =>
        {'expression': expression, 'type': 'ProviderState'};
    final generators = <String, Object>{
      if (pathExpression != null) 'path': generator(pathExpression!),
      if (bodyExpressions.isNotEmpty)
        'body': {for (final e in bodyExpressions.entries) e.key: generator(e.value)},
    };
    return {
      'description': description,
      'pending': false,
      if (state != null) 'providerStates': [
        {'name': state!},
      ],
      'request': {
        'method': method,
        'path': path,
        if (query.isNotEmpty) 'query': {for (final q in query.entries) q.key: [q.value]},
        if (headers.isNotEmpty) 'headers': {for (final h in headers.entries) h.key: [h.value]},
        if (body != null)
          'body': {'content': body, 'contentType': 'application/json', 'encoded': false},
        if (generators.isNotEmpty) 'generators': generators,
      },
      'response': {
        'status': status,
        if (responseBody != null)
          'body': {'content': responseBody, 'contentType': 'application/json', 'encoded': false},
        if (responseRules.isNotEmpty) 'matchingRules': {'body': responseRules},
      },
      'type': 'Synchronous/HTTP',
    };
  }
}

class PactFile {
  PactFile(this.consumer, this.provider);

  final String consumer;
  final String provider;
  final List<Interaction> interactions = [];

  void add(Interaction interaction) {
    if (interactions.any((i) => i.description == interaction.description)) {
      throw StateError('Duplicate interaction: ${interaction.description}');
    }
    interactions.add(interaction);
  }

  Map<String, Object> toJson() => {
        'consumer': {'name': consumer},
        'provider': {'name': provider},
        'interactions': [for (final i in interactions) i.toJson()],
        'metadata': {
          'pactSpecification': {'version': '4.0'},
        },
      };

  /// Overwrites the file, so an interaction removed from the tests can't linger.
  void write(String path) {
    final file = File(path)..parent.createSync(recursive: true);
    file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(toJson())}\n');
  }
}
