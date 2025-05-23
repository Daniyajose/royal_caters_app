import 'dart:ffi';

class OrderModel {
  final String id;
  final String orderNumber;
  final String clientName;
  final String clientLocation;
  final String clientContact;
  final DateTime date; // Keeping it as DateTime
  final DateTime time;   // Storing only the time as String (HH:mm format)
  final String scheduledTime;
  final String orderDetails;
  final String orderType;
  final String? driverName;
  final List<String> images;
  final String orderStatus;
  final int? numberofPax;
  final int? numberofKids;
  final double? advAmount;
  final double? totalAmount;
  final List<Vessel>? vessels;
  final String? responseId;
  final String? contactPersonName;
  final String? contactPersonNumber;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.clientName,
    required this.clientLocation,
    required this.clientContact,
    required this.date,
    required this.time,
    required this.scheduledTime,
    required this.orderDetails,
    required this.orderType,
    required this.driverName,
    required this.images,
    required this.orderStatus,
    this.numberofPax,
    this.numberofKids,
    this.advAmount,
    this.totalAmount,
    this.vessels,
    this.responseId,
    this.contactPersonName,
    this.contactPersonNumber,
  });


  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? clientName,
    String? clientLocation,
    String? clientContact,
    DateTime? date,
    DateTime? time,
    String? scheduledTime,
    String? orderDetails,
    String? orderType,
    String? driverName,
    List<String>? images,
    String? orderStatus,
    int? numberofPax,
    int? numberofKids,
    double? advAmount,
    double? totalAmount,
    List<Vessel>? vessels,
    String? responseId,
    String? contactPersonName,
    String? contactPersonNumber,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      clientName: clientName ?? this.clientName,
      clientLocation: clientLocation ?? this.clientLocation,
      clientContact: clientContact ?? this.clientContact,
      date: date ?? this.date,
      time: time ?? this.time,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      orderDetails: orderDetails ?? this.orderDetails,
      orderType: orderType ?? this.orderType,
      driverName: driverName ?? this.driverName,
      images: images ?? this.images,
      orderStatus: orderStatus ?? this.orderStatus,
      numberofPax: numberofPax ?? this.numberofPax,
      numberofKids: numberofKids ?? this.numberofKids,
      advAmount: advAmount ?? this.advAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      vessels: vessels ?? this.vessels,
      responseId: responseId ?? this.responseId,
      contactPersonName: contactPersonName ?? this.contactPersonName,
      contactPersonNumber: contactPersonNumber ?? this.contactPersonNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'clientName': clientName,
      'clientLocation': clientLocation,
      'clientContact': clientContact,
      'date': date.toIso8601String(),  // Fix: Correct key name
      'time': time.toIso8601String(),  // Fix: Correct key name
      'scheduledTime': scheduledTime,  // Fix: Correct key name
      'orderDetails': orderDetails,
      'orderType': orderType,
      'driverName': driverName,
      'images': images,
      'orderStatus': orderStatus,
      'numberofPax': numberofPax,
      'numberofKids': numberofKids,
      'advAmount': advAmount,
      'totalAmount': totalAmount,
      'vessels': vessels?.map((v) => v.toMap()).toList(),
      'responseId': responseId,
      'contactPersonName': contactPersonName,
      'contactPersonNumber': contactPersonNumber,
    };
  }


  factory OrderModel.fromMap(Map<String, dynamic> map, String documentId) {
    return OrderModel(
      id: documentId,
      orderNumber: map['orderNumber'] ?? '',
      clientName: map['clientName'] ?? '',
      clientLocation: map['clientLocation'] ?? '',
      clientContact: map['clientContact'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(), // Fix: Safe parsing
      time: map['time'] != null ? DateTime.parse(map['time']) : DateTime.now(), // Fix: Safe parsing
      scheduledTime: map['scheduledTime'] ?? '',
      orderDetails: map['orderDetails'] ?? '',
      orderType: map['orderType'] ?? 'Takeaway',
      driverName: map['driverName'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      orderStatus: map['orderStatus'] ?? 'Pending',
      numberofPax: map['numberofPax'] != null ? (map['numberofPax'] as num?)?.toInt() : null,
      numberofKids: map['numberofKids'] != null ? (map['numberofKids'] as num?)?.toInt() : null,
      advAmount: map['advAmount'] != null ? (map['advAmount'] as num?)?.toDouble() : null,
      totalAmount: map['totalAmount'] != null ? (map['totalAmount'] as num?)?.toDouble() : null,
      vessels: (map['vessels'] as List<dynamic>?)?.map((v) => Vessel.fromMap(v)).toList(),
      responseId: map['responseId'],
      contactPersonName: map['contactPersonName'],
      contactPersonNumber: map['contactPersonNumber'],
    );
  }

}
class Vessel {
  final String name;
  final bool isTaken;
  final int quantity;
  final bool isReturned;

  Vessel({
    required this.name,
    this.isTaken = false,
    this.quantity = 0,
    this.isReturned = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isTaken': isTaken,
      'quantity': quantity,
      'isReturned': isReturned,
    };
  }

  factory Vessel.fromMap(Map<String, dynamic> map) {
    return Vessel(
      name: map['name'] ?? '',
      isTaken: map['isTaken'] ?? false,
      quantity: map['quantity'] ?? 0,
      isReturned: map['isReturned'] ?? false,
    );
  }
}