import 'package:flutter/material.dart';

import '../constants/asset_constant.dart';


class RCBackgroundContainer extends StatelessWidget {
  const RCBackgroundContainer({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      width: double.infinity,
      decoration: const BoxDecoration(
          image: DecorationImage(
              fit: BoxFit.fill,
              image: AssetImage(ImageAssetPath.logo_bg))),
      child: child,
    );
  }
}
