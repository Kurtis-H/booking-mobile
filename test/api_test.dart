import 'dart:convert';

import 'package:booking_mobile/api/booking_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_backend.dart';

BookingApi apiReturning(http.Response response, {void Function(http.Request)? seen}) => BookingApi(
      baseUrl: 'http://x',
      client: MockClient((request) async {
        seen?.call(request);
        return response;
      }),
    );

void main() {
  test('sends the API key and a JSON body', () async {
    late http.Request sent;
    final api = apiReturning(
      http.Response(
        jsonEncode({
          'id': 1,
          'total_cents': 100,
          'created_at': '2026-11-26T15:00:00Z',
          'items': <Object>[]
        }),
        201,
      ),
      seen: (r) => sent = r,
    );
    await api.createOrder([4, 5], 'k');
    expect(sent.headers['X-API-Key'], 'k');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(sent.body), {
      'seat_ids': [4, 5]
    });
  });

  test('turns detail into the message and reads Retry-After', () async {
    final api = apiReturning(
        http.Response(jsonEncode({'detail': 'slow down'}), 429, headers: {'retry-after': '12'}));
    await expectLater(
      api.listOrders('k'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 429)
            .having((e) => e.message, 'message', 'slow down')
            .having((e) => e.retryAfterSeconds, 'retryAfter', 12),
      ),
    );
  });

  test('summarises validation errors', () async {
    final api = apiReturning(http.Response(
        jsonEncode({
          'detail': <Object>[
            {'loc': <Object>[]}
          ]
        }),
        422));
    await expectLater(
      api.getEvent(1),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'Some of the details sent were not valid.')),
    );
  });

  test('copes with a body that is not JSON', () async {
    final api = apiReturning(http.Response('oops', 502, reasonPhrase: 'Bad Gateway'));
    await expectLater(
      api.getEvent(1),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Bad Gateway')),
    );
  });

  test('network failures become offline errors', () async {
    final api = BookingApi(
        baseUrl: 'http://x', client: MockClient((_) => throw http.ClientException('down')));
    await expectLater(
        api.getEvent(1), throwsA(isA<ApiException>().having((e) => e.isOffline, 'offline', true)));
  });

  test('pages through events and seats', () async {
    final api = FakeBackend().api();
    final page = await api.listEvents(limit: 5, offset: 10);
    expect(page.items.map((e) => e.id), [11, 12, 13, 14, 15]);
    expect(page.total, 30);
    expect(await api.listSeats(1, limit: 100, offset: 0), hasLength(24));
  });
}
