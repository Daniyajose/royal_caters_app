import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../utils/constants/asset_constant.dart';
import '../../../bloc/order/order_bloc.dart';
import '../../../bloc/order/order_state.dart';
import '../widgets/order_card.dart';


class CanceledTab extends StatelessWidget {
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
          final canceledOrders = state.orders
              .where((order) => order.orderStatus == "Canceled")
              .toList();

          if (canceledOrders.isEmpty) {
            return Center(child: Text("No cancelled orders."));
          }

          return ListView.builder(
            itemCount: canceledOrders.length,
            itemBuilder: (context, index) {
              return OrderCard(order: canceledOrders[index]);
            },
          );
        }
        return Center(child: Text("No orders available."));
      },
    );
  }
}
