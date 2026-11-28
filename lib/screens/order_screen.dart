import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import '../logic/format.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/status.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.orderId, this.justBought = false});
  final int orderId;
  final bool justBought;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  Future<Order>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    _future ??= session.api.getOrder(widget.orderId, session.apiKey ?? '');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Order #${widget.orderId}')),
        body: FutureBuilder<Order>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error!);
            if (!snap.hasData) return const LoadingView(label: 'Loading order…');
            final order = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.justBought) ...[
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Palette.okSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Palette.ok),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Thanks! Your order is confirmed.',
                              key: ValueKey('order-confirmation'),
                              style: TextStyle(color: Palette.ok, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _Ticket(order: order),
              ],
            );
          },
        ),
      );
}

/// The order as a ticket: a header stub, the seats, and the total.
class _Ticket extends StatelessWidget {
  const _Ticket({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Palette.accent,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pluralize(order.items.length, 'seat'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Placed ${formatDateTime(order.createdAt)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    const Icon(Icons.event_seat_outlined, size: 20, color: Palette.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Seat ${item.label}')),
                    Text(formatCents(item.priceCents)),
                  ],
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Divider(),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text('Total', style: Theme.of(context).textTheme.titleMedium)),
                  Text(
                    formatCents(order.totalCents),
                    key: const ValueKey('order-detail-total'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
