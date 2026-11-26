import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import '../logic/format.dart';
import '../session.dart';
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
              itemCount: orders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final order = orders[i];
                return ListTile(
                  key: ValueKey('order-${order.id}'),
                  title: Text('Order #${order.id}'),
                  subtitle: Text(
                    '${pluralize(order.items.length, 'seat')} · ${formatDateTime(order.createdAt)}',
                  ),
                  trailing: Text(formatCents(order.totalCents)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => OrderScreen(orderId: order.id)),
                  ),
                );
              },
            );
          },
        ),
      );
}
