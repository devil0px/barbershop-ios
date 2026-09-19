class BarberService {
  final int id;
  final String name;
  final String description;
  final double price;
  final int duration;
  final String? imageUrl;

  BarberService({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.duration,
    this.imageUrl,
  });

  factory BarberService.fromJson(Map<String, dynamic> json) {
    return BarberService(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      price: double.parse(json['price'].toString()),
      duration: json['duration'],
      imageUrl: json['image'] ?? (json['images'] != null && json['images'].isNotEmpty 
          ? json['images'][0]['image'] 
          : null),
    );
  }
}
