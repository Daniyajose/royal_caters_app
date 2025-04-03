import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../utils/constants/asset_constant.dart';
import '../../../utils/constants/color_constants.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/constants/string_constant.dart';
import '../../../utils/pref/preference_data.dart';
import '../../../utils/widgets/rc_background.dart';
import '../../../utils/widgets/rc_primary_button.dart';
import '../../../utils/widgets/toast.dart';

class ChangePasswordScreen extends StatefulWidget {
  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  void _changePassword() async {
    FocusScope.of(context).unfocus();

    if (_passwordController.text != _confirmPasswordController.text) {
      SnackbarUtils.showSnackBar(context,TOASTSTYLE.ERROR,'Passwords do not match!');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update password in Firebase Auth
        await user.updatePassword(_passwordController.text);
        // Update Firestore to set `needsPasswordChange = false`
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'isFirstLogin': false,
        });

        SnackbarUtils.showSnackBar(context,TOASTSTYLE.SUCCESS,'Password changed successfully!');
       await AppPreferences.setBool(Strings.isLloggedInPref, true);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      SnackbarUtils.showSnackBar(context,TOASTSTYLE.ERROR,'Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: RCBackgroundContainer(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView( // Ensures content is centered and not stretched
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500, // Limits width of the card
                  maxHeight: 500, // Limits height of the card
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
                        Image.asset(ImageAssetPath.royalCatersLogo, height: 140,width: 140,),
                        const SizedBox(height: 16),
                        const Text(Strings.changePassword,style: TextStyle(color: primaryColor, fontSize: 24, fontWeight: FontWeight.w600),),
                        const SizedBox(height: 30),
                        inputFieldsWidget(),
                        _isLoading
                            ? Center(
                          child: Image.asset(
                            ImageAssetPath.spinning_loader,
                            width: 50, // Adjust size as needed
                            height: 50,
                          ),
                        )
                            : RCPrimaryButton(
                          onPressed: () =>_changePassword(),
                          text: Strings.updatePassword,
                        ),
                        const SizedBox(height: 40),
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

  Widget inputFieldsWidget() {
    return Column(
      children: [
        _textFieldView(_passwordController, Strings.newPassword,isPasswordField: true),
        const SizedBox(
          height: 10,
        ),
        _textFieldView(_confirmPasswordController, Strings.confirmPassword,
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
            alignment: Alignment.centerRight,
            children: [
              TextFormField(
              style: const TextStyle(color: inputTextColor, fontSize: 15),
              obscureText: isPasswordField
                  ? (text == Strings.newPassword ? _obscurePassword : _obscureConfirmPassword)
                  : false,
              controller: controller,

              textAlign: TextAlign.center,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
                      (text == Strings.newPassword ? _obscurePassword : _obscureConfirmPassword)
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: labelGray,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        if (text == Strings.newPassword) {
                          _obscurePassword = !_obscurePassword;
                        } else {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        }
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

}
