import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:royalcaters/utils/constants/color_constants.dart';

import '../../../../utils/constants/asset_constant.dart';
import '../../../../utils/network_service.dart';
import '../../../bloc/order/order_bloc.dart';
import '../../../bloc/order/order_event.dart';
import '../../../bloc/order/order_state.dart';
import '../widgets/order_card.dart';

class OrderList extends StatefulWidget {
  final String status;
  const OrderList({Key? key, required this.status}) : super(key: key);

  @override
  State<OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<OrderList> {
  bool _hasNetworkError = false;
  bool _isCheckingConnection = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final isConnected = await NetworkService().isConnected();
    setState(() {
      _hasNetworkError = !isConnected;
      _isCheckingConnection = false;
    });

    if (isConnected && context.mounted) {
      context.read<OrderBloc>().add(FetchOrdersEvent());
    }
  }

  Future<void> _refreshOrders() async {
    final isConnected = await NetworkService().isConnected();
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No Internet connection")),
      );
      return;
    }
    if (context.mounted) {
      context.read<OrderBloc>().add(FetchOrdersEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingConnection) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasNetworkError) {
      return _buildNoInternetUI();
    }

    return BlocBuilder<OrderBloc, OrderState>(
      builder: (context, state) {
        if (state is OrderLoading) {
          return Center(
            child: Image.asset(ImageAssetPath.spinning_loader, width: 40, height: 40),
          );
        } else if (state is OrderFailure) {
          return Center(child: Text("Error: ${state.error}"));
        } else if (state is OrderLoaded) {
          final filteredOrders = state.orders
              .where((o) => o.orderStatus == widget.status)
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

          if (filteredOrders.isEmpty) {
            return Center(child: Text("No ${widget.status} orders."));
          }

          return RefreshIndicator(
            onRefresh: _refreshOrders,
            child: ListView.builder(
              itemCount: filteredOrders.length,
              itemBuilder: (_, index) => OrderCard(order: filteredOrders[index]),
            ),
          );
        }
        return const Center(child: Text("No orders available."));
      },
    );
  }

  Widget _buildNoInternetUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "No Internet Connection!..\nPlease check your network and try again..",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
          ),
          const SizedBox(height: 10),
          IconButton(
            onPressed: () {
              setState(() => _isCheckingConnection = true);
              _checkConnectivity();
            },
            icon: const Icon(Icons.refresh, color: primaryColor, size: 40),
            tooltip: 'Retry',
          ),
        ],
      ),
    );
  }
}
