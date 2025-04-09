import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:royalcaters/utils/network_service.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'package:royalcaters/src/firebase/notification_service.dart';
import 'package:royalcaters/src/repositories/auth_repository.dart';
import 'package:royalcaters/src/repositories/user_repository.dart';
import 'package:royalcaters/src/repositories/order_repository.dart';
import 'package:royalcaters/src/bloc/auth/auth_bloc.dart';
import 'package:royalcaters/src/bloc/user/user_bloc.dart';
import 'package:royalcaters/src/bloc/order/order_bloc.dart';
import 'package:royalcaters/utils/constants/string_constant.dart';
import 'package:royalcaters/utils/constants/color_constants.dart';
import 'package:royalcaters/utils/constants/enums.dart';
import 'package:royalcaters/utils/pref/preference_data.dart';
import 'package:royalcaters/utils/widgets/toast.dart';
import 'package:royalcaters/src/screens/splashscreen.dart';
import 'package:royalcaters/src/screens/network_error_screen.dart';
import 'package:royalcaters/src/screens/auth/login_screen.dart';
import 'package:royalcaters/src/screens/auth/registration_screen.dart';
import 'package:royalcaters/src/screens/auth/change_password_screen.dart';
import 'package:royalcaters/src/screens/add_user/user_list_screen.dart';
import 'package:royalcaters/src/screens/homescreen/HomeScreen.dart';
import 'package:royalcaters/src/screens/order/create_order_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: \${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPreferences.init();
  tz.initializeTimeZones();
  await Firebase.initializeApp();
  NetworkService().initialize();
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  NotificationService.initialize();
  await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

  final authRepository = AuthRepository();
  final userRepository = UserRepository();
  final orderRepository = OrderRepository();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc(authRepository: authRepository)),
        BlocProvider(create: (_) => UserBloc(userRepository: userRepository)),
        BlocProvider(create: (_) => OrderBloc(orderRepository)),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isUserExist = false;
  bool _isLoading = true;
  bool _hasNetworkError = false;
  bool _needsPasswordChange = false;

  @override
  void initState() {
    super.initState();
    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    await Future.delayed(const Duration(seconds: 2));
    await _initializeApp();
  }

  Future<void> _initializeApp() async {
    final networkAvailable =  await NetworkService().isConnected();

    if (!networkAvailable) {
      setState(() {
        _hasNetworkError = true;
        _isLoading = false;
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await AuthRepository().saveUserToken(user.uid);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await AuthRepository().saveUserToken(user.uid);
      }
    });

    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (!userDoc.exists || userDoc['isActive'] == false) {
          await FirebaseAuth.instance.signOut();
          await AppPreferences.setBool(Strings.isLloggedInPref, false);
          SnackbarUtils.showSnackBar(context, TOASTSTYLE.INFO, userDoc.exists ? "Your account has been deactivated." : "No user found. Please contact the Admin");
        }else {
          // Check if the user needs to change their password
          _needsPasswordChange = userDoc['isFirstLogin'] == true;
        }
      }

      setState(() {
        _isUserExist = snapshot.docs.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasNetworkError = true;
        _isLoading = false;
      });
    }
  }

  bool _isUserLoggedIn() {
    return AppPreferences.getBool(Strings.isLloggedInPref);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Royal Caters',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
        fontFamily: "Roboto",
        useMaterial3: true,
      ),
      home: _isLoading
          ? SplashScreen()
          : _hasNetworkError
          ? NetworkErrorScreen(
        onRetry: () {
          setState(() {
            _isLoading = true;
            _hasNetworkError = false;
          });
          _startSplashSequence();
        },
      )
          : _isUserExist
          ? (_isUserLoggedIn() && FirebaseAuth.instance.currentUser != null
          ?(_needsPasswordChange ? ChangePasswordScreen() : HomeScreen())
          : LoginScreen())
          : RegisterScreen(),
      routes: {
        '/login': (_) => LoginScreen(),
        '/register': (_) => RegisterScreen(),
        '/change_password': (_) => ChangePasswordScreen(),
        '/home': (_) => HomeScreen(),
        '/users': (_) => UserListScreen(),
        '/createorder': (_) => CreateOrderScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
