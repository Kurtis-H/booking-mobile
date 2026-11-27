import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import '../logic/format.dart';
import '../session.dart';
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
                if (widget.justBought)
                  Semantics(
                    liveRegion: true,
                    child: Card(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Thanks! Your order is confirmed.',
                            key: ValueKey('order-confirmation')),
                      ),
                    ),
                  ),
                Text('Placed ${formatDateTime(order.createdAt)}'),
                const SizedBox(height: 12),
                for (final item in order.items)
                  ListTile(
                    dense: true,
                    title: Text('Seat ${item.label}'),
                    trailing: Text(formatCents(item.priceCents)),
                  ),
                const Divider(),
                ListTile(
                  title: const Text('Total'),
                  trailing: Text(
                    formatCents(order.totalCents),
                    key: const ValueKey('order-detail-total'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ),
      );
}
