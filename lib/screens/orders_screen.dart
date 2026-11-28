import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import '../logic/format.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/status.dart';
import 'order_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  Future<List<Order>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    _future ??= session.api.listOrders(session.apiKey ?? '');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My orders')),
        body: FutureBuilder<List<Order>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error!);
            if (!snap.hasData) return const LoadingView(label: 'Loading your orders…');
            final orders = snap.data!;
            if (orders.isEmpty) {
              return const Center(child: Text("You haven't bought anything yet."));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final order = orders[i];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('order-${order.id}'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => OrderScreen(orderId: order.id)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Palette.accentSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.confirmation_number_outlined,
                                color: Palette.accent),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Order #${order.id}',
                                    style: Theme.of(context).textTheme.titleMedium),
                                Text(
                                  '${pluralize(order.items.length, 'seat')} · '
                                  '${formatDateTime(order.createdAt)}',
                                  style: const TextStyle(color: Palette.muted),
                                ),
                              ],
                            ),
                          ),
                          Text(formatCents(order.totalCents),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}
