// Consumer contract: what booking-mobile needs from the booking API.
//
// Each test runs the app's own BookingApi against a stub that answers with the
// interaction's example response. It checks the client sent exactly the
// recorded request and could read the response, then the interaction is
// written to pacts/booking-mobile-booking-api.json. api-performance-lab's CI
// replays that file against the real API, so an API change that would break
// this app fails the API's own pull request.
//
// Only fields the app reads are in the contract. Unlike the web app, this one
// copes with an order item that has no seat label (it shows "#<seat id>"), so
// its contract doesn't require one (the fallback is tested in models_test.dart).
import 'dart:convert';

import 'package:booking_mobile/api/booking_api.dart';
import 'package:booking_mobile/screens/event_screen.dart' show seatsPerPage;
import 'package:booking_mobile/screens/events_screen.dart' show eventsPerPage;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'pact_writer.dart';

// The provider's states create orders for this buyer; 99 is a different buyer.
const buyer = 'key-user-98';
const otherBuyer = 'key-user-99';

final pact = PactFile('booking-mobile', 'booking-api');

final event = {
  'id': 1,
  'name': 'Summer concert',
  'venue': 'Main hall',
  'starts_at': '2027-06-01T19:00:00+00:00',
  'available_seats': 4,
};
Map<String, Map<String, Object>> eventRules(String at) => {
      '$at.id': integer,
      '$at.name': anyType,
      '$at.venue': anyType,
      '$at.starts_at': anyType,
      '$at.available_seats': integer,
    };

final order = {
  'id': 1,
  'total_cents': 3500,
  'created_at': '2026-11-27T16:00:00+00:00',
  'items': [
    {'seat_id': 1, 'price_cents': 3500},
  ],
};
Map<String, Map<String, Object>> orderRules(String at) => {
      '$at.id': integer,
      '$at.total_cents': integer,
      '$at.created_at': anyType,
      '$at.items': eachLike(),
      '$at.items[*].seat_id': integer,
      '$at.items[*].price_cents': integer,
    };

final errorBody = {'detail': 'Something went wrong'};
final errorRules = {r'$.detail': anyType};

const acceptJson = {'Accept': 'application/json'};

/// Runs [call] against a stub answering with [i]'s example response, checks the
/// request the client sent, and records [i] for the contract file.
Future<T> recorded<T>(Interaction i, Future<T> Function(BookingApi api) call) async {
  http.Request? sent;
  final api = BookingApi(
    baseUrl: 'http://contract.test',
    client: MockClient((request) async {
      sent = request;
      return http.Response(jsonEncode(i.responseBody), i.status,
          headers: {'content-type': 'application/json'});
    }),
  );
  try {
    return await call(api);
  } finally {
    final request = sent;
    expect(request, isNotNull, reason: 'the client made no request');
    expect(request!.method, i.method);
    expect(request.url.path, i.path);
    expect(request.url.queryParameters, i.query);
    for (final header in i.headers.entries) {
      expect(request.headers[header.key], startsWith(header.value), reason: header.key);
    }
    if (i.body != null) expect(jsonDecode(request.body), i.body);
    pact.add(i);
  }
}

TypeMatcher<ApiException> apiError(int status) =>
    isA<ApiException>().having((e) => e.statusCode, 'statusCode', status);

