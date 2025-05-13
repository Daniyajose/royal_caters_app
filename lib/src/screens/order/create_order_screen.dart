import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:royalcaters/utils/constants/asset_constant.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

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
  final _numberofPaxController = TextEditingController();
  final _numberofKidsController = TextEditingController();
  final _advAmountController = TextEditingController();
  final _totalAmountController = TextEditingController();

  DateTime? _selectedDate;
  String _orderType = 'Takeaway';
  String _orderStatus = 'Upcoming';
  List<String> _images = [];
  bool _isLoading = false;
  bool _isAdmin = false;
  List<Vessel> _vessels = []; // Track vessels
  Map<String, TextEditingController> _vesselQuantityControllers = {};

  // List of available vessel names
  static const List<String> _availableVessels = [
    'Flat Tray 2 kg',
    'Flat Tray 4 kg',
    'Flat Tray 6 kg',
    'Black Box',
    'Hot Box',
    'Chafing Dish',
    'Water Tray',
  ];

  @override
  void initState() {
    super.initState();
    _checkIfAdmin();
    _populateFieldsForUpdate();
    _initializeVessels();
  }
  @override
  void dispose() {
    _clientNameController.dispose();
    _clientLocationController.dispose();
    _clientContactController.dispose();
    _orderDetailsController.dispose();
    _driverNameController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _numberofPaxController.dispose();
    _numberofKidsController.dispose();
    _advAmountController.dispose();
    _totalAmountController.dispose();
    // Dispose of vessel quantity controllers
    _vesselQuantityControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }
  Future<void> _checkIfAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          final role = doc['role'];
          _isAdmin = role == 'admin' || role == 'super_admin';
        });
      }
    }
  }

  void _populateFieldsForUpdate() {
    if (widget.order != null) {
      final order = widget.order!;
      _clientNameController.text = order.clientName;
      _clientLocationController.text = order.clientLocation;
      _clientContactController.text = order.clientContact;
      _orderDetailsController.text = order.orderDetails;
      _driverNameController.text = order.driverName ?? '';
      _dateController.text = DateFormat('dd MMMM yyyy').format(order.date);
      _timeController.text = DateFormat('HH:mm:ss').format(order.time);
      _orderType = order.orderType;
      _orderStatus = order.orderStatus;
      _images = order.images;
      _numberofPaxController.text = order.numberofPax?.toString() ?? '';
      _numberofKidsController.text = order.numberofKids?.toString() ?? '';
      _advAmountController.text = order.advAmount?.toString() ?? '';
      _totalAmountController.text = order.totalAmount?.toString() ?? '';
      _vessels = order.vessels ?? _availableVessels
          .map((name) => Vessel(name: name, isTaken: false, quantity: 0, isReturned: false))
          .toList();
      // Update quantity controllers for existing vessels
      for (var vessel in _vessels) {
        _vesselQuantityControllers[vessel.name] = TextEditingController(text: vessel.quantity.toString());
      }
    }
    print('images : ${_images.toString()}');
  }
  void _initializeVessels() {
    if (_vessels.isEmpty) {
      _vessels = _availableVessels
          .map((name) => Vessel(name: name, isTaken: false, quantity: 0, isReturned: false))
          .toList();
    }
    // Initialize quantity controllers
    for (var vessel in _vessels) {
      _vesselQuantityControllers[vessel.name] ??= TextEditingController(text: vessel.quantity.toString());
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
        numberofPax: _numberofPaxController.text.isNotEmpty
            ? int.tryParse(_numberofPaxController.text)
            : null,
        numberofKids: _numberofKidsController.text.isNotEmpty
            ? int.tryParse(_numberofKidsController.text)
            : null,
        advAmount: _isAdmin && _advAmountController.text.isNotEmpty
            ? double.tryParse(_advAmountController.text)
            : null,
        totalAmount: _isAdmin && _totalAmountController.text.isNotEmpty
            ? double.tryParse(_totalAmountController.text)
            : null,
        vessels: _vessels, //
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

  Future<bool> _requestStoragePermission() async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      SnackbarUtils.showSnackBar(
        context,
        TOASTSTYLE.ERROR,
        "Storage permission is permanently denied. Please enable it in settings.",
      );
      await openAppSettings();
      return false;
    } else {
      SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, "Storage permission denied.");
      return false;
    }
  }

  Future<void> _generateAndSavePDF() async {
    // Request storage permission
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) return;

    setState(() => _isLoading = true);

    try {
      final pdf = pw.Document();

      // Load images from URLs or local files
      final List<pw.Widget> imageWidgets = [];
      for (String image in _images) {
        if (image.startsWith("http")) {
          final response = await http.get(Uri.parse(image));
          final imageBytes = response.bodyBytes;
          imageWidgets.add(pw.Image(pw.MemoryImage(imageBytes), width: 100, height: 100));
        } else {
          final file = File(image);
          final imageBytes = await file.readAsBytes();
          imageWidgets.add(pw.Image(pw.MemoryImage(imageBytes), width: 100, height: 100));
        }
      }

      // Build vessel details for PDF
      final vesselDetails = _vessels.map((v) => pw.Text(
        '${v.name}: ${v.isTaken ? "Taken (${v.quantity} units)" : "Not Taken"}'
            '${v.isReturned && _orderStatus == "Completed" ? ", Returned" : ""}',
        style: pw.TextStyle(fontSize: 24),
      ));

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Order Details',
                style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 40),
              pw.Text('Client Name: ${widget.order?.clientName}', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 25),
              pw.Text('Client Location: ${widget.order?.clientLocation}', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 25),
              pw.Text('Client Contact: ${widget.order?.clientContact}', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 25),
              pw.Text('Date & Time: ${DateFormat('dd MMMM yyyy').format(widget.order!.date)} , ${DateFormat('HH:mm:ss a').format(widget.order!.time)}', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 25),
              pw.Text('Order Type: ${widget.order?.orderType}', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 25),
              pw.Text('Driver Name: ${widget.order?.driverName}', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 25),
              pw.Text('Number of pax: ${widget.order?.numberofPax?.toString() ?? 'N/A'}', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 25),
              pw.Text('Number of kids: ${widget.order?.numberofKids?.toString() ?? 'N/A'}', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 25),
              pw.Text('Order Details: ${widget.order?.orderDetails}', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              if (_vessels.isNotEmpty) ...[
                pw.Text('Vessels:', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                ...vesselDetails,
                pw.SizedBox(height: 20),
              ],
              pw.SizedBox(height: 40),
              if (imageWidgets.isNotEmpty) ...[
                pw.Text(
                  'Images:',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: imageWidgets,
                ),
              ],
            ],
          ),
        ),
      );

      // Save the PDF to a temporary directory
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/order_${widget.order!.id}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Open the PDF file
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, "Failed to open PDF: ${result.message}");
      }
    } catch (e) {
      print("PDF generation error: $e");
      SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, "Failed to generate PDF: $e");
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
                            const SizedBox(height: 15),
                            _vesselPickerWidget(),
                            const SizedBox(height: 15),
                            _imagePickerWidget(),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (widget.order == null || widget.order?.orderStatus == 'Upcoming')
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
     /* actions: widget.order != null
          ? [
        IconButton(
          icon: Icon(Icons.picture_as_pdf, color: white),
          onPressed: _generateAndSavePDF,
          tooltip: 'Generate PDF',
        ),
      ]
          : null,*/
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

 /* Widget _buildUpdateAndCancelButtons() {
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
*/
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
        _dateTimePickerView(),
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
        _textFieldView(_numberofPaxController, 'Number of pax', isNumeric: true, allowDecimal: false),
        const SizedBox(height: 15),
        _textFieldView(_numberofKidsController, 'Number of kids', isNumeric: true, allowDecimal: false),
        const SizedBox(height: 15),
        _textFieldView(_driverNameController, 'Driver Name',allowValidation: false),
        const SizedBox(height: 15),
        if (_isAdmin) ...[
          _textFieldView(_advAmountController, 'Advance amount', isNumeric: true),
          const SizedBox(height: 15),
          _textFieldView(_totalAmountController, 'Total amount', isNumeric: true),
        ]
      ],
    );
  }

  Widget _textFieldView(TextEditingController controller, String labelText, {
    bool showObscureText = false, bool isMultiline = false,
    bool isNumeric = false, bool allowDecimal = true, bool allowValidation = true}) {
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
          textAlignVertical: TextAlignVertical.top,
          maxLines: isMultiline ? null : 1,
          minLines: isMultiline ? 5 : 1,
          keyboardType: isNumeric
              ? TextInputType.numberWithOptions(decimal: allowDecimal)
              : isMultiline
              ? TextInputType.multiline
              : TextInputType.text,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          validator: (value) {
            if (!isNumeric && allowValidation && (value == null || value.isEmpty)) {
              return 'Required';
            }
            return null;
          },
        ),
      ],
    );
  }
  Widget _vesselPickerWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Vessels",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: primaryColor),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _vessels.length,
          itemBuilder: (context, index) {
            final vessel = _vessels[index];
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),

              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: vessel.isTaken,
                    onChanged: (value) {
                      setState(() {
                        _vessels[index] = Vessel(
                          name: vessel.name,
                          isTaken: value ?? false,
                          quantity: vessel.quantity,
                          isReturned: vessel.isReturned,
                        );
                        // Reset quantity if not taken
                        if (!(value ?? false)) {
                          _vesselQuantityControllers[vessel.name]?.text = '0';
                          _vessels[index] = Vessel(
                            name: vessel.name,
                            isTaken: false,
                            quantity: 0,
                            isReturned: false,
                          );
                        }
                      });
                    },
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Flexible(
                    child: Text(
                      vessel.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 20),
                  if (vessel.isTaken)
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 36),
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Qty',
                            labelStyle: const TextStyle(fontSize: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          style: const TextStyle(fontSize: 14),
                          keyboardType: TextInputType.number,
                          controller: _vesselQuantityControllers[vessel.name],
                          onChanged: (value) {
                            setState(() {
                              _vessels[index] = Vessel(
                                name: vessel.name,
                                isTaken: vessel.isTaken,
                                quantity: int.tryParse(value) ?? 0,
                                isReturned: vessel.isReturned,
                              );
                            });
                          },
                        ),
                      ),
                    ),
                  if (vessel.isTaken) const SizedBox(width: 8),
                  if (_isOrderPastDue() && vessel.isTaken) ...[
                    Checkbox(
                      value: vessel.isReturned,
                      onChanged: (value) {
                        setState(() {
                          _vessels[index] = Vessel(
                            name: vessel.name,
                            isTaken: vessel.isTaken,
                            quantity: vessel.quantity,
                            isReturned: value ?? false,
                          );
                        });
                      },
                    ),
                    const Text('Returned', style: TextStyle(fontSize: 14)),
                  ],
                ],
              ),
            );
          },
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
        Text("Add Images", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: primaryColor)),
        SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _images.length + 1,
          itemBuilder: (context, index) {
            if (index == _images.length) {
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Yes"),
            ),
          ],
        );
      },
    ) ?? false;
  }
