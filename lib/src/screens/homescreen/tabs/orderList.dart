import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../utils/constants/asset_constant.dart';
import '../../../bloc/order/order_bloc.dart';
import '../../../bloc/order/order_event.dart';
import '../../../bloc/order/order_state.dart';
import '../widgets/orders_tab.dart';


class OrderList extends StatelessWidget {
  final String status;

  const OrderList({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderBloc, OrderState>(
      builder: (context, state) {
        if (state is OrderLoading) {
          return Center(
            child: Image.asset(
              ImageAssetPath.spinning_loader,
              width: 40, // Adjust size as needed
              height: 40,
            ),
          );
        } else if (state is OrderFailure) {
          return Center(child: Text("Error: ${state.error}"));
        } else if (state is OrderLoaded) {
          final filteredOrders =
          state.orders.where((order) => order.orderStatus == status).toList();

          if (filteredOrders.isEmpty) {
            return Center(child: Text("No $status orders."));
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<OrderBloc>().add(FetchOrdersEvent());
            },
            child: ListView.builder(
              itemCount: filteredOrders.length,
              itemBuilder: (context, index) {
                return OrderCard(order: filteredOrders[index]);
              },
            ),
          );
        }
        return Center(child: Text("No orders available."));
      },
    );
  }
}