void main() {
  tearDownAll(() => pact.write('pacts/booking-mobile-booking-api.json'));

  test('a page of upcoming events', () async {
    final page = await recorded(
      Interaction(
        description: 'a request for the first page of events',
        state: 'events exist',
        method: 'GET',
        path: '/events',
        query: {'limit': '$eventsPerPage', 'offset': '0'},
        headers: acceptJson,
        status: 200,
        responseBody: {
          'items': [event],
          'total': 30,
        },
        responseRules: {
          r'$.items': eachLike(),
          ...eventRules(r'$.items[*]'),
          r'$.total': integer,
        },
      ),
      (api) => api.listEvents(limit: eventsPerPage, offset: 0),
    );
    expect(page.items.single.availableSeats, 4);
    expect(page.total, 30);
  });

  test('one event', () async {
    final found = await recorded(
      Interaction(
        description: 'a request for an event',
        state: 'an event with available seats exists',
        method: 'GET',
        path: '/events/1',
        pathExpression: r'/events/${eventId}',
        headers: acceptJson,
        status: 200,
        responseBody: event,
        responseRules: eventRules(r'$'),
      ),
      (api) => api.getEvent(1),
    );
    expect(found.name, 'Summer concert');
  });

  test("the seat map for an event", () async {
    final seats = await recorded(
      Interaction(
        description: "a request for an event's seats",
        state: 'an event with available seats exists',
        method: 'GET',
        path: '/events/1/seats',
        pathExpression: r'/events/${eventId}/seats',
        query: {'limit': '$seatsPerPage', 'offset': '0'},
        headers: acceptJson,
        status: 200,
        responseBody: {
          'items': [
            {'id': 1, 'label': 'R1-1', 'price_cents': 3500, 'status': 'available'},
          ],
        },
        responseRules: {
          r'$.items': eachLike(),
          r'$.items[*].id': integer,
          r'$.items[*].label': anyType,
          r'$.items[*].price_cents': integer,
          r'$.items[*].status': regex('available|sold'),
        },
      ),
      (api) => api.listSeats(1, limit: seatsPerPage, offset: 0),
    );
    expect(seats.single.label, 'R1-1');
  });

  test('buying a seat', () async {
    final placed = await recorded(
      Interaction(
        description: 'an order for an available seat',
        state: 'an event with available seats exists',
        method: 'POST',
        path: '/orders',
        headers: {...acceptJson, 'X-API-Key': buyer, 'Content-Type': 'application/json'},
        body: {
          'seat_ids': [1],
        },
        bodyExpressions: {r'$.seat_ids[0]': r'${seatId}'},
        status: 201,
        responseBody: order,
        responseRules: orderRules(r'$'),
      ),
      (api) => api.createOrder([1], buyer),
    );
    expect(placed.items.single.seatId, 1);
  });

  test('a 409 with a reason when someone else bought the seat first', () async {
    await expectLater(
      recorded(
        Interaction(
          description: 'an order for a seat that is already sold',
          state: 'a seat has already been sold',
          method: 'POST',
          path: '/orders',
          headers: {...acceptJson, 'X-API-Key': buyer, 'Content-Type': 'application/json'},
          body: {
            'seat_ids': [1],
          },
          bodyExpressions: {r'$.seat_ids[0]': r'${seatId}'},
          status: 409,
          responseBody: errorBody,
          responseRules: errorRules,
        ),
        (api) => api.createOrder([1], buyer),
      ),
      throwsA(apiError(409).having((e) => e.message, 'message', 'Something went wrong')),
    );
  });

  test("the buyer's orders", () async {
    final orders = await recorded(
      Interaction(
        description: "a request for the buyer's orders",
        state: 'the buyer has an order',
        method: 'GET',
        path: '/orders',
        query: {'limit': '50'},
        headers: {...acceptJson, 'X-API-Key': buyer},
        status: 200,
        responseBody: {
          'items': [order],
        },
        responseRules: {r'$.items': eachLike(), ...orderRules(r'$.items[*]')},
      ),
      (api) => api.listOrders(buyer),
    );
    expect(orders.single.totalCents, 3500);
  });

  test("a 401 for a key that isn't valid (the sign-in check)", () async {
    await expectLater(
      recorded(
        Interaction(
          description: 'a request for orders with an unknown key',
          method: 'GET',
          path: '/orders',
          query: {'limit': '50'},
          headers: {...acceptJson, 'X-API-Key': 'key-does-not-exist'},
          status: 401,
          responseBody: errorBody,
          responseRules: errorRules,
        ),
        (api) => api.listOrders('key-does-not-exist'),
      ),
      throwsA(apiError(401)),
    );
  });

  test("one of the buyer's orders", () async {
    final found = await recorded(
      Interaction(
        description: "a request for one of the buyer's orders",
        state: 'the buyer has an order',
        method: 'GET',
        path: '/orders/1',
        pathExpression: r'/orders/${orderId}',
        headers: {...acceptJson, 'X-API-Key': buyer},
        status: 200,
        responseBody: order,
        responseRules: orderRules(r'$'),
      ),
      (api) => api.getOrder(1, buyer),
    );
    expect(found.id, 1);
  });

  test("a 404, not someone else's order", () async {
    await expectLater(
      recorded(
        Interaction(
          description: 'a request from another buyer for that order',
          state: 'the buyer has an order',
          method: 'GET',
          path: '/orders/1',
          pathExpression: r'/orders/${orderId}',
          headers: {...acceptJson, 'X-API-Key': otherBuyer},
          status: 404,
          responseBody: errorBody,
          responseRules: errorRules,
        ),
        (api) => api.getOrder(1, otherBuyer),
      ),
      throwsA(apiError(404)),
    );
  });
}
