import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:royalcaters/utils/constants/color_constants.dart';

class RCPrimaryButton extends StatelessWidget {
  const RCPrimaryButton(
      {super.key,
      required this.onPressed,
      required this.text,
      this.width = 220,
      this.height = 50});
  final String text;
  final Function() onPressed;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      // width: double.infinity,
      // margin: const EdgeInsets.fromLTRB(60.0, 15.0, 60.0, 0.0),
      child: ElevatedButton(
        style: ButtonStyle(
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          )),
          padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
              const EdgeInsets.symmetric(horizontal: 20)),
          backgroundColor: WidgetStateProperty.all<Color>(primaryColor),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            color: white,
            letterSpacing: 0.2,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
