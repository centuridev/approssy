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

enum CategoryExtrasStatus { pending, missing, found, error }

class CategoryExtrasResult {
  final CategoryExtrasStatus status;
  final List<ServiceExtra> extras;

  const CategoryExtrasResult._({
    required this.status,
    required this.extras,
  });

  const CategoryExtrasResult.pending()
      : this._(status: CategoryExtrasStatus.pending, extras: const []);

  const CategoryExtrasResult.missing()
      : this._(status: CategoryExtrasStatus.missing, extras: const []);

  const CategoryExtrasResult.found(List<ServiceExtra> extras)
      : this._(status: CategoryExtrasStatus.found, extras: extras);

  const CategoryExtrasResult.error()
      : this._(status: CategoryExtrasStatus.error, extras: const []);

  bool get exists => status == CategoryExtrasStatus.found;

  bool get shouldUseServiceFallback => status == CategoryExtrasStatus.missing;
}

class Service {
  final String id;
  final String name;
  final String price;
  final int duration;
  final String image;
  final String category;
  final String details;
  final bool useCategoryExtras;
  final List<String> allowedExtraIds;
  final List<ServiceExtra> extras;

  const Service({
    this.id = '',
    required this.name,
    required this.price,
    required this.duration,
    required this.image,
    required this.category,
    this.details = '',
    this.useCategoryExtras = true,
    this.allowedExtraIds = const [],
    this.extras = const [],
  });

  double get numericPrice {
    final normalized = price.replaceAll('€', '').replaceAll(',', '.').trim();

    return double.tryParse(normalized) ?? 0;
  }

  List<ServiceExtra> availableExtrasFrom(
    CategoryExtrasResult categoryExtras,
  ) {
    final source = useCategoryExtras
        ? categoryExtras.shouldUseServiceFallback
              ? extras
              : categoryExtras.extras
        : extras;

    if (allowedExtraIds.isEmpty) {
      return source.where((extra) => extra.active).toList(growable: false);
    }

    final allowedIds = allowedExtraIds.toSet();

    return source
        .where((extra) => extra.active && allowedIds.contains(extra.id))
        .toList(growable: false);
  }

  factory Service.fromFirestore(Map<String, dynamic> data, {String id = ''}) {
    final rawExtras = data['extras'];
    final rawAllowedExtraIds = data['allowedExtraIds'];

    final List<ServiceExtra> parsedExtras = [];
    final List<String> parsedAllowedExtraIds = [];

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

    if (rawAllowedExtraIds is List) {
      for (final rawId in rawAllowedExtraIds) {
        final extraId = rawId?.toString().trim() ?? '';

        if (extraId.isNotEmpty) {
          parsedAllowedExtraIds.add(extraId);
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
      useCategoryExtras: _parseBool(
        data['useCategoryExtras'],
        defaultValue: true,
      ),
      allowedExtraIds: parsedAllowedExtraIds,
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
      'useCategoryExtras': useCategoryExtras,
      'allowedExtraIds': allowedExtraIds,
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
