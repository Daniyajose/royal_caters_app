import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:royalcaters/utils/constants/asset_constant.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

import '../../../utils/constants/color_constants.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/network_service.dart';
import '../../../utils/widgets/toast.dart';
import '../../bloc/order/order_bloc.dart';
import '../../bloc/order/order_event.dart';
import '../../bloc/order/order_state.dart';
import '../../firebase/notification_service.dart';
import '../../model/order_model.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key, this.order});
  final OrderModel? order;

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _clientLocationController = TextEditingController();
  final _clientContactController = TextEditingController();
  final _orderDetailsController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  DateTime? _selectedDate;
  String _orderType = 'Takeaway';
  String _orderStatus = 'Upcoming';
  List<String> _images = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _populateFieldsForUpdate();
  }

  void _populateFieldsForUpdate() {
    if (widget.order != null) {
      final order = widget.order!;
      _clientNameController.text = order.clientName;
      _clientLocationController.text = order.clientLocation;
      _clientContactController.text = order.clientContact;
      _orderDetailsController.text = order.orderDetails;
      _driverNameController.text = order.driverName;
      _dateController.text = DateFormat('dd MMMM yyyy').format(order.date);
      _timeController.text = DateFormat('HH:mm:ss').format(order.time);
      _orderType = order.orderType;
      _orderStatus = order.orderStatus;
      _images = order.images;
    }
  }

  Future<void> _pickImages() async {
    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      setState(() {
        _images.addAll(pickedFiles.map((file) => file.path));
      });
    }
  }

  Future<String> _uploadImage(File imageFile) async {
    try {
      final fileName = path.basenameWithoutExtension(imageFile.path);
      final ext = path.extension(imageFile.path);
      final uniqueName = 'orders/${fileName}_${DateTime.now().millisecondsSinceEpoch}$ext';
      final storageRef = FirebaseStorage.instance.ref().child(uniqueName);
      final snapshot = await storageRef.putFile(imageFile);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Upload error: $e");
      return "";
    }
  }

  Future<void> _createOrUpdateOrder() async {
    final isConnected = await NetworkService().isConnected();
    if (!isConnected) {
      SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, "No network connection.");
      return;
    }

    if (!_formKey.currentState!.validate() || _dateController.text.isEmpty || _timeController.text.isEmpty) {
      SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, "Validation failed or missing date/time.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final date = DateFormat('dd MMMM yyyy').parse(_dateController.text);
      final time = DateFormat('HH:mm:ss').parse(_timeController.text);
      final localDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute, time.second);
      final tzDateTime = tz.TZDateTime.from(localDateTime, tz.local);
      final isoDateTime = tzDateTime.toIso8601String();

      final imageUrls = await Future.wait(_images.map((image) async {
        return image.startsWith("http") ? image : await _uploadImage(File(image));
      }));

      final order = OrderModel(
        id: widget.order?.id ?? Uuid().v4(),
        clientName: _clientNameController.text,
        clientLocation: _clientLocationController.text,
        clientContact: _clientContactController.text,
        date: localDateTime,
        time: localDateTime,
        orderDetails: _orderDetailsController.text,
        orderType: _orderType,
        driverName: _driverNameController.text,
        images: imageUrls,
        orderStatus: _orderStatus,
      );

      final bloc = context.read<OrderBloc>();

      if (widget.order == null) {
        bloc.add(CreateOrderEvent(order));
        await _scheduleOrderReminder(order, isoDateTime);
      } else {
        bloc.add(UpdateOrderEvent(order));
        if (widget.order?.date != date) {
          await _updateOrderReminder(order, isoDateTime);
        }
      }
    } catch (e) {
      print("Order creation error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelOrder() async {
    final isConnected = await NetworkService().isConnected();
    if (!isConnected) {
      SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, "No network connection.");
      return;
    }

    final confirm = await _showCancelConfirmationDialog();
    if (!confirm || widget.order == null) return;

    setState(() => _isLoading = true);

    try {
      context.read<OrderBloc>().add(CancelOrderEvent(widget.order!.id));
      await _cancelOrderReminder(widget.order!.id);
    } catch (e) {
      print("Order cancel error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderBloc, OrderState>(
      listener: (context, state) {
        if (state is OrderLoaded || state is OrderFailure) {
          setState(() => _isLoading = false);
          if (state is OrderLoaded) Navigator.pop(context, true);
          if (state is OrderFailure) SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, state.error);
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: white,
            appBar: _buildAppBar(),
            body: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            inputFieldsWidget(),
                            _imagePickerWidget(),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: Center(
                  child: Image.asset(ImageAssetPath.spinning_loader, width: 40, height: 40),
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primaryColor,
      title: Text(widget.order == null ? 'Create Order' : 'Edit Order', style: TextStyle(color: white)),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (widget.order == null) {
      return _buildCreateButton();
    } else {
      return _buildUpdateAndCancelButtons();
    }
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _createOrUpdateOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Text("CREATE ORDER", style: TextStyle(fontSize: 18, color: white)),
      ),
    );
  }

  Widget _buildUpdateAndCancelButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _cancelOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("CANCEL ORDER", style: TextStyle(fontSize: 15, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _createOrUpdateOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("UPDATE ORDER", style: TextStyle(fontSize: 15, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget inputFieldsWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _textFieldView(_clientNameController, 'Client Name'),
        const SizedBox(height: 15),
        _textFieldView(_clientLocationController, 'Client Location'),
        const SizedBox(height: 15),
        _textFieldView(_clientContactController, 'Client Phone/Email'),
        const SizedBox(height: 15),
        _textFieldView(_orderDetailsController, 'Order Details', isMultiline: true),
        const SizedBox(height: 15),
        _dateTimePickerView(), // Date & Time Picker
        const SizedBox(height: 15),
        Row(
          children: ["Takeaway", "Delivery"].map((type) {
            return Row(
              children: [
                Radio<String>(
                  value: type,
                  groupValue: _orderType,
                  onChanged: (val) => setState(() => _orderType = val!),
                ),
                Text(type),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        _textFieldView(_driverNameController, 'Driver Name'),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _textFieldView(TextEditingController controller, String labelText, {
    bool showObscureText = false, bool isMultiline = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            labelText,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: primaryColor),
          ),
        ),
        TextFormField(
          style: const TextStyle(color: Colors.black, fontSize: 15),
          obscureText: showObscureText,
          controller: controller,
          textAlign: TextAlign.start,
          textAlignVertical: TextAlignVertical.top, // Align text from the top
          maxLines: isMultiline ? null : 1, // Allows multiple lines if `isMultiline` is true
          minLines: isMultiline ? 5 : 1, // Minimum lines for better spacing
          keyboardType: isMultiline ? TextInputType.multiline : TextInputType.text,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), // Adjusted padding
            hintText: 'Enter $labelText',
            hintStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal, color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: Colors.grey, width: 0.6),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: Colors.grey, width: 0.6),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: primaryColor, width: 0.6),
              borderRadius: BorderRadius.circular(5.0),
            ),
          ),
          validator: (value) => value!.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }


  Widget _dateTimePickerView() {

    return Row(
      children: [
        Expanded(
          child: _pickerFieldView(
            controller: _dateController,
            labelText: "Select Date",
            icon: Icons.calendar_today,
            onTap: (context) async {
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2101),
              );
              if (pickedDate != null) {
                setState(() {
                  _selectedDate = pickedDate;
                  _dateController.text = DateFormat('dd MMMM yyyy').format(pickedDate);

                });

              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _pickerFieldView(
            controller: _timeController,
            labelText: "Select Time",
            icon: Icons.access_time,
            onTap: (context) async {
              TimeOfDay? pickedTime = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (pickedTime != null) {
                setState(() {
                  final now = DateTime.now();
                  final formattedTime = DateTime(now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);
                  _timeController.text = DateFormat('HH:mm:ss').format(formattedTime);
                });

              }
            },
          ),
        ),
      ],
    );
  }

  /// **Reusable Picker Field View**
  Widget _pickerFieldView({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required Function(BuildContext) onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 0.0, bottom: 4.0),
          child: Text(
            labelText,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: primaryColor),
          ),
        ),
        InkWell(
          onTap: () => onTap(context),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 0),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: Colors.white,
              border: Border.all(color: Colors.grey, width: 0.6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? 'Select' : controller.text,
                    style: const TextStyle(fontSize: 15, color: Colors.black),
                  ),
                ),
                Icon(icon, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePickerWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text("Add Images", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: primaryColor)),

        SizedBox(height: 10),

        // Image Grid + Add Button
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // 3 images per row
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _images.length + 1, // +1 for the "Add Image" button
          itemBuilder: (context, index) {
            if (index == _images.length) {
              // Add Image Button
              return GestureDetector(
                onTap: _pickImages,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 30, color: Colors.grey.shade600),
                      SizedBox(height: 5),
                      Text("Add Image", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
              );
            }

            // Determine if the image is a local file or a Firebase URL
            bool isUrl = _images[index].startsWith("http");

            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: isUrl
                      ? Image.network(_images[index], width: 100, height: 100, fit: BoxFit.cover)
                      : Image.file(File(_images[index]), width: 100, height: 100, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: GestureDetector(
                    onTap: () => setState(() => _images.removeAt(index)),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<bool> _showCancelConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Cancel Order"),
          content: const Text("Are you sure you want to cancel this order? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Dismiss without canceling
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // Proceed with cancellation
              child: const Text("Yes"),
            ),
          ],
        );
      },
    ) ?? false; // Return false if dialog is dismissed
  }

  Future<void> _scheduleOrderReminder(OrderModel order, String isoDateTime) async {
    final local = tz.local;
    final orderDate = tz.TZDateTime.from(order.date, local); // Order date in local timezone
    final formattedDate = DateFormat('dd MMMM yyyy').format(order.date);

    // Define notification times for the last 3 days (excluding order date)
    const reminderHours = [6, 12, 18]; // 6 AM, 12 PM, 6 PM

    // Schedule reminders from 7 days before to the order date
    for (int daysBefore = 7; daysBefore >= 0; daysBefore--) {
      final reminderDate = orderDate.subtract(Duration(days: daysBefore));

      // For the order date (daysBefore == 0), only schedule at 6 AM
      if (daysBefore == 0) {
        final reminderDateTime = tz.TZDateTime(
          local,
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          6, // 6 AM only
          0,
          0,
        );

        if (reminderDateTime.isAfter(tz.TZDateTime.now(local))) {
          await FirebaseFirestore.instance.collection('scheduled_notifications').add({
            'orderId': order.id,
            'title': 'Order Today',
            'body': 'Your order for ${order.clientName} is today, $formattedDate!',
            'scheduledTime': reminderDateTime.toIso8601String(),
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'scheduled',
          });
        }
      }
      // For days 7 to 4 before, schedule only at 6 AM
      else if (daysBefore >= 4) {
        final reminderDateTime = tz.TZDateTime(
          local,
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          6, // 6 AM
          0,
          0,
        );

        if (reminderDateTime.isAfter(tz.TZDateTime.now(local))) {
          await FirebaseFirestore.instance.collection('scheduled_notifications').add({
            'orderId': order.id,
            'title': 'Order Reminder',
            'body': 'You have an order for ${order.clientName} on $formattedDate',
            'scheduledTime': reminderDateTime.toIso8601String(),
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'scheduled',
          });
        }
      }
      // For days 3 to 1 before, schedule at 6 AM, 12 PM, and 6 PM
      else {
        for (int hour in reminderHours) {
          final reminderDateTime = tz.TZDateTime(
            local,
            reminderDate.year,
            reminderDate.month,
            reminderDate.day,
            hour,
            0,
            0,
          );

          if (reminderDateTime.isAfter(tz.TZDateTime.now(local))) {
            await FirebaseFirestore.instance.collection('scheduled_notifications').add({
              'orderId': order.id,
              'title': 'Order Reminder',
              'body': 'Upcoming order for ${order.clientName} on $formattedDate at ${DateFormat('hh:mm a').format(reminderDateTime)}',
              'scheduledTime': reminderDateTime.toIso8601String(),
              'createdAt': FieldValue.serverTimestamp(),
              'status': 'scheduled',
            });
          }
        }
      }
    }
  }

  Future<void> _updateOrderReminder(OrderModel order, String isoDateTime) async {
    final local = tz.local;
    final orderDate = tz.TZDateTime.from(order.date, local);
    final formattedDate = DateFormat('dd MMMM yyyy').format(order.date);

    // Cancel existing reminders
    CollectionReference notifications = FirebaseFirestore.instance.collection('scheduled_notifications');
    QuerySnapshot querySnapshot = await notifications.where('orderId', isEqualTo: order.id).get();
    for (var doc in querySnapshot.docs) {
      await notifications.doc(doc.id).update({
        'status': 'canceled',
        'canceledAt': FieldValue.serverTimestamp(),
      });
    }

    // Define notification times for the last 3 days (excluding order date)
    const reminderHours = [6, 12, 18]; // 6 AM, 12 PM, 6 PM

    // Schedule new reminders
    for (int daysBefore = 7; daysBefore >= 0; daysBefore--) {
      final reminderDate = orderDate.subtract(Duration(days: daysBefore));

      // For the order date (daysBefore == 0), only schedule at 6 AM
      if (daysBefore == 0) {
        final reminderDateTime = tz.TZDateTime(
          local,
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          6, // 6 AM only
          0,
          0,
        );

        if (reminderDateTime.isAfter(tz.TZDateTime.now(local))) {
          await notifications.add({
            'orderId': order.id,
            'title': 'Order Today',
            'body': 'Your order for ${order.clientName} is today, $formattedDate!',
            'scheduledTime': reminderDateTime.toIso8601String(),
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'scheduled',
          });
        }
      }
      // For days 7 to 4 before, schedule only at 6 AM
      else if (daysBefore >= 4) {
        final reminderDateTime = tz.TZDateTime(
          local,
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          6, // 6 AM
          0,
          0,
        );

        if (reminderDateTime.isAfter(tz.TZDateTime.now(local))) {
          await notifications.add({
            'orderId': order.id,
            'title': 'Order Reminder',
            'body': 'You have an order for ${order.clientName} on $formattedDate',
            'scheduledTime': reminderDateTime.toIso8601String(),
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'scheduled',
          });
        }
      }
      // For days 3 to 1 before, schedule at 6 AM, 12 PM, and 6 PM
      else {
        for (int hour in reminderHours) {
          final reminderDateTime = tz.TZDateTime(
            local,
            reminderDate.year,
            reminderDate.month,
            reminderDate.day,
            hour,
            0,
            0,
          );

          if (reminderDateTime.isAfter(tz.TZDateTime.now(local))) {
            await notifications.add({
              'orderId': order.id,
              'title': 'Order Reminder',
              'body': 'Upcoming order for ${order.clientName} on $formattedDate at ${DateFormat('hh:mm a').format(reminderDateTime)}',
              'scheduledTime': reminderDateTime.toIso8601String(),
              'createdAt': FieldValue.serverTimestamp(),
              'status': 'scheduled',
            });
          }
        }
      }
    }
  }

  Future<void> _cancelOrderReminder(String orderId) async {
    CollectionReference notifications =
    FirebaseFirestore.instance.collection('scheduled_notifications');
    QuerySnapshot querySnapshot =
    await notifications.where('orderId', isEqualTo: orderId).get();

    // Cancel all matching notifications
    if (querySnapshot.docs.isNotEmpty) {
      for (var doc in querySnapshot.docs) {
        await notifications.doc(doc.id).update({
          'status': 'canceled',
          'canceledAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

}
