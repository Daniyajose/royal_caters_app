import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:royalcaters/utils/constants/color_constants.dart';

import '../../../utils/constants/asset_constant.dart';
import '../../../utils/network_service.dart';
import '../../bloc/order/order_bloc.dart';
import '../../bloc/order/order_event.dart';
import '../../bloc/order/order_state.dart';
import 'widgets/order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart'; // For formatting dates

import 'package:path/path.dart' as path;
import 'package:pdf/widgets.dart' as pw;

class OrderList extends StatefulWidget {
  final String status;
  const OrderList({Key? key, required this.status}) : super(key: key);

  @override
  State<OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<OrderList> {
  bool _hasNetworkError = false;
  bool _isCheckingConnection = true;
  String _searchQuery = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final isConnected = await NetworkService().isConnected();
    setState(() {
      _hasNetworkError = !isConnected;
      _isCheckingConnection = false;
    });

    if (isConnected && context.mounted) {
      context.read<OrderBloc>().add(FetchOrdersEvent());
    }
  }

  Future<void> _refreshOrders() async {
    final isConnected = await NetworkService().isConnected();
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No Internet connection")),
      );
      return;
    }
    if (context.mounted) {
      context.read<OrderBloc>().add(FetchOrdersEvent());
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingConnection) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasNetworkError) {
      return _buildNoInternetUI();
    }

    return BlocBuilder<OrderBloc, OrderState>(
        builder: (context, state) {
          // Check if there are orders
          bool hasOrders = state is OrderLoaded &&
              state.orders.any((order) => order.orderStatus == widget.status);
      return Column(
        children: [
         if(hasOrders)
          Padding(
            padding: const EdgeInsets.only(left:12.0 ,top: 10.0, right: 4.0,bottom: 10.0),
            child: SizedBox(
              height: 50,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                        hintText: 'Search by name or contact',
                        hintStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.normal, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(width: 1.0, color: Colors.grey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(width: 1.0, color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(width: 1.0, color: primaryColor),
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  IconButton(
                    icon:Image.asset(ImageAssetPath.filter, height: 25,width: 25,color: primaryColor,),
                    onPressed: _showFilterDialog,
                    tooltip: 'Filter by Date',
                  ),
                  IconButton(
                    icon: Icon(Icons.picture_as_pdf, color: primaryColor, size: 25,),
                    onPressed: _showPDFDatePicker,
                    tooltip: 'Generate PDF',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<OrderBloc, OrderState>(
              builder: (context, state) {
                if (state is OrderLoading) {
                  return Center(
                    child: Image.asset(
                      ImageAssetPath.spinning_loader,
                      width: 40,
                      height: 40,
                    ),
                  );
                } else if (state is OrderFailure) {
                  return Center(child: Text("Error: ${state.error}"));
                } else if (state is OrderLoaded) {
                  final filteredOrders = state.orders
                      .where((order) {
                    // Status filter
                    bool matchesStatus = order.orderStatus == widget.status;

                    // Search filter
                    bool matchesSearch = _searchQuery.isEmpty ||
                        order.clientName.toLowerCase().contains(_searchQuery) ||
                        order.clientContact.toLowerCase().contains(_searchQuery);

                    // Date filter
                    bool matchesDate = true;
                    if (_fromDate != null) {
                      final fromDateStart = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
                      final orderDate = DateTime(order.date.year, order.date.month, order.date.day);
                      matchesDate = orderDate.isAfter(fromDateStart.subtract(const Duration(days: 1)));
                      if (_toDate != null) {
                        final toDateEnd = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
                        matchesDate = matchesDate && (orderDate.isBefore(toDateEnd.add(const Duration(seconds: 1))) || orderDate.isAtSameMomentAs(toDateEnd));
                      }
                    }

                    return matchesStatus && matchesSearch && matchesDate;
                  })
                      .toList()
                    ..sort((a, b) => a.date.compareTo(b.date));
                  if (filteredOrders.isEmpty) {
                    return Center(child: Text("No ${widget.status} orders."));
                  }

                  return RefreshIndicator(
                    onRefresh: _refreshOrders,
                    child: ListView.builder(
                      itemCount: filteredOrders.length,
                      itemBuilder: (_, index) => OrderCard(order: filteredOrders[index]),
                    ),
                  );
                }
                return const Center(child: Text("No orders available."));
              },
            ),
          ),
        ],
      );
     },
    );
  }

  Widget _buildNoInternetUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "No Internet Connection!..\nPlease check your network and try again..",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
          ),
          const SizedBox(height: 10),
          IconButton(
            onPressed: () {
              setState(() => _isCheckingConnection = true);
              _checkConnectivity();
            },
            icon: const Icon(Icons.refresh, color: Colors.blue, size: 40),
            tooltip: 'Retry',
          ),
        ],
      ),
    );
  }


  void _showFilterDialog() {
    DateTime? tempFromDate = _fromDate;
    DateTime? tempToDate = _toDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isValidFilter() {
              if (tempFromDate == null && tempToDate != null) {
                return false; // To date only is not allowed
              }
              if (tempFromDate != null && tempToDate != null) {
                return !tempToDate!.isBefore(tempFromDate!); // To date must not be before From date
              }
              return true; // From date only or no dates are valid
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              elevation: 8.0,
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Text(
                            'Filter by Date',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey.shade800),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20.0),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0,right: 4.0),
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: tempFromDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: primaryColor,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: primaryColor,
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setDialogState(() {
                              tempFromDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: primaryColor, size: 18.0),
                              const SizedBox(width: 12.0),
                              Text(
                                tempFromDate == null
                                    ? 'Select From Date'
                                    : 'From: ${DateFormat('dd MMMM, yyyy').format(tempFromDate!)}',
                                style: TextStyle(
                                  color: tempFromDate == null ? Colors.grey : primaryColor,
                                  fontSize: 15.0,
                                  fontWeight: tempFromDate == null ? FontWeight.normal : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15.0),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0,right: 4.0),
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: tempToDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: primaryColor,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: primaryColor,
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setDialogState(() {
                              tempToDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: primaryColor, size: 18.0),
                              const SizedBox(width: 12.0),
                              Text(
                                tempToDate == null
                                    ? 'Select To Date'
                                    : 'To :  ${DateFormat('dd MMMM, yyyy').format(tempToDate!)}',
                                style: TextStyle(
                                  color: tempToDate == null ? Colors.grey : primaryColor,
                                  fontSize: 15.0,
                                  fontWeight: tempToDate == null ? FontWeight.normal : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0,right: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: ()
                            {
                              setState(() {
                                _fromDate = null;
                                _toDate = null;
                              });
                              setDialogState(() {
                                tempFromDate = null;
                                tempToDate = null;
                              });
                             // Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              backgroundColor: Colors.grey.shade200,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14.0),
                          ElevatedButton(
                            onPressed: () {
                              if (isValidFilter()) {
                                setState(() {
                                  _fromDate = tempFromDate;
                                  _toDate = tempToDate;
                                });
                                Navigator.pop(context);
                              } else {
                                String errorMessage;
                                if (tempFromDate == null && tempToDate != null) {
                                  errorMessage = "From date is required when To date is set";
                                } else {
                                  errorMessage = "To date cannot be before From date";
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMessage),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  void _showPDFDatePicker() {
    showDialog(
      context: context,
      builder: (context) {
        DateTime? selectedDate;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              elevation: 8.0,
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Text(
                            'Select Date for PDF',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey.shade800),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20.0),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0, right: 4.0),
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: primaryColor,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: primaryColor,
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 14.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  color: primaryColor, size: 18.0),
                              const SizedBox(width: 12.0),
                              Text(
                                selectedDate == null
                                    ? 'Select Date'
                                    : 'Date: ${DateFormat('dd MMMM, yyyy').format(selectedDate!)}',
                                style: TextStyle(
                                  color:
                                  selectedDate == null ? Colors.grey : primaryColor,
                                  fontSize: 15.0,
                                  fontWeight: selectedDate == null
                                      ? FontWeight.normal
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              backgroundColor: Colors.grey.shade200,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0, vertical: 10.0),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14.0),
                          ElevatedButton(
                            onPressed: selectedDate == null
                                ? null
                                : () {
                              Navigator.pop(context);
                              _generateAndShowPDF(selectedDate!);
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0, vertical: 10.0),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Generate',
                              style: TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  Future<void> _generateAndShowPDF(DateTime selectedDate) async {
    try {
      // Get orders for the selected date
      final state = context.read<OrderBloc>().state;
      if (state is! OrderLoaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No orders available to generate PDF")),
        );
        return;
      }

      final orders = state.orders.where((order) {
        final orderDate =
        DateTime(order.date.year, order.date.month, order.date.day);
        final selected =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        return orderDate.isAtSameMomentAs(selected);
      }).toList();

      if (orders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "No orders found for ${DateFormat('dd MMMM, yyyy').format(selectedDate)}")),
        );
        return;
      }

      // Create PDF document
      final pdf = pw.Document();

      // Add a page with a table of orders
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Order Report - ${DateFormat('dd MMMM, yyyy').format(selectedDate)}',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(5),
                  },

                  children: [
                    // Header row
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          child: pw.Text(
                            'Client Name',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          child: pw.Text(
                            'Client Location',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          child: pw.Text(
                            'Time',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          child: pw.Text(
                            'Order Details',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    // Data rows
                    ...orders.map((order) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            child: pw.Text(order.clientName),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            child: pw.Text(order.clientLocation),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            child: pw.Text(DateFormat('hh:mm a').format(order.time)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            child: pw.Text(order.orderDetails),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Save PDF to temporary file
      final tempDir = await getTemporaryDirectory();
      final pdfPath = '${tempDir.path}/orders_report.pdf';
      final pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(await pdf.save());

      // Open PDF in device's default PDF viewer
      final result = await OpenFile.open(pdfPath);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error opening PDF: ${result.message}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error generating PDF: $e")),
      );
    }
  }
}