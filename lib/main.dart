import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:royalcaters/src/bloc/auth/auth_bloc.dart';
import 'package:royalcaters/src/bloc/order/order_bloc.dart';
import 'package:royalcaters/src/bloc/user/user_bloc.dart';
import 'package:royalcaters/src/firebase/notification_service.dart';
import 'package:royalcaters/src/repositories/auth_repository.dart';
import 'package:royalcaters/src/repositories/order_repository.dart';
import 'package:royalcaters/src/repositories/user_repository.dart';
import 'package:royalcaters/src/screens/add_user/user_list_screen.dart';
import 'package:royalcaters/src/screens/auth/change_password_screen.dart';
import 'package:royalcaters/src/screens/auth/login_screen.dart';
import 'package:royalcaters/src/screens/auth/registration_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:royalcaters/src/screens/homescreen/HomeScreen.dart';
import 'package:royalcaters/src/screens/order/create_order_screen.dart';
import 'package:royalcaters/src/screens/splashscreen.dart';
import 'package:royalcaters/utils/constants/enums.dart';
import 'package:royalcaters/utils/constants/string_constant.dart';
import 'package:royalcaters/utils/pref/preference_data.dart';
import 'package:royalcaters/utils/widgets/toast.dart';
import 'package:timezone/data/latest.dart' as tz;

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPreferences.init();
  tz.initializeTimeZones();
  await Firebase.initializeApp();
  // Initialize Crashlytics
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  // Pass all uncaught errors to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final authRepository = AuthRepository();
  final userRepository = UserRepository();
  final orderRepository = OrderRepository();

  NotificationService.initialize(); // Add this line
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );

  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await authRepository.saveUserToken(user.uid); // Update token on app launch
  }

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await authRepository.saveUserToken(currentUser.uid);
    }
  });

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(authRepository: authRepository),
        ),
        BlocProvider<UserBloc>(
          create: (context) => UserBloc(userRepository: userRepository),
        ),
        BlocProvider<OrderBloc>(
          create: (context) => OrderBloc(orderRepository),
        ),
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

  @override
  void initState() {
    super.initState();
    _startSplashScreen();
  }

  Future<void> _startSplashScreen() async {
    await Future.delayed(const Duration(seconds: 2)); // Wait for 2 seconds
    await _checkUserExistence();
   // setState(() {});
  }

  Future<void> _checkUserExistence() async {
    try {
      QuerySnapshot usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      User? user = FirebaseAuth.instance.currentUser;
      bool anyUserExists = usersSnapshot.docs.isNotEmpty;

      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          // User exists in Firebase Auth but not in Firestore 'users' collection
          await FirebaseAuth.instance.signOut();
          await AppPreferences.setBool(Strings.isLloggedInPref, false);
          if(mounted) {
            SnackbarUtils.showSnackBar(context,TOASTSTYLE.INFO,"No user found. Please contact the Admin");
          }
          setState(() {
            _isUserExist = anyUserExists;
            _isLoading = false;
          });
          return; // Exit early
        } else if (userDoc.exists && userDoc['isActive'] == false ) {
          // User is deactivated
          await FirebaseAuth.instance.signOut();
          await AppPreferences.setBool(Strings.isLloggedInPref, false);
          if(mounted) {
            SnackbarUtils.showSnackBar(context,TOASTSTYLE.INFO,"Your account has been deactivated.");
          }
          setState(() {
            _isUserExist = anyUserExists;
            _isLoading = false;
          });
          return; // Exit early
        } else {
          // User is valid, update FCM token
          await AuthRepository().saveUserToken(user.uid);
        }
      }

      setState(() {
        _isUserExist = anyUserExists;
        _isLoading = false;
      });
    } catch (e) {
      print("Error checking user existence: $e");
      if(mounted) {
        SnackbarUtils.showSnackBar(context,TOASTSTYLE.INFO,"Error: $e");
      }
      setState(() => _isLoading = false);
    }
  }
 /* Future<void> _checkUserExistence() async {
      try {
        QuerySnapshot usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
        bool anyUserExists = usersSnapshot.docs.isNotEmpty;

        User? user = FirebaseAuth.instance.currentUser;
        print('user exist : $anyUserExists , $user');

        setState(() {
          if (!anyUserExists) {
            _isUserExist = false; // No users → Show Registration Screen
          } else{
            _isUserExist = true;
          }
          _isLoading = false;
        });
      } catch (e) {
        print("Error checking user existence: $e");
        setState(() {
          _isLoading = false;
        });
      }
  }*/

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _isLoading ? SplashScreen() : (_isUserExist ?
      (_isUserLoggedIn() && FirebaseAuth.instance.currentUser != null  ? HomeScreen() :LoginScreen()) : RegisterScreen()),
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/change_password': (context) => ChangePasswordScreen(),
        '/home': (context) => HomeScreen(),
        '/users': (context) => UserListScreen(),
        '/createorder': (context) => CreateOrderScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }

  bool _isUserLoggedIn() {
    return AppPreferences.getBool(Strings.isLloggedInPref);
  }
}
