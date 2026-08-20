class ServiceExtra {
  final String id;
  final String name;
  final double price;
  final int duration;
  final bool active;

  const ServiceExtra({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    this.active = true,
  });

  factory ServiceExtra.fromMap(Map<String, dynamic> data) {
    return ServiceExtra(
      id: data['id']?.toString().trim() ?? '',
      name: data['name']?.toString().trim() ?? '',
      price: _parsePrice(data['price']),
      duration: _parseDuration(data['duration']),
      active: _parseBool(data['active'], defaultValue: true),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'duration': duration,
      'active': active,
    };
  }

  static double _parsePrice(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      final normalized = value.replaceAll('€', '').replaceAll(',', '.').trim();

      return double.tryParse(normalized) ?? 0;
    }

    return 0;
  }

  static int _parseDuration(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      final normalized = value.replaceAll('min', '').trim();

      return int.tryParse(normalized) ?? 0;
    }

    return 0;
  }

  static bool _parseBool(dynamic value, {required bool defaultValue}) {
    if (value is bool) {
      return value;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();

      if (normalized == 'true') {
        return true;
      }

      if (normalized == 'false') {
        return false;
      }
    }

    return defaultValue;
  }
}

class Service {
  final String id;
  final String name;
  final String price;
  final int duration;
  final String image;
  final String category;
  final String details;
  final List<ServiceExtra> extras;

  const Service({
    this.id = '',
    required this.name,
    required this.price,
    required this.duration,
    required this.image,
    required this.category,
    this.details = '',
    this.extras = const [],
  });

  double get numericPrice {
    final normalized = price.replaceAll('€', '').replaceAll(',', '.').trim();

    return double.tryParse(normalized) ?? 0;
  }

  factory Service.fromFirestore(Map<String, dynamic> data, {String id = ''}) {
    final rawExtras = data['extras'];

    final List<ServiceExtra> parsedExtras = [];

    if (rawExtras is List) {
      for (final rawExtra in rawExtras) {
        if (rawExtra is Map) {
          final extraMap = Map<String, dynamic>.from(rawExtra);

          final extra = ServiceExtra.fromMap(extraMap);

          if (extra.active) {
            parsedExtras.add(extra);
          }
        }
      }
    }

    return Service(
      id: id,
      name: data['name']?.toString() ?? '',
      price: data['price']?.toString() ?? '',
      duration: _parseDuration(data['duration']),
      image: data['image']?.toString() ?? '',
      category: data['category']?.toString() ?? 'unghie',
      details: data['details']?.toString() ?? '',
      extras: parsedExtras,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'price': price,
      'duration': duration,
      'image': image,
      'category': category,
      'details': details,
      'extras': extras.map((extra) => extra.toMap()).toList(),
      'active': true,
    };
  }

  static int _parseDuration(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      final normalized = value.replaceAll('min', '').trim();

      return int.tryParse(normalized) ?? 0;
    }

    return 0;
  }
}
