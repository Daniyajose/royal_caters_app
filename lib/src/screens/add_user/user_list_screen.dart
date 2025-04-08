import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../utils/constants/asset_constant.dart';
import '../../../utils/constants/color_constants.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/constants/string_constant.dart';
import '../../../utils/network_service.dart';
import '../../../utils/pref/preference_data.dart';
import '../../../utils/widgets/toast.dart';
import '../../bloc/user/user_bloc.dart';
import '../../bloc/user/user_event.dart';
import '../../bloc/user/user_state.dart';

class UserListScreen extends StatefulWidget {
  @override
  _UserListScreenState createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  String currentUserRole = "";

  @override
  void initState() {
    super.initState();
    _checkNetworkAndLoad();
  }

  Future<void> _checkNetworkAndLoad() async {
    final isConnected = await NetworkService().isConnected();
    if (isConnected && context.mounted) {
      await _checkUserRole();
      context.read<UserBloc>().add(LoadUsers());
    } else {
      SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, "No internet connection.");
    }
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() => currentUserRole = doc['role']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      appBar: _buildAppBar(context),
      body: BlocListener<UserBloc, UserState>(
        listener: (context, state) {
          if (state is UserError) {
            SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, state.message);
          }
        },
        child: BlocBuilder<UserBloc, UserState>(
          builder: (context, state) {
            if (state is UserLoading) {
              return _buildLoader();
            } else if (state is UserLoaded) {
              return _buildUserList(state);
            } else if (state is UserError) {
              return Center(child: Text("Error: ${state.message}"));
            }
            return Center(child: Text("No users available"));
          },
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: primaryColor,
      title: const Text("Users", style: TextStyle(color: white)),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.add, color: white, size: 30),
          onPressed: () => _showAddUserDialog(context),
        ),
      ],
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Image.asset(ImageAssetPath.spinning_loader, width: 40, height: 40),
    );
  }

  Widget _buildUserList(UserLoaded state) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('pending_users').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoader();

        final pendingUsers = snapshot.data!.docs.map((doc) => {
          'email': doc.id,
          'name': doc['name'],
          'role': doc['role'],
          'status': 'pending'
        }).toList();

        final allUsers = [
          ...state.users.map((u) => {
            'email': u.email,
            'name': u.name,
            'role': u.role,
            'id': u.id,
            'status': 'active'
          }),
          ...pendingUsers,
        ];

        if (allUsers.isEmpty) return Center(child: Text("No users available"));

        return ListView.builder(
          padding: EdgeInsets.all(10),
          itemCount: allUsers.length,
          itemBuilder: (context, index) => _buildUserCard(allUsers[index]),
        );
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isPending = user['status'] == 'pending';
    final canDeleteActive =
    (currentUserRole == 'super_admin' ||
        (currentUserRole == 'admin' && user['role'] == 'staff'));

    return Card(
      color: white,
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildUserInfo(user, isPending),
            if (canDeleteActive)
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  context.read<UserBloc>().add(DeleteUser(
                    userId: isPending ? user['email'] : user['id'],
                    requesterRole: currentUserRole,
                    isPending: isPending,
                  ));
                },
              ),
          ],
        ),
      ),
    );
  }

  Column _buildUserInfo(Map<String, dynamic> user, bool isPending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user['name'],
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        SizedBox(height: 5),
        Text(
          "Role: ${user['role'] == 'super_admin' || user['role'] == 'admin' ? 'Admin' : 'Staff'}",
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        SizedBox(height: 5),
        Text(
          "Status: ${isPending ? 'Pending' : 'Active'}",
          style: TextStyle(fontSize: 14, color: isPending ? Colors.orange : Colors.green),
        ),
      ],
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String role = "staff";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: white,
        title: Center(child: Text("Add User", style: TextStyle(color: primaryColor, fontSize: 24))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10),
            _textFieldView(nameController, Strings.name),
            SizedBox(height: 25),
            _textFieldView(emailController, Strings.email),
            SizedBox(height: 25),
            DropdownButtonFormField<String>(
              value: role,
              onChanged: (value) => role = value ?? "staff",
              items: ["admin", "staff"]
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              decoration: _inputDecoration("Select Role"),
            ),
          ],
        ),
        actions: [
          _dialogAction("CANCEL", () => Navigator.pop(context)),
          _dialogAction("ADD", () {
            FocusScope.of(context).unfocus();
            if (!validateInputs(emailController, nameController)) return;

            context.read<UserBloc>().add(AddUser(
              email: emailController.text.trim(),
              name: nameController.text.trim(),
              role: role,
              isFirstLogin: true,
              createdBy: currentUserRole,
              createdAt: DateTime.now().toIso8601String(),
              deviceId: '',
            ));
            Navigator.pop(context);
          }),
        ],
      ),
    );
  }

  Widget _dialogAction(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Text(text, style: TextStyle(color: primaryColor, fontSize: 16)),
      ),
    );
  }

  Widget _textFieldView(TextEditingController controller, String label, {bool obscure = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: inputTextColor),
      decoration: _inputDecoration(label),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 15, color: labelGray),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: mediumGray, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: primaryColor, width: 1.0),
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
    );
  }

  bool validateInputs(TextEditingController emailCtrl, TextEditingController nameCtrl) {
    final email = emailCtrl.text.trim();
    final name = nameCtrl.text.trim();

    if (email.isEmpty || name.isEmpty) {
      SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, "Email and Name are required!");
      return false;
    }

    final emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
    if (!RegExp(emailPattern).hasMatch(email)) {
      SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, "Please enter a valid email address!");
      return false;
    }

    return true;
  }
}
