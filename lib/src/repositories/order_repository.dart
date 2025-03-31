import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/order_model.dart';

class OrderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createOrder(OrderModel order) async {
    await _firestore.collection('orders').doc(order.id).set(order.toMap());
  }
  Future<List<OrderModel>> fetchOrders() async {
    QuerySnapshot snapshot = await _firestore.collection('orders').get();

    return snapshot.docs.map((doc) {
      return OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }
  Future<void> updateOrder(OrderModel order) async {
    await _firestore.collection('orders').doc(order.id).update(order.toMap());
  }
  Future<void> cancelOrder(String orderId) async {
    await _firestore.collection('orders').doc(orderId).update({
      'orderStatus': 'Canceled',
    });
  }
}