/*
  Future<void> _scheduleOrderReminder(OrderModel order, String isoDateTime) async {
    final local = tz.local;
    final orderDate = tz.TZDateTime.from(order.date, local);
    final formattedDate = DateFormat('dd MMMM yyyy').format(order.date);

    const reminderHours = [6, 12, 18];

    for (int daysBefore = 7; daysBefore >= 0; daysBefore--) {
      final reminderDate = orderDate.subtract(Duration(days: daysBefore));

      if (daysBefore == 0) {
        final reminderDateTime = tz.TZDateTime(
          local,
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          6,
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
      } else if (daysBefore >= 4) {
        final reminderDateTime = tz.TZDateTime(
          local,
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          6,
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
      } else {
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

    CollectionReference notifications = FirebaseFirestore.instance.collection('scheduled_notifications');
    QuerySnapshot querySnapshot = await notifications.where('orderId', isEqualTo: order.id).get();
    for (var doc in querySnapshot.docs) {
      await notifications.doc(doc.id).update({
        'status': 'canceled',
        'canceledAt': FieldValue.serverTimestamp(),
      });
    }

    const reminderHours = [6, 12, 18];

    for (int daysBefore = 7; daysBefore >= 0; daysBefore--) {
      final reminderDate = orderDate.subtract(Duration(days: daysBefore));

      if (daysBefore == 0) {
        final reminderDateTime = tz.TZDateTime(
          local,
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          6,
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
      } else if (daysBefore >= 4) {
        final reminderDateTime = tz.TZDateTime(
          local,
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          6,
          0,
          0,
        );

        if (reminderDateTime.isAfter(tz.TZDateTime.now(local))) {
          await notifications.add({
            'orderId': order.id,
            'title': 'Order Reminder',
            'body': 'You have an order for ${order.clientName} on $formattedDate',
            'scheduledTime': reminderDateTime.toIso8601String(),
            'createdLectureAt': FieldValue.serverTimestamp(),
            'status': 'scheduled',
          });
        }
      } else {
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
  }*/

  Future<void> _scheduleOrderReminder(OrderModel order, String isoDateTime) async {
    final local = tz.local;
    final orderDate = tz.TZDateTime.from(order.date, local);
    final formattedDate = DateFormat('dd MMMM yyyy').format(order.date);

    const reminderHours = [6, 12, 18];

    for (int daysBefore = 7; daysBefore >= 0; daysBefore--) {
      final reminderDate = orderDate.subtract(Duration(days: daysBefore));

      if (daysBefore == 0 || daysBefore >= 4) {
        final reminderDateTime = tz.TZDateTime(
          local,
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          6,
          0,
          0,
        );

        if (reminderDateTime.isAfter(tz.TZDateTime.now(local))) {
          await FirebaseFirestore.instance.collection('scheduled_notifications').add({
            'orderId': order.id,
            'title': daysBefore == 0 ? 'Order Today' : 'Order Reminder',
            'body': daysBefore == 0
                ? 'Your order for ${order.clientName} is today, $formattedDate!'
                : 'You have an order for ${order.clientName} on $formattedDate',
            'scheduledTime': reminderDateTime.toIso8601String(),
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'scheduled',
          });
        }
      } else {
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

    CollectionReference notifications = FirebaseFirestore.instance.collection('scheduled_notifications');
    QuerySnapshot querySnapshot = await notifications.where('orderId', isEqualTo: order.id).get();
    for (var doc in querySnapshot.docs) {
      await notifications.doc(doc.id).update({
        'status': 'canceled',
        'canceledAt': FieldValue.serverTimestamp(),
      });
    }

    const reminderHours = [6, 12, 18];

    for (int daysBefore = 7; daysBefore >= 0; daysBefore--) {
      final reminderDate = orderDate.subtract(Duration(days: daysBefore));

      if (daysBefore == 0 || daysBefore >= 4) {
        final reminderDateTime = tz.TZDateTime(
          local,
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          6,
          0,
          0,
        );

        if (reminderDateTime.isAfter(tz.TZDateTime.now(local))) {
          await notifications.add({
            'orderId': order.id,
            'title': daysBefore == 0 ? 'Order Today' : 'Order Reminder',
            'body': daysBefore == 0
                ? 'Your order for ${order.clientName} is today, $formattedDate!'
                : 'You have an order for ${order.clientName} on $formattedDate',
            'scheduledTime': reminderDateTime.toIso8601String(),
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'scheduled',
          });
        }
      } else {
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
    CollectionReference notifications = FirebaseFirestore.instance.collection('scheduled_notifications');
    QuerySnapshot querySnapshot = await notifications.where('orderId', isEqualTo: orderId).get();

    if (querySnapshot.docs.isNotEmpty) {
      for (var doc in querySnapshot.docs) {
        await notifications.doc(doc.id).update({
          'status': 'canceled',
          'canceledAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }


  bool _isOrderPastDue() {
    if (widget.order == null) return false;
    final order = widget.order!;
    // Combine date and time into a single DateTime
    final orderDateTime = DateTime(
      order.date.year,
      order.date.month,
      order.date.day,
      order.time.hour,
      order.time.minute,
      order.time.second,
    );
    final local = tz.local;
    final tzOrderDateTime = tz.TZDateTime.from(orderDateTime, local);
    final now = tz.TZDateTime.now(local);
    return tzOrderDateTime.isBefore(now);
  }

  Future<void> _completeOrder() async {
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
        id: widget.order!.id,
        clientName: _clientNameController.text,
        clientLocation: _clientLocationController.text,
        clientContact: _clientContactController.text,
        date: localDateTime,
        time: localDateTime,
        orderDetails: _orderDetailsController.text,
        orderType: _orderType,
        driverName: _driverNameController.text,
        images: imageUrls,
        orderStatus: 'Completed', // Set status to Completed
        numberofPax: _numberofPaxController.text.isNotEmpty
            ? int.tryParse(_numberofPaxController.text)
            : null,
        numberofKids: _numberofKidsController.text.isNotEmpty
            ? int.tryParse(_numberofKidsController.text)
            : null,
        advAmount: _isAdmin && _advAmountController.text.isNotEmpty
            ? double.tryParse(_advAmountController.text)
            : null,
        totalAmount: _isAdmin && _totalAmountController.text.isNotEmpty
            ? double.tryParse(_totalAmountController.text)
            : null,
        vessels: _vessels,
      );

      context.read<OrderBloc>().add(UpdateOrderEvent(order));
      if (widget.order?.date != date) {
        await _updateOrderReminder(order, isoDateTime);
      }
    } catch (e) {
      print("Order completion error: $e");
      SnackbarUtils.showSnackBar(context, TOASTSTYLE.ERROR, "Failed to complete order: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildUpdateAndCancelButtons() {
    final isPastDue = _isOrderPastDue();
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
              onPressed: isPastDue ? _completeOrder : _createOrUpdateOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                isPastDue ? "COMPLETE ORDER" : "UPDATE ORDER",
                style: const TextStyle(fontSize: 15, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

