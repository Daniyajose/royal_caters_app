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
  _CreateOrderScreenState createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientLocationController = TextEditingController();
  final TextEditingController _clientContactController = TextEditingController();
  final TextEditingController _orderDetailsController = TextEditingController();
  final TextEditingController _driverNameController = TextEditingController();
  TextEditingController _dateController = TextEditingController();
  TextEditingController _timeController = TextEditingController();

  DateTime? _selectedDate;
  String _orderType = 'Takeaway';
  String _orderStatus = 'Upcoming';
  List<String> _images = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.order != null) {
      // Populate fields for update
      _clientNameController.text = widget.order!.clientName;
      _clientLocationController.text = widget.order!.clientLocation;
      _clientContactController.text = widget.order!.clientContact;
      _orderDetailsController.text = widget.order!.orderDetails;
      _driverNameController.text = widget.order!.driverName;
      _dateController.text = DateFormat('dd MMMM yyyy').format(widget.order!.date); // Display format
      _timeController.text = DateFormat('HH:mm:ss').format(widget.order!.time); // 24-hour format
      _orderType = widget.order!.orderType;
      _orderStatus = widget.order!.orderStatus;
      _images = widget.order!.images;
    }
  }


  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      for (var pickedFile in pickedFiles) {
        setState(() {
          _images.add(pickedFile.path);
        });
      }
    }
  }

  Future<String> _uploadImage(File imageFile) async {
    try {
      String originalFileName = path.basenameWithoutExtension(imageFile.path);
      String fileExtension = path.extension(imageFile.path);
      // Create a unique file name using original name and current timestamp
      String uniqueFileName = "orders/${originalFileName}_${DateTime.now().millisecondsSinceEpoch}$fileExtension";
      Reference storageRef = FirebaseStorage.instance.ref().child(uniqueFileName);
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      return "";
    }
  }

  Future<void> _createOrder() async {
    if (_formKey.currentState!.validate() && _dateController.text.isNotEmpty && _timeController.text.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });
      try {
        // Parse date and time in local time zone
        final dateFormat = DateFormat('dd MMMM yyyy');
        final timeFormat = DateFormat('HH:mm:ss');
        final selectedDate = dateFormat.parse(_dateController.text);
        final selectedTime = timeFormat.parse(_timeController.text);
        final combinedDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
          selectedTime.second,
        );

        // Convert to UTC with local time zone offset
        final local = tz.local;
        final tzDateTime = tz.TZDateTime.from(combinedDateTime, local);
        final isoDateTime = tzDateTime.toIso8601String(); // e.g., "2025-03-31T10:00:00+05:30"

        List<String> imageUrls = [];
        // Upload only local file images. If image already starts with "http", it’s a URL.
        for (var image in _images) {
          if (image.startsWith("http")) {
            imageUrls.add(image);
          } else {
            String url = await _uploadImage(File(image));
            if (url.isNotEmpty) imageUrls.add(url);
          }
        }
        final order = OrderModel(
          id: widget.order?.id ?? Uuid().v4(),
          clientName: _clientNameController.text,
          clientLocation: _clientLocationController.text,
          clientContact: _clientContactController.text,
          date: combinedDateTime, // Local time for display
          time: combinedDateTime, // Local time for display
          orderDetails: _orderDetailsController.text,
          orderType: _orderType,
          driverName: _driverNameController.text,
          images: imageUrls,
          orderStatus: _orderStatus,
        );
        if (widget.order == null) {
          // Create new order
          if(mounted) {
            context.read<OrderBloc>().add(CreateOrderEvent(order));
          }
          await _scheduleOrderReminder(order,isoDateTime);

        } else {
          if(mounted) {
            context.read<OrderBloc>().add(UpdateOrderEvent(order));
          }
          if(widget.order?.date != selectedDate) {
            await _updateOrderReminder(order,isoDateTime);
          }
        }

      } catch (e) {
        print("Error while creating order: $e");
        setState(() {
          _isLoading = false; // Hide loader on error
        });
      }
    } else {

      SnackbarUtils.showSnackBar(context,TOASTSTYLE.ERROR, "Validation failed or date/time not selected.");
    }
  }
  Future<void> _cancelOrder() async {

    bool confirmCancel = await _showCancelConfirmationDialog();
    if (!confirmCancel) return;

    setState(() {
      _isLoading = true;
    });

    setState(() {
      _isLoading = true;
    });
    if (widget.order != null) {
      try {
        context.read<OrderBloc>().add(CancelOrderEvent(widget.order!.id));
        await _cancelOrderReminder(widget.order!.id);

      } catch (e) {
        print("Error while cancelling order: $e");
        setState(() {
          _isLoading = false; // Hide loader on error
        });
      }
    }

  }

  Future<void> _scheduleOrderReminder(OrderModel order, String isoDateTime) async {
    final local = tz.local;
    final orderDate = tz.TZDateTime.from(order.date, local); // Order date in local timezone
    final formattedDate = DateFormat('dd MMMM yyyy').format(order.date);

    // Schedule reminders from 7 days before to the order date
    for (int daysBefore = 7; daysBefore >= 0; daysBefore--) {
      final reminderDate = orderDate.subtract(Duration(days: daysBefore));
      // Set reminder time to 7 AM local time
      final reminderDateTime = tz.TZDateTime(
        local,
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        6, // 7 AM
        0,  // Minutes
        0,  // Seconds
      );

      // Only schedule if the reminder time is in the future
      if (reminderDateTime.isAfter(tz.TZDateTime.now(local))) {
        await FirebaseFirestore.instance.collection('scheduled_notifications').add({
          'orderId': order.id,
          'title': 'Order Reminder',
          'body': 'You have scheduled an order for ${order.clientName} on $formattedDate',
          'scheduledTime': reminderDateTime.toIso8601String(), // ISO 8601 with offset
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'scheduled',
        });
      }
    }
  }

  Future<void> _updateOrderReminder(OrderModel order, String isoDateTime) async {
    final local = tz.local;
    final orderDate = tz.TZDateTime.from(order.date, local);
    final formattedDate = DateFormat('dd MMMM yyyy').format(order.date);

    // Cancel existing reminders for this order
    CollectionReference notifications = FirebaseFirestore.instance.collection('scheduled_notifications');
    QuerySnapshot querySnapshot = await notifications.where('orderId', isEqualTo: order.id).get();
    for (var doc in querySnapshot.docs) {
      await notifications.doc(doc.id).update({
        'status': 'canceled',
        'canceledAt': FieldValue.serverTimestamp(),
      });
    }

    // Schedule new reminders from 7 days before to the order date
    for (int daysBefore = 7; daysBefore >= 0; daysBefore--) {
      final reminderDate = orderDate.subtract(Duration(days: daysBefore));
      final reminderDateTime = tz.TZDateTime(
        local,
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        6, // 7 AM
        0,
        0,
      );

      if (reminderDateTime.isAfter(tz.TZDateTime.now(local))) {
        await notifications.add({
          'orderId': order.id,
          'title': 'Order Reminder',
          'body': 'You have scheduled an order for ${order.clientName} on $formattedDate',
          'scheduledTime': reminderDateTime.toIso8601String(),
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'scheduled',
        });
      }
    }
  }

  Future<void> _cancelOrderReminder(String orderId) async {
    CollectionReference notifications =
    FirebaseFirestore.instance.collection('scheduled_notifications');
    QuerySnapshot querySnapshot =
    await notifications.where('orderId', isEqualTo: orderId).get();

    if (querySnapshot.docs.isNotEmpty) {
      String docId = querySnapshot.docs.first.id;
      await notifications.doc(docId).update({
        'status': 'canceled', // Mark as canceled instead of deleting
        'canceledAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderBloc, OrderState>(
      listener: (context, state) {
        if (state is OrderLoaded) {

          setState(() {
            _isLoading = false; // Hide loader on error
          });
          Navigator.pop(context, true); // Close screen and refresh HomeScreen
        } else if (state is OrderFailure) {
          setState(() {
            _isLoading = false; // Hide loader on error
          });
          SnackbarUtils.showSnackBar(context,TOASTSTYLE.ERROR, state.error);
        }
      },
      child: Stack(
        children: [
          Scaffold(
          backgroundColor: white,
          appBar: AppBar(
            backgroundColor: primaryColor,
            title: Text(widget.order == null ? 'Create Order' : 'Edit Order', style: TextStyle(color: white)),
            leading: IconButton( // Adds the back button manually
              icon: Icon(Icons.arrow_back, color: white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body:
          Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            inputFieldsWidget(),
                            _imagePickerWidget(),
                            SizedBox(height: 30,)
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Create Order button at the bottom
                  if (widget.order == null)
                  SizedBox(
                    width: double.infinity, // Make button full width
                    child: ElevatedButton(
                      onPressed: _createOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor, // Background color
                        textStyle: TextStyle(color: white, fontSize: 18, fontWeight: FontWeight.bold) ,// Text color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0), // Rounded corners
                        ),

                        padding: EdgeInsets.symmetric(vertical: 16), // Vertical padding
                        elevation: 5, // Shadow effect
                      ),
                      child: Text(
                        "CREATE ORDER",
                        style: TextStyle(
                          fontSize: 18,
                          letterSpacing: 1.0,
                          color: white,// Text size
                          fontWeight: FontWeight.normal, // Bold text
                        ),
                      ),
                    ),
                  ),
                  if (widget.order != null)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Cancel Order Button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _cancelOrder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text("CANCEL ORDER", style: TextStyle(fontSize: 15, color: Colors.white)),
                            ),
                          ),
                          SizedBox(width: 16), // Space between buttons
                          // Update Order Button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _createOrder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text("UPDATE ORDER", style: TextStyle(fontSize: 15, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),

                ],
              ),
            ),
         // ),
        ),

          if (_isLoading) // Show loader on top when loading
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5), // Semi-transparent overlay
                child: Center(
                  child: Image.asset(ImageAssetPath.spinning_loader,width: 40,height: 40,),
                ),
              ),
            ),
      ]
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
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
}
