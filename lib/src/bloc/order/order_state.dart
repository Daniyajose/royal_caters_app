import 'package:equatable/equatable.dart';

import '../../model/order_model.dart';

abstract class OrderState extends Equatable {
  @override
  List<Object?> get props => [];
}

class OrderInitial extends OrderState {}

class OrderLoading extends OrderState {}

class OrderSuccess extends OrderState {
  final String message;
  OrderSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class OrderFailure extends OrderState {
  final String error;

  OrderFailure(this.error);

  @override
  List<Object?> get props => [error];
}

class OrderLoaded extends OrderState {
  final List<OrderModel> orders;

  OrderLoaded(this.orders);

  @override
  List<Object?> get props => [orders];
}


