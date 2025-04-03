import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../utils/constants/asset_constant.dart';
import '../../../utils/constants/color_constants.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/constants/string_constant.dart';
import '../../../utils/pref/preference_data.dart';
import '../../../utils/widgets/toast.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/user/user_bloc.dart';
import '../../bloc/user/user_event.dart';
import '../../bloc/user/user_state.dart';
import '../../model/user_model.dart';

class UserListScreen extends StatefulWidget {
  @override
  _UserListScreenState createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  String currentUserRole = "";

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    context.read<UserBloc>().add(LoadUsers());
  }

  Future<void> _checkUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        setState(() {
          currentUserRole = userDoc['role'] ;
          print('currentUserRole $currentUserRole');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text("Users",style: TextStyle(color: white),),
        leading: IconButton( // Adds the back button manually
          icon: Icon(Icons.arrow_back, color: white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add,color: white,size: 30,),
            onPressed: () => _showAddUserDialog(context),
          ),
        ],
      ),
      body: BlocListener<UserBloc, UserState>(
        listener: (context, state) {
          if (state is UserError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          }
          if (state is UserLoaded && FirebaseAuth.instance.currentUser == null) {
            AppPreferences.setBool(Strings.isLloggedInPref, false);
            Navigator.pushReplacementNamed(context, '/login');
          }
        },
        child: BlocBuilder<UserBloc, UserState>(
          builder: (context, state) {
            if (state is UserLoading) {
              return Center(child: Image.asset(ImageAssetPath.spinning_loader, width: 40, height: 40));
            } else if (state is UserLoaded) {
              return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance.collection('pending_users').get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: Image.asset(
                          ImageAssetPath.spinning_loader,
                          width: 40, // Adjust size as needed
                          height: 40,
                        ),
                      );
                    }
                    final pendingUsers = snapshot.data!.docs.map((doc) =>
                    {
                      'email': doc.id,
                      'name': doc['name'],
                      'role': doc['role'],
                      'status': 'pending'
                    }).toList();
                    final allUsers = [
                      ...state.users.map((user) =>
                      {
                        'email': user.email,
                        'name': user.name,
                        'role': user.role,
                        'id': user.id,
                        'status': 'active'
                      }),
                      ...pendingUsers,
                    ];
                    if (allUsers.isEmpty) {
                      return Center(child: Text("No users available"));
                    }
                    return ListView.builder(
                      itemCount: allUsers.length,
                      padding: EdgeInsets.all(10),
                      // Adds some spacing around the list
                      itemBuilder: (context, index) {
                        final user = allUsers[index];
                        final isPending = user['status'] == 'pending';
                        final canDeleteActive =
                            (currentUserRole == 'super_admin' || (currentUserRole == 'admin' && user['role'] == 'staff' && user['role'] != 'super_admin'));
                       // final canDeletePending = currentUserRole == 'super_admin' || currentUserRole == 'admin';
                        return Card(
                          color: white,
                          elevation: 4,
                          // Adds shadow effect
                          margin: EdgeInsets.symmetric(
                              vertical: 8, horizontal: 5),
                          // Spacing between cards
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                5), // Rounded corners
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            // Padding inside the card
                            child: Row( // Use Row to place delete icons at the end
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // User Info Column
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user['name'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      "Role: ${user['role'] == 'super_admin' ||
                                          user['role'] == 'admin'
                                          ? 'Admin'
                                          : 'Staff'}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      "Status: ${isPending ? 'Pending' : 'Active'}",
                                      style: TextStyle(fontSize: 14, color: isPending ? Colors.orange : Colors.green),
                                    ),
                                  ],
                                ),

                                if (canDeleteActive)
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    context.read<UserBloc>().add(DeleteUser(
                                        userId: isPending? user['email']: user['id'],
                                        requesterRole: currentUserRole,isPending: isPending));

                                    // _deleteUser(user["id"]); // Call delete function
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
              );
            } else if (state is UserError) {
              return Center(child: Text("Error: ${state.message}"));
            }
            return Center(child: Text("No users available"));
          },
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    String email = "";
    String role = "staff"; // Default role

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: white,
          title: Container(child: Center(child: Text("Add User",style: TextStyle(color: primaryColor,fontSize: 24),))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                height: 10,
              ),
              _textFieldView(nameController, Strings.name),
              const SizedBox(
                height: 25,
              ),
              _textFieldView(emailController, Strings.email),
              const SizedBox(
                height: 25,
              ),
              DropdownButtonFormField<String>(
                value: role,
                onChanged: (value) => role = value ?? "staff",
                items: ["admin", "staff"].map((role) {
                  return DropdownMenuItem(value: role, child: Text(role,style: TextStyle(fontWeight: FontWeight.normal),));
                }).toList(),
                decoration: _inputDecoration("Select Role")
              ),
              const SizedBox(
                width: 10,
              ),
            ],
          ),
          actions: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text("CANCEL",style: TextStyle(color: primaryColor,fontSize: 16)),
            ),
            const SizedBox(
              width: 10,
            ),
            GestureDetector(
              onTap: () {
                if (!validateInputs(emailController,nameController)) {
                  return;
                }

                if (emailController.text.isNotEmpty && nameController.text.isNotEmpty) {
                  context.read<UserBloc>().add(AddUser(
                    email: emailController.text,
                    name: nameController.text,
                    role: role,
                    isFirstLogin: true,
                    createdBy: currentUserRole,
                    createdAt: DateTime.now().toIso8601String(),
                    deviceId: '',
                  ));
                  Navigator.pop(context);
                }
              },
              child: Text("ADD",style: TextStyle(color: primaryColor,fontSize: 16)),
            ),
            const SizedBox(
              width: 10,
            ),
          ],
        );
      },
    );
  }


  Widget _textFieldView(TextEditingController controller, String text, {bool showObscureText = false}) {
    return TextFormField(
      style: const TextStyle(color: inputTextColor, fontWeight: FontWeight.normal),
      obscureText: showObscureText,
      controller: controller,
      textAlign: TextAlign.left,
      decoration: _inputDecoration(text), // Apply same decoration
    );
  }

  /// Function to return consistent InputDecoration for both fields
  InputDecoration _inputDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(fontSize: 15, color: labelGray),
      hintStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: labelGray),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: mediumGray, width: 1.0), // Same border color
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: mediumGray, width: 1.0), // Same border color initially
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: primaryColor, width: 1.0), // Highlighted when focused
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
    );
  }

  bool validateInputs(TextEditingController emailController,TextEditingController nameController) {
    String email = emailController.text.trim();
    String name = nameController.text;

    if (email.isEmpty || name.isEmpty) {
      SnackbarUtils.showSnackBar(context,TOASTSTYLE.ERROR, "Email and Name are required!");
      return false;
    }

    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      SnackbarUtils.showSnackBar(context,TOASTSTYLE.ERROR, "Please enter a valid email address!");
      return false;
    }

    return true;
  }
}
