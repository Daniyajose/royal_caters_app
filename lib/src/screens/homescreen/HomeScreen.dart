import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:royalcaters/src/screens/order/create_order_screen.dart';
import 'package:royalcaters/utils/constants/color_constants.dart';

import '../../../utils/constants/string_constant.dart';
import '../../../utils/pref/preference_data.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/order/order_bloc.dart';
import '../../bloc/order/order_event.dart';
import '../../model/order_model.dart';
import '../order/tabs/canceled_tab.dart';
import '../order/tabs/completed_tab.dart';
import '../order/tabs/orderList.dart';
import '../order/tabs/upcoming_tab.dart';

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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.index = 1;
    _checkIfAdmin();
    _fetchOrders();

    // Listen for tab changes and refresh orders if needed
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _fetchOrders();
      }
    });
    _startPeriodicCheck();
  }

  Future<void> _startPeriodicCheck() async {
    while (mounted) {
      await Future.delayed(Duration(minutes: 1));
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (!userDoc.exists || (userDoc.exists && userDoc['isActive'] == false)) {
          await FirebaseAuth.instance.signOut();
          await AppPreferences.setBool(Strings.isLloggedInPref, false);
          Navigator.pushReplacementNamed(context, '/login');
          break; // Exit loop after logout
        }
      }
    }
  }


  Future<void> _fetchOrders() async {
    final currentDate = DateTime.now();
    final ordersSnapshot = await FirebaseFirestore.instance.collection('orders').get();
    final orders = ordersSnapshot.docs.map((doc) {
      return OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();

    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var order in orders) {
      if (order.orderStatus == "Upcoming" && order.date.isBefore(currentDate)) {
        batch.update(
          FirebaseFirestore.instance.collection('orders').doc(order.id),
          {'orderStatus': 'Completed'},
        );
      }
    }
    await batch.commit();
    context.read<OrderBloc>().add(FetchOrdersEvent());
  }

  Future<void> _checkIfAdmin() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        setState(() {
          _isAdmin = userDoc['role'] == 'admin' || userDoc['role'] == 'super_admin';
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
        title: Text('Orders', style: TextStyle(color: white)),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: Icon(Icons.account_circle_sharp, color: white),
              onPressed: () {
                Navigator.pushNamed(context, '/users');
              },
            ),
          IconButton(
            icon: Icon(Icons.logout, color: white),
            onPressed: () async {
              BlocProvider.of<AuthBloc>(context).add(LogoutEvent());
              await AppPreferences.setBool(Strings.isLloggedInPref, false);
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: white,
          labelColor: white,
          unselectedLabelColor: Colors.grey[300],
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
          indicatorSize: TabBarIndicatorSize.tab,
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
        children: [
         /* CompletedTab(),
          UpcomingTab(),
          CanceledTab(),*/
          OrderList(status: "Completed"),
          OrderList(status: "Upcoming"),
          OrderList(status: "Canceled"),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: ()  async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateOrderScreen()),
          );

          if (result == true) {
            _tabController.index = 1;
            _fetchOrders(); // Reload orders when coming back
          }
        },
        child: Icon(Icons.add, color: white),
      ),
    );
  }
}
