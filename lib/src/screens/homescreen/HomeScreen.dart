import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:royalcaters/src/screens/homescreen/tabs/orderList.dart';
import 'package:royalcaters/src/screens/order/create_order_screen.dart';
import 'package:royalcaters/utils/constants/color_constants.dart';

import '../../../utils/constants/string_constant.dart';
import '../../../utils/pref/preference_data.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/order/order_bloc.dart';
import '../../bloc/order/order_event.dart';
import '../../model/order_model.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _initializeTabController();
    _checkIfAdmin();
    _fetchOrders();
    _startUserActiveMonitor();
  }

  void _initializeTabController() {
    _tabController = TabController(length: 3, vsync: this);
    _tabController.index = 1;
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) _fetchOrders();
    });
  }

  Future<void> _startUserActiveMonitor() async {
    while (mounted) {
      await Future.delayed(const Duration(minutes: 1));
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (!doc.exists || (doc['isActive'] == false)) {
          await _logoutAndRedirect();
          break;
        }
      }
    }
  }

  Future<void> _logoutAndRedirect() async {
    await FirebaseAuth.instance.signOut();
    await AppPreferences.setBool(Strings.isLloggedInPref, false);
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _fetchOrders() async {
    final now = DateTime.now();
    final ordersSnapshot = await FirebaseFirestore.instance.collection('orders').get();

    final orders = ordersSnapshot.docs.map((doc) {
      return OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();

    final batch = FirebaseFirestore.instance.batch();

    for (var order in orders) {
      if (order.orderStatus == "Upcoming" && order.date.isBefore(now)) {
        batch.update(
          FirebaseFirestore.instance.collection('orders').doc(order.id),
          {'orderStatus': 'Completed'},
        );
      }
    }

    await batch.commit();
    if (mounted) context.read<OrderBloc>().add(FetchOrdersEvent());
  }

  Future<void> _checkIfAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          final role = doc['role'];
          _isAdmin = role == 'admin' || role == 'super_admin';
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Orders', style: TextStyle(color: white)),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.account_circle_sharp, color: white),
              onPressed: () => Navigator.pushNamed(context, '/users'),
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: white),
            onPressed: () async => await _logoutAndRedirect(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: white,
          labelColor: white,
          unselectedLabelColor: Colors.grey[300],
          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          indicatorWeight: 3.0,
          tabs: const [
            Tab(text: "Completed"),
            Tab(text: "Upcoming"),
            Tab(text: "Cancelled"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          OrderList(status: "Completed"),
          OrderList(status: "Upcoming"),
          OrderList(status: "Canceled"),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
          );
          if (result == true) {
            _tabController.index = 1;
            _fetchOrders();
          }
        },
        child: const Icon(Icons.add, color: white),
      ),
    );
  }
}
