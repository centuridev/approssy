class Service {
  final String name;
  final String price;
  final int duration;
  final String image;
  final String category;

  Service({
    required this.name,
    required this.price,
    required this.duration,
    required this.image,
    required this.category,
  });

  factory Service.fromFirestore(Map<String, dynamic> data) {
    return Service(
      name: data['name'] ?? '',
      price: data['price'] ?? '',
      duration: data['duration'] ?? 0,
      image: data['image'] ?? '',
      category: data['category'] ?? 'unghie',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'price': price,
      'duration': duration,
      'image': image,
      'category': category,
      'active': true,
    };
  }
}
