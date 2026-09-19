class Barbershop {
  final int id;
  final String name;
  final String description;
  final String address;
  final String? phone;
  final String? whatsappNumber;
  final double rating;
  final String? logoUrl;
  final bool isOpen;
  final double? latitude;
  final double? longitude;
  final int currentTurnNumber;
  final Map<String, dynamic> workingHours;
  final List<String> galleryImages;
  final List<String> staffNames;

  Barbershop({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    this.phone,
    this.whatsappNumber,
    required this.rating,
    this.logoUrl,
    required this.isOpen,
    this.latitude,
    this.longitude,
    this.currentTurnNumber = 0,
    this.workingHours = const {},
    this.galleryImages = const [],
    this.staffNames = const [],
  });

  factory Barbershop.fromJson(Map<String, dynamic> json) {
    // Parse gallery images from 'images' array
    List<String> gallery = [];
    if (json['images'] != null && json['images'] is List) {
      for (var img in json['images']) {
        if (img is Map && img['image'] != null) {
          gallery.add(img['image'].toString());
        }
      }
    }

    return Barbershop(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone_number'],
      whatsappNumber: json['whatsapp_number'],
      rating: double.parse((json['average_rating'] ?? 0).toString()),
      logoUrl: json['main_photo_url'] ?? json['image'],
      isOpen: json['is_open_now'] ?? json['is_active'] ?? true,
      latitude: json['latitude'] != null ? double.parse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.parse(json['longitude'].toString()) : null,
      currentTurnNumber: json['current_turn_number'] ?? 0,
      workingHours: json['working_hours'] is Map ? Map<String, dynamic>.from(json['working_hours']) : {},
      galleryImages: gallery,
      staffNames: json['staff_names'] != null ? List<String>.from(json['staff_names']) : [],
    );
  }
}
