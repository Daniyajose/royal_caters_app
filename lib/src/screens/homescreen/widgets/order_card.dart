import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../utils/constants/color_constants.dart';
import '../../../bloc/order/order_bloc.dart';
import '../../../bloc/order/order_event.dart';
import '../../../model/order_model.dart';
import '../../order/create_order_screen.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;

  const OrderCard({Key? key, required this.order}) : super(key: key);

  bool _isOrderPastDue() {
    final orderDateTime = DateTime(
      order.date.year,
      order.date.month,
      order.date.day,
      order.time.hour,
      order.time.minute,
      order.time.second,
    );
    final location = tz.getLocation('Europe/Dublin');
    final tzOrderDateTime = tz.TZDateTime.from(orderDateTime, location);
    final now = tz.TZDateTime.now(location);
    return tzOrderDateTime.isBefore(now) && order.orderStatus == 'Upcoming';
  }

  @override
  Widget build(BuildContext context) {
    // Format date and time
    String formattedDateTime = DateFormat('MMMM dd, yyyy • hh:mm a').format(order.date);
    final isPastDue = _isOrderPastDue();

    return GestureDetector(
      onTap: ()  async {
          final result = await Navigator.push(
            context, // Use stored context
            MaterialPageRoute(
                builder: (context) => CreateOrderScreen(order: order)),
          );

          if (result == true &&
              context.mounted) { // Check if the context is still mounted
            context.read<OrderBloc>().add(
                FetchOrdersEvent()); // Safely refresh orders
          }

      },
      child: Card(
        color: white,
        elevation: 4,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPastDue)
                Container(
                  width: 4,
                  color: Colors.orange.shade800,
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Date-Time in the same row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          Expanded(
                            child: Text(
                              '${order.orderNumber}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            formattedDateTime,
                            style: TextStyle(fontSize: 15, color: black),
                          ),
                        ],
                      ),
                      Divider(
                        color: Colors.grey.shade300,
                        thickness: 1.0,
                      ),
                      SizedBox(height: 5),
                      // Name and Date-Time in the same row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          Expanded(
                            child: Text(
                              '${order.clientName}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            order.clientContact,
                            style: TextStyle(fontSize: 15, color: Colors.black),
                          ),
                        ],
                      ),
                      SizedBox(height: 5),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Location: ${order.clientLocation}',
                              style: TextStyle(fontSize: 15, color: Colors.black),
                            ),
                          ),
                          Text(
                            order.orderType,
                            style: TextStyle(fontSize: 15, color: (order.orderType == 'Takeaway')? Colors.green: Colors.red),
                          ),

                        ],
                      ),
                      SizedBox(height: 6),

                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );


  }

}
