import 'package:flutter/material.dart';
import 'package:royalcaters/utils/constants/asset_constant.dart';
import 'package:royalcaters/utils/constants/color_constants.dart';

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      body: Center(
        child: Image.asset(
          ImageAssetPath.royalCatersLogo, // Ensure the correct path
          width: 300, // Adjust size as needed
          height: 300,
        ),
      ),
    );
  }
}
