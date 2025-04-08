import 'package:flutter/material.dart';

class NetworkErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const NetworkErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 50, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              "No Internet Connection",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Please check your network and try again",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              child: Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}