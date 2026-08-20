import 'service.dart';

class BookingSelection {
  final Service service;
  final List<ServiceExtra> selectedExtras;

  const BookingSelection({
    required this.service,
    this.selectedExtras = const [],
  });

  double get totalPrice {
    return service.numericPrice +
        selectedExtras.fold<double>(0, (total, extra) => total + extra.price);
  }

  int get totalDuration {
    return service.duration +
        selectedExtras.fold<int>(0, (total, extra) => total + extra.duration);
  }

  BookingSelection copyWith({
    Service? service,
    List<ServiceExtra>? selectedExtras,
  }) {
    return BookingSelection(
      service: service ?? this.service,
      selectedExtras: selectedExtras ?? this.selectedExtras,
    );
  }

  bool hasExtra(String extraId) {
    return selectedExtras.any((extra) => extra.id == extraId);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'serviceId': service.id,
      'name': service.name,
      'price': service.numericPrice,
      'duration': service.duration,
      'extras': selectedExtras
          .map(
            (extra) => {
              'id': extra.id,
              'name': extra.name,
              'price': extra.price,
              'duration': extra.duration,
            },
          )
          .toList(),
      'totalPrice': totalPrice,
      'totalDuration': totalDuration,
    };
  }
}
