class Staff {
  final int id;
  final String fullName;
  final String? role;
  final String? photoUrl;
  final bool isAvailable;
  final int currentTurnNumber;
  final int bookingsCountToday;
  final int bookingsCountMonth;
  final int bookingsCountYear;

  Staff({
    required this.id,
    required this.fullName,
    this.role,
    this.photoUrl,
    this.isAvailable = true,
    this.currentTurnNumber = 0,
    this.bookingsCountToday = 0,
    this.bookingsCountMonth = 0,
    this.bookingsCountYear = 0,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'],
      fullName: json['name'] ?? '',
      role: json['role_display'] ?? json['role'] ?? '',
      photoUrl: json['photo'],
      isAvailable: json['is_available'] ?? true,
      currentTurnNumber: json['current_turn_number'] ?? 0,
      bookingsCountToday: json['bookings_count_today'] ?? 0,
      bookingsCountMonth: json['bookings_count_month'] ?? 0,
      bookingsCountYear: json['bookings_count_year'] ?? 0,
    );
  }
}
