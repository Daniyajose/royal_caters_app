import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/order_repository.dart';
import 'order_event.dart';
import 'order_state.dart';
class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderRepository orderRepository;

  OrderBloc(this.orderRepository) : super(OrderInitial()) {
    on<FetchOrdersEvent>(_onFetchOrders);
    on<CreateOrderEvent>(_onCreateOrder);
    on<UpdateOrderEvent>(_onUpdateOrder);
    on<CancelOrderEvent>(_onCancelOrder);
  }


  Future<void> _onCreateOrder(CreateOrderEvent event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      await orderRepository.createOrder(event.order);
      emit(OrderSuccess("Order created successfully!"));
      add(FetchOrdersEvent());
    } catch (e) {
      print("Order creation failed: $e");
      emit(OrderFailure(e.toString()));
    }
  }

  Future<void> _onFetchOrders(FetchOrdersEvent event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      final orders = await orderRepository.fetchOrders();
      emit(OrderLoaded(orders));
    } catch (e) {
      emit(OrderFailure(e.toString()));
    }
  }

  Future<void> _onUpdateOrder(UpdateOrderEvent event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      await orderRepository.updateOrder(event.order);
      emit(OrderSuccess("Order updated successfully!"));
      add(FetchOrdersEvent()); // Refresh list
    } catch (e) {
      emit(OrderFailure(e.toString()));
    }
  }

  Future<void> _onCancelOrder(CancelOrderEvent event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      await orderRepository.cancelOrder(event.orderId);
      emit(OrderSuccess("Order canceled successfully!"));
      add(FetchOrdersEvent()); // Refresh list
    } catch (e) {
      emit(OrderFailure(e.toString()));
    }
  }
}
