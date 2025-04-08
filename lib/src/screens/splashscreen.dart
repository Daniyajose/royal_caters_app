import 'package:flutter/material.dart';
import 'package:royalcaters/utils/constants/asset_constant.dart';

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Image.asset(
                  ImageAssetPath.royalCatersLogo,
                  width: 300,
                  height: 300,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


