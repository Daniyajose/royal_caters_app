import 'package:cloud_firestore/cloud_firestore.dart';
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

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Check if the user exists and is active in the 'users' collection
  Future<bool> _isExistingUser(String email) async {
    QuerySnapshot userDocs = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    if (userDocs.docs.isEmpty) return false;
    return userDocs.docs.first['isActive'] == true;
  }

  // Check if the user exists in the 'pending_users' collection
  Future<bool> _isPendingUser(String email) async {
    DocumentSnapshot pendingUserDoc = await FirebaseFirestore.instance
        .collection('pending_users')
        .doc(email)
        .get();
    return pendingUserDoc.exists;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is AuthAuthenticated) {
            if (state.isFirstLogin) {
              Navigator.pushReplacementNamed(context, '/change_password');
            } else {
              await AppPreferences.setBool(Strings.isLloggedInPref, true);
              Navigator.pushReplacementNamed(context, '/home');
            }
          } else if (state is AuthError) {
            SnackbarUtils.showSnackBar(context,TOASTSTYLE.ERROR,state.message);
          }
        },
        child: RCBackgroundContainer(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: SingleChildScrollView( // Ensures content is centered and not stretched
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 500, // Limits width of the card
                    maxHeight: 650, // Limits height of the card
                  ),
                  child: Card(
                    color: white,
                    elevation: 10.0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0), // Prevents content from touching edges
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // Limits column size to required space
                        children: [
                          const SizedBox(height: 8),
                          Image.asset(ImageAssetPath.royalCatersLogo, height: 160,width: 160,),
                          const SizedBox(height: 30),
                          inputFieldsWidget(),
                          RCPrimaryButton(
                            onPressed: () async {
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
                              // Check if the user exists in 'users' or 'pending_users'
                              final isExisting = await _isExistingUser(emailController.text);
                              final isPending = await _isPendingUser(emailController.text);

                              if (isExisting) {
                                // User exists in 'users' collection, attempt login
                               if(context.mounted) {
                                 BlocProvider.of<AuthBloc>(context).add(LoginEvent(emailController.text, passwordController.text),
                                );
                               }
                               setState(() {
                                 _isLoading = false;
                               });
                              } else if (isPending) {
                                // User exists in 'pending_users', attempt registration
                                if(context.mounted) {
                                  BlocProvider.of<AuthBloc>(context).add(
                                    RegisterPendingEvent(
                                      emailController.text,
                                      passwordController.text,
                                      '',
                                    ),
                                  );
                                }
                                setState(() {
                                  _isLoading = false;
                                });
                              } else {
                                // User doesn't exist in either collection
                                if(mounted) {
                                  SnackbarUtils.showSnackBar(context,TOASTSTYLE.ERROR, "No account found with this email. Please contact an admin.");
                                }
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            },
                            text: Strings.login,
                          ),
                          const SizedBox(height: 20),
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
        _textFieldView(emailController, Strings.email),
        const SizedBox(
          height: 10,
        ),
        _textFieldView(passwordController, Strings.password,
            isPasswordField: true),
        const SizedBox(
          height: 30,
        ),
      ],
    );
  }

  Widget _textFieldView(controller, text, {bool isPasswordField = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Text(text),
        Container(
          height: 45,
          alignment: Alignment.center,
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          decoration: BoxDecoration(
            borderRadius: (BorderRadius.circular(5)),
            color: white,
          ),
          child: Stack(
            alignment: Alignment.centerRight, // Ensures toggle icon stays right without affecting text
            children: [ TextFormField(
              style: const TextStyle(color: inputTextColor, fontSize: 15),
              obscureText: isPasswordField ? _obscurePassword: false,
              controller: controller,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                labelStyle: const TextStyle(fontSize: 16, color: inputTextColor),
                hintText: text,
                hintStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.normal,
                    color: labelGray),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide:  const BorderSide(color: mediumGray, width: 1.0),
                ),
                enabledBorder: OutlineInputBorder(  // 👈 Add this to set the default border color
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: mediumGray, width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: labelGray, width: 1.0),
                  borderRadius: BorderRadius.circular(5.0),
                ),

              ),
              // validator: MultiValidator([
              //   RequiredValidator(errorText: Strings.pleaseEnterValidCred),
              // ]
            ),
              if (isPasswordField)
                Positioned(
                  right: 2, // Keep it properly aligned
                  child: IconButton(
                    icon: Icon(
                      ( _obscurePassword)
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: labelGray,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                          _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
           ]
          ),
        ),
      ],
    );
  }
  bool validateInputs() {
    String email = emailController.text.trim();
    String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      SnackbarUtils.showSnackBar(context,TOASTSTYLE.ERROR, "Email and Password are required!");
      return false;
    }

    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      SnackbarUtils.showSnackBar(context,TOASTSTYLE.ERROR, "Please enter a valid email address!");
      return false;
    }

    return true;
  }

}
