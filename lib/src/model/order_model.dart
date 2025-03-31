class OrderModel {
  final String id;
  final String clientName;
  final String clientLocation;
  final String clientContact;
  final DateTime date; // Keeping it as DateTime
  final DateTime time;   // Storing only the time as String (HH:mm format)
  final String orderDetails;
  final String orderType;
  final String driverName;
  final List<String> images;
  final String orderStatus;

  OrderModel({
    required this.id,
    required this.clientName,
    required this.clientLocation,
    required this.clientContact,
    required this.date,
    required this.time,
    required this.orderDetails,
    required this.orderType,
    required this.driverName,
    required this.images,
    required this.orderStatus,
  });


  OrderModel copyWith({
    String? id,
    String? clientName,
    String? clientLocation,
    String? clientContact,
    DateTime? date,
    DateTime? time,
    String? orderDetails,
    String? orderType,
    String? driverName,
    List<String>? images,
    String? orderStatus,
  }) {
    return OrderModel(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      clientLocation: clientLocation ?? this.clientLocation,
      clientContact: clientContact ?? this.clientContact,
      date: date ?? this.date,
      time: time ?? this.time,
      orderDetails: orderDetails ?? this.orderDetails,
      orderType: orderType ?? this.orderType,
      driverName: driverName ?? this.driverName,
      images: images ?? this.images,
      orderStatus: orderStatus ?? this.orderStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientName': clientName,
      'clientLocation': clientLocation,
      'clientContact': clientContact,
      'date': date.toIso8601String(),  // Fix: Correct key name
      'time': time.toIso8601String(),  // Fix: Correct key name
      'orderDetails': orderDetails,
      'orderType': orderType,
      'driverName': driverName,
      'images': images,
      'orderStatus': orderStatus,
    };
  }


  factory OrderModel.fromMap(Map<String, dynamic> map, String documentId) {
    return OrderModel(
      id: documentId,
      clientName: map['clientName'] ?? '',
      clientLocation: map['clientLocation'] ?? '',
      clientContact: map['clientContact'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(), // Fix: Safe parsing
      time: map['time'] != null ? DateTime.parse(map['time']) : DateTime.now(), // Fix: Safe parsing
      orderDetails: map['orderDetails'] ?? '',
      orderType: map['orderType'] ?? 'Takeaway',
      driverName: map['driverName'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      orderStatus: map['orderStatus'] ?? 'Pending',
    );
  }

}
