import 'dart:convert';

import 'package:booking_mobile/api/booking_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An in-memory stand-in for the booking API that follows the real API's
/// rules: 401 for unknown keys, 404 for unknown ids, 409 for taken seats.
class FakeBackend {
  FakeBackend({int events = 30, int seatsPerEvent = 24}) {
    for (var e = 1; e <= events; e++) {
      this.events.add({
        'id': e,
        'name': 'Event $e',
        'venue': 'Venue ${(e - 1) % 3 + 1}',
        'starts_at': DateTime.utc(2027, 1, e + 1, 19).toIso8601String(),
      });
      for (var n = 0; n < seatsPerEvent; n++) {
        seats.add({
          'id': seats.length + 1,
          'event': e,
          'label': 'R${n ~/ 12 + 1}-${n % 12 + 1}',
          'price_cents': 2500 + (n ~/ 12) * 500,
          'status': 'available',
        });
      }
    }
  }

  static const validKeys = {'key-user-1', 'key-user-2'};

  final events = <Map<String, Object>>[];
  final seats = <Map<String, Object>>[];
  final orders = <Map<String, Object>>[];
  final requests = <String>[];

  /// Set to make the next order fail with this status (and optional Retry-After).
  int? failNextOrderWith;
  String? retryAfter;
  bool offline = false;

  BookingApi api() => BookingApi(baseUrl: 'http://fake', client: MockClient(_handle));

  List<Map<String, Object>> _available(int eventId) =>
      seats.where((s) => s['event'] == eventId && s['status'] == 'available').toList();

  Map<String, Object> _seatOut(Map<String, Object> s) =>
      {'id': s['id']!, 'label': s['label']!, 'price_cents': s['price_cents']!, 'status': s['status']!};

  void sellBehindTheScenes(int seatId) => seats.firstWhere((s) => s['id'] == seatId)['status'] = 'sold';

  Future<http.Response> _handle(http.Request request) async {
    if (offline) throw http.ClientException('offline');
    requests.add('${request.method} ${request.url.path}');
    final path = request.url.pathSegments;
    final q = request.url.queryParameters;
    final limit = int.tryParse(q['limit'] ?? '') ?? 20;
    final offset = int.tryParse(q['offset'] ?? '') ?? 0;
    final key = request.headers['X-API-Key'] ?? request.headers['x-api-key'];
    final user = validKeys.contains(key) ? key : null;

    http.Response json(Object body, [int status = 200, Map<String, String> headers = const {}]) =>
        http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', ...headers});
    http.Response notFound(String what) => json({'detail': '$what not found'}, 404);

    if (request.method == 'GET' && path.length == 1 && path[0] == 'events') {
      final page = events.skip(offset).take(limit).map((e) => {...e, 'available_seats': _available(e['id']! as int).length});
      return json({'items': page.toList(), 'total': events.length, 'limit': limit, 'offset': offset});
    }
    if (request.method == 'GET' && path.length >= 2 && path[0] == 'events') {
      final id = int.tryParse(path[1]);
      final event = events.where((e) => e['id'] == id).firstOrNull;
      if (event == null) return notFound('Event');
      if (path.length == 2) return json({...event, 'available_seats': _available(id!).length});
      if (path[2] == 'seats') {
        final page = _available(id!).skip(offset).take(limit).map(_seatOut).toList();
        return json({'items': page, 'limit': limit, 'offset': offset});
      }
    }
    if (path.isNotEmpty && path[0] == 'orders') {
      if (user == null) return json({'detail': 'Unknown API key'}, 401);
      if (request.method == 'POST') {
        if (failNextOrderWith != null) {
          final status = failNextOrderWith!;
          failNextOrderWith = null;
          return json({'detail': 'failed'}, status, {if (retryAfter != null) 'retry-after': retryAfter!});
        }
        final ids = ((jsonDecode(request.body) as Map<String, dynamic>)['seat_ids'] as List<dynamic>).cast<int>();
        final chosen = ids.map((id) => seats.where((s) => s['id'] == id).firstOrNull).toList();
        if (chosen.any((s) => s == null)) return notFound('Seat');
        if (chosen.any((s) => s!['status'] != 'available')) {
          return json({'detail': 'One or more seats are already taken'}, 409);
        }
        for (final s in chosen) {
          s!['status'] = 'sold';
        }
        final order = <String, Object>{
          'id': orders.length + 1,
          'owner': user,
          'total_cents': chosen.fold<int>(0, (sum, s) => sum + (s!['price_cents']! as int)),
          'created_at': DateTime.utc(2026, 11, 26, 15).toIso8601String(),
          'items': [for (final s in chosen) {'seat_id': s!['id']!, 'price_cents': s['price_cents']!}],
        };
        orders.add(order);
        return json(_public(order), 201);
      }
      if (path.length == 1) {
        final mine = orders.where((o) => o['owner'] == user).toList().reversed.map(_public).toList();
        return json({'items': mine, 'limit': 50, 'offset': 0});
      }
      final order = orders.where((o) => o['id'] == int.tryParse(path[1]) && o['owner'] == user).firstOrNull;
      return order == null ? notFound('Order') : json(_public(order));
    }
    return notFound('Route');
  }

  Map<String, Object> _public(Map<String, Object> o) => Map.of(o)..remove('owner');
}
