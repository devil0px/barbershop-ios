class Booking {
  final int id;
  final String status;
  final String date;
  final String time;
  final double totalPrice;
  final String barbershopName;
  final String barbershopAddress;
  final List<String> serviceList;
  final DateTime bookingDay;
  final int queueNumber;
  final int currentServingQueue;
  final int peopleAhead;
  final String? customerName;
  final String? staffName;

  Booking({
    required this.id,
    required this.status,
    required this.date,
    required this.time,
    required this.totalPrice,
    required this.barbershopName,
    required this.barbershopAddress,
    required this.serviceList,
    required this.bookingDay,
    required this.queueNumber,
    required this.currentServingQueue,
    required this.peopleAhead,
    this.customerName,
    this.staffName,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    // Handling nested barbershop object from server
    final shopData = json['barbershop'] as Map<String, dynamic>?;
    
    return Booking(
      id: json['id'] ?? 0,
      status: json['status'] ?? 'pending',
      date: json['booking_day'] ?? json['date'] ?? '',
      time: json['time'] ?? '',
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
      barbershopName: shopData?['name'] ?? json['barbershop_name'] ?? 'صالون حلاقة',
      barbershopAddress: shopData?['address'] ?? json['barbershop_address'] ?? 'غير محدد',
      serviceList: json['services_list'] != null 
          ? List<String>.from(json['services_list'])
          : (json['booking_services'] != null 
              ? List<String>.from(json['booking_services'].map((s) => s['service']?['name'] ?? 'خدمة'))
              : []),
      bookingDay: json['booking_day'] != null ? DateTime.tryParse(json['booking_day']) ?? DateTime.now() : DateTime.now(),
      queueNumber: json['queue_number'] ?? 0,
      currentServingQueue: json['current_serving_queue'] ?? 0,
      peopleAhead: json['people_ahead'] ?? 0,
      customerName: json['customer_name'],
      staffName: json['staff_name'],
    );
  }
}
