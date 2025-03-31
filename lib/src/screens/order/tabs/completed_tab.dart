import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:royalcaters/src/bloc/order/order_event.dart';
import '../../../../utils/constants/asset_constant.dart';
import '../../../bloc/order/order_bloc.dart';
import '../../../bloc/order/order_state.dart';
import '../../../repositories/order_repository.dart';
import '../widgets/orders_tab.dart';

class CompletedTab extends StatelessWidget {
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
          final completedOrders = state.orders
              .where((order) => order.orderStatus == "Completed")
              .toList();

          if (completedOrders.isEmpty) {
            return Center(child: Text("No completed orders."));
          }

          return ListView.builder(
            itemCount: completedOrders.length,
            itemBuilder: (context, index) {
              return OrderCard(order: completedOrders[index]);
            },
          );
        }
        return Center(child: Text("No orders available."));
      },
    );
  }
}
