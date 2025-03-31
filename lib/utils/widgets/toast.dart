import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../constants/enums.dart';
class SnackbarUtils {

  static void showSnackBar(BuildContext context,TOASTSTYLE? style,  String message) {

    var backgroundColor = Colors.lightBlue.shade800;
    switch (style ?? TOASTSTYLE.ERROR) {
      case TOASTSTYLE.SUCCESS:
        {
          backgroundColor = Colors.green.shade600;
        }
        break;
      case TOASTSTYLE.ERROR:
        {
          backgroundColor = Colors.red.shade600;
        }
        break;
      case TOASTSTYLE.INFO:
        {
          backgroundColor = Colors.lightBlue.shade800;
        }
        break;
      case TOASTSTYLE.WARN:
        {
          backgroundColor = Colors.orange.shade800;
        }
        break;
    }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}