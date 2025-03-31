import 'package:equatable/equatable.dart';

import '../../model/order_model.dart';

abstract class OrderEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class CreateOrderEvent extends OrderEvent {
  final OrderModel order;

  CreateOrderEvent(this.order);

  @override
  List<Object?> get props => [order];
}

class FetchOrdersEvent extends OrderEvent {}

class UpdateOrderEvent extends OrderEvent {
  final OrderModel order;
  UpdateOrderEvent(this.order);
  @override
  List<Object?> get props => [order];
}

class CancelOrderEvent extends OrderEvent {
  final String orderId;
  CancelOrderEvent(this.orderId);
  @override
  List<Object?> get props => [orderId];
}

