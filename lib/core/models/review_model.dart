class Review {
  final int id;
  final String customerName;
  final String? customerPhoto;
  final double rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.customerName,
    this.customerPhoto,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final customerData = json['customer'];
    String? photo;
    if (customerData is Map) {
      photo = customerData['profile_photo_url'];
    }
    
    return Review(
      id: json['id'],
      customerName: json['customer_name'] ?? 'ضيف',
      customerPhoto: photo,
      rating: double.parse((json['rating'] ?? 0).toString()),
      comment: json['comment'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
