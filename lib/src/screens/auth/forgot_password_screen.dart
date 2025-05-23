import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:royalcaters/utils/constants/color_constants.dart';

import '../../../utils/constants/asset_constant.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/constants/string_constant.dart';
import '../../../utils/pref/preference_data.dart';
import '../../../utils/widgets/rc_background.dart';
import '../../../utils/widgets/rc_primary_button.dart';
import '../../../utils/widgets/toast.dart';
import '../../bloc/auth/auth_bloc.dart';


class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  bool _isLoading = false;

  Future<bool> _isExistingUser(String email) async {
    QuerySnapshot userDocs = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    return userDocs.docs.isNotEmpty && userDocs.docs.first['isActive'] == true;
  }

  Future<void> _sendPasswordResetEmail() async {
    String email = emailController.text.trim();

    if (!validateInputs()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      bool userExists = await _isExistingUser(email);
      if (!userExists) {
        SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, "No active user found with this email.");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      SnackbarUtils.showSnackBar(context, TOASTSTYLE.SUCCESS, "Password reset email sent. Check your inbox.");
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      String errorMessage = 'Error: ${e.toString()}';
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No user found with this email.';
            break;
          case 'invalid-email':
            errorMessage = 'Please enter a valid email address.';
            break;
          default:
            errorMessage = 'Error: ${e.message}';
        }
      }
      SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool validateInputs() {
    String email = emailController.text.trim();

    if (email.isEmpty) {
      SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, "Email is required!");
      return false;
    }

    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, "Please enter a valid email address!");
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: RCBackgroundContainer(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 600,
                ),
                child: Card(
                  color: white,
                  elevation: 10.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 5),
                        Image.asset(ImageAssetPath.royalCatersLogo, height: 140, width: 140),
                        const SizedBox(height: 16),
                        const Text(
                          "Reset Password",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 30),
                        _textFieldView(emailController, Strings.email),
                        const SizedBox(height: 30),
                        _isLoading
                            ? Center(
                          child: Image.asset(
                            ImageAssetPath.spinning_loader,
                            width: 50,
                            height: 50,
                          ),
                        )
                            : AbsorbPointer(
                          absorbing: _isLoading,
                          child: Opacity(
                            opacity: _isLoading ? 0.5 : 1.0,
                            child: RCPrimaryButton(
                              onPressed: _sendPasswordResetEmail,
                              text: "Send Reset Link",
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          child: const Text(
                            "Back to Login",
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textFieldView(TextEditingController controller, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          height: 45,
          alignment: Alignment.center,
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: white,
          ),
          child: TextFormField(
            style: const TextStyle(color: inputTextColor, fontSize: 15),
            controller: controller,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              labelStyle: const TextStyle(fontSize: 16, color: inputTextColor),
              hintText: text,
              hintStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.normal,
                color: labelGray,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: mediumGray, width: 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: mediumGray, width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: labelGray, width: 1.0),
                borderRadius: BorderRadius.circular(5.0),
              ),
            ),
          ),
        ),
      ],
    );
  }
}