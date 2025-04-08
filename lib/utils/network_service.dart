import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _networkStatusController = StreamController<bool>.broadcast();

  Stream<bool> get networkStatusStream => _networkStatusController.stream;

  void initialize() {
    _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      _networkStatusController.add(isConnected);
    });

    // Initial check
    _connectivity.checkConnectivity().then((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      _networkStatusController.add(isConnected);
    });
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }


  Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return _isConnected(result);
  }

  void dispose() {
    _networkStatusController.close();
  }
}
