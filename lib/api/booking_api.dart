import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

/// An error from the booking API, or a failure to reach it (statusCode 0).
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message, {this.retryAfterSeconds});

  final int statusCode;
  final String message;
  final int? retryAfterSeconds;

  bool get isOffline => statusCode == 0;

  @override
  String toString() => 'ApiException($statusCode, $message)';
}

/// Typed client for the booking API (api-performance-lab).
class BookingApi {
  BookingApi(
      {required this.baseUrl, http.Client? client, this.timeout = const Duration(seconds: 15)})
      : _client = client ?? http.Client();

  /// On the Android emulator, 10.0.2.2 is the host machine.
  static const defaultBaseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  Future<EventPage> listEvents({required int limit, required int offset}) async =>
      EventPage.fromJson(await _send('GET', '/events?limit=$limit&offset=$offset') as Json);

  Future<EventSummary> getEvent(int id) async =>
      EventSummary.fromJson(await _send('GET', '/events/$id') as Json);

  Future<List<Seat>> listSeats(int eventId, {required int limit, required int offset}) async {
    final page = await _send('GET', '/events/$eventId/seats?limit=$limit&offset=$offset') as Json;
    return (page['items'] as List<dynamic>).map((s) => Seat.fromJson(s as Json)).toList();
  }

  Future<Order> createOrder(List<int> seatIds, String apiKey) async => Order.fromJson(
        await _send('POST', '/orders', body: {'seat_ids': seatIds}, apiKey: apiKey) as Json,
      );

  Future<List<Order>> listOrders(String apiKey) async {
    final page = await _send('GET', '/orders?limit=50', apiKey: apiKey) as Json;
    return (page['items'] as List<dynamic>).map((o) => Order.fromJson(o as Json)).toList();
  }

  Future<Order> getOrder(int id, String apiKey) async =>
      Order.fromJson(await _send('GET', '/orders/$id', apiKey: apiKey) as Json);

  Future<Object?> _send(String method, String path, {Object? body, String? apiKey}) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['Accept'] = 'application/json';
    if (apiKey != null) request.headers['X-API-Key'] = apiKey;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(timeout));
    } on SocketException {
      throw const ApiException(0, 'Network unreachable');
    } on TimeoutException {
      throw const ApiException(0, 'The request timed out');
    } on http.ClientException {
      throw const ApiException(0, 'Network unreachable');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    throw _toException(response);
  }

  ApiException _toException(http.Response response) {
    var message = response.reasonPhrase ?? 'Request failed (${response.statusCode})';
    try {
      final detail = (jsonDecode(response.body) as Json)['detail'];
      if (detail is String) {
        message = detail;
      } else if (detail is List) {
        message = 'Some of the details sent were not valid.';
      }
    } on FormatException {
      // Not JSON; keep the reason phrase.
    } on TypeError {
      // JSON but not an object; keep the reason phrase.
    }
    final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
    return ApiException(
      response.statusCode,
      message,
      retryAfterSeconds: (retryAfter != null && retryAfter > 0) ? retryAfter : null,
    );
  }

  void close() => _client.close();
}
