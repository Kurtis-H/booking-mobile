/// Data shapes returned by the booking API. Money is always whole cents.
library;

typedef Json = Map<String, dynamic>;

class EventSummary {
  const EventSummary({
    required this.id,
    required this.name,
    required this.venue,
    required this.startsAt,
    required this.availableSeats,
  });

  factory EventSummary.fromJson(Json json) => EventSummary(
        id: json['id'] as int,
        name: json['name'] as String,
        venue: json['venue'] as String,
        startsAt: DateTime.parse(json['starts_at'] as String),
        availableSeats: json['available_seats'] as int,
      );

  final int id;
  final String name;
  final String venue;
  final DateTime startsAt;
  final int availableSeats;
}

class EventPage {
  const EventPage({required this.items, required this.total});

  factory EventPage.fromJson(Json json) => EventPage(
        items:
            (json['items'] as List<dynamic>).map((e) => EventSummary.fromJson(e as Json)).toList(),
        total: json['total'] as int,
      );

  final List<EventSummary> items;
  final int total;
}

class Seat {
  const Seat({
    required this.id,
    required this.label,
    required this.priceCents,
    required this.status,
    this.section = 'General',
    String? row,
    int? number,
  })  : row = row ?? '',
        _number = number;

  factory Seat.fromJson(Json json) => Seat(
        id: json['id'] as int,
        label: json['label'] as String,
        priceCents: json['price_cents'] as int,
        status: json['status'] as String,
        // Older API versions send only the label; the app copes without the rest.
        section: json['section'] as String? ?? 'General',
        row: json['row'] as String?,
        number: json['number'] as int?,
      );

  final int id;

  /// "R3-12" or "A-7": the row, a dash, then the seat number.
  final String label;
  final int priceCents;
  final String status;

  /// The price tier the seat is in, such as "Orchestra". "General" for a plain block.
  final String section;
  final String row;
  final int? _number;

  /// The seat's number in its row, from the API or else read from the label.
  String get number => _number?.toString() ?? label.split('-').last;

  /// The row, from the API or else read from the label.
  String get rowName => row.isNotEmpty ? row : label.split('-').first;

  /// The same seat with another status, such as a seat you hold shown as one you can buy.
  Seat withStatus(String newStatus) => Seat(
        id: id,
        label: label,
        priceCents: priceCents,
        status: newStatus,
        section: section,
        row: row,
        number: _number,
      );
}

class OrderItem {
  const OrderItem({required this.seatId, required this.label, required this.priceCents});

  factory OrderItem.fromJson(Json json) => OrderItem(
        seatId: json['seat_id'] as int,
        // Older API versions don't send the label; fall back to the id.
        label: json['label'] as String? ?? '#${json['seat_id']}',
        priceCents: json['price_cents'] as int,
      );

  final int seatId;

  /// The seat as the buyer saw it, such as "R3-12".
  final String label;
  final int priceCents;
}

class Order {
  const Order({
    required this.id,
    required this.totalCents,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Json json) => Order(
        id: json['id'] as int,
        totalCents: json['total_cents'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
        items: (json['items'] as List<dynamic>).map((e) => OrderItem.fromJson(e as Json)).toList(),
      );

  final int id;
  final int totalCents;
  final DateTime createdAt;
  final List<OrderItem> items;
}

/// Seats you hold for an event, and when the hold ends.
class Hold {
  const Hold({required this.eventId, required this.seatIds, required this.expiresAt});

  factory Hold.fromJson(Json json) => Hold(
        eventId: json['event_id'] as int,
        seatIds: (json['seat_ids'] as List<dynamic>).cast<int>(),
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );

  final int eventId;
  final List<int> seatIds;
  final DateTime expiresAt;
}
