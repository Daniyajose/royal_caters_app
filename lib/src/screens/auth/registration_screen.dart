import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:royalcaters/utils/constants/enums.dart';

import '../../../utils/constants/asset_constant.dart';
import '../../../utils/constants/color_constants.dart';
import '../../../utils/constants/string_constant.dart';
import '../../../utils/pref/preference_data.dart';
import '../../../utils/widgets/rc_background.dart';
import '../../../utils/widgets/rc_primary_button.dart';
import '../../../utils/widgets/toast.dart';
import '../../bloc/auth/auth_bloc.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is AuthRegistered) {
            Navigator.pushReplacementNamed(context, '/login');
          } else if (state is AuthError) {
            SnackbarUtils.showSnackBar(context,TOASTSTYLE.ERROR,state.message);
          }
        },
        child: RCBackgroundContainer(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 500, // Limits width of the card
                    maxHeight: 600, // Limits height of the card
                  ),
                  child: Card(
                    color: white,
                    elevation: 10.0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0), // Prevents content from touching edges
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // Limits column size to required space
                        children: [
                          const SizedBox(height: 5),
                          Image.asset(ImageAssetPath.royalCatersLogo, height: 160,width: 160,),
                          const SizedBox(height: 20),
                          inputFieldsWidget(),
                          RCPrimaryButton(
                            onPressed: () {
                              FocusScope.of(context).unfocus();

                              setState(() {
                                _isLoading =  true;
                              });

                              if (!validateInputs()) {
                                setState(() {
                                  _isLoading = false;
                                });
                                return;
                              }

                              BlocProvider.of<AuthBloc>(context).add(
                                RegisterEvent(
                                  emailController.text,
                                  passwordController.text,
                                  nameController.text,
                                  "super_admin",
                                  false,
                                  "super_admin",
                                  DateTime.now().toIso8601String(),
                                  '',
                                ),
                              );
                              setState(() {
                                _isLoading =  false;
                              });
                            },
                            text: Strings.signup,
                          ),
                          const SizedBox(height: 30),
                          if(_isLoading)
                            Center(
                              child: Image.asset(
                                ImageAssetPath.spinning_loader,
                                width: 40, // Adjust size as needed
                                height: 40,
                              ),
                            ),
                          if(_isLoading)
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
      ),
    );
  }

  Widget inputFieldsWidget() {
    return Column(
      children: [
        _textFieldView(nameController, Strings.name),
        const SizedBox(height: 5),
        _textFieldView(emailController, Strings.email),
        const SizedBox(height: 5),
        _textFieldView(passwordController, Strings.password, isPasswordField: true),
        const SizedBox(height: 5),
        _textFieldView(_confirmPasswordController, Strings.confirmPassword,  isPasswordField: true),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _textFieldView(
      TextEditingController controller,
      String text,
      {bool isPasswordField = false}
      ) {
    return Column(
      children: <Widget>[
        Container(
          height: 50,
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: white,
          ),
          child: Stack(
            alignment: Alignment.centerRight, // Ensures toggle icon stays right without affecting text
            children: [
              TextFormField(
                style: const TextStyle(color: inputTextColor, fontSize: 15),
                obscureText: isPasswordField
                    ? (text == Strings.password ? _obscurePassword : _obscureConfirmPassword)
                    : false,
                controller: controller,
                textAlign: TextAlign.center, // Keep text perfectly centered
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 12), // Adjust vertical padding
                  hintText: text,
                  hintStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal, color: labelGray),
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
              if (isPasswordField)
                Positioned(
                  right: 2, // Keep it properly aligned
                  child: IconButton(
                    icon: Icon(
                      (text == Strings.password ? _obscurePassword : _obscureConfirmPassword)
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: labelGray,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        if (text == Strings.password) {
                          _obscurePassword = !_obscurePassword;
                        } else {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        }
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }


  bool validateInputs() {
    String name = nameController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text;
    String confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      SnackbarUtils.showSnackBar(context,TOASTSTYLE.ERROR, "All fields are required!");
      return false;
    }

    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      SnackbarUtils.showSnackBar(context,TOASTSTYLE.ERROR, "Please enter a valid email address!");
      return false;
    }

    if (password.length < 6) {
      SnackbarUtils.showSnackBar(context,TOASTSTYLE.ERROR, "Password must be at least 6 characters long!");
      return false;
    }

    if (password != confirmPassword) {
      SnackbarUtils.showSnackBar(context,TOASTSTYLE.ERROR, "Passwords do not match!");
      return false;
    }

    return true;
  }


}
