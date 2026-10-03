import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/service.dart';

class ServiceExtrasService {
  ServiceExtrasService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, CategoryExtrasResult> _cache = {};
  static final Map<String, Future<CategoryExtrasResult>> _inFlight = {};
  static final Map<String, DateTime> _transientCachedAt = {};
  static const Duration _transientCacheDuration = Duration(seconds: 30);

  static Future<CategoryExtrasResult> getActiveExtrasForCategory(
    String category,
  ) {
    final categoryId = category.trim().toLowerCase();

    if (categoryId.isEmpty) {
      return Future.value(const CategoryExtrasResult.missing());
    }

    final cachedResult = _cache[categoryId];

    if (cachedResult != null) {
      if (cachedResult.status == CategoryExtrasStatus.found) {
        return SynchronousFuture(cachedResult);
      }

      final cachedAt = _transientCachedAt[categoryId];

      if (cachedAt != null &&
          DateTime.now().difference(cachedAt) < _transientCacheDuration) {
        return SynchronousFuture(cachedResult);
      }

      _cache.remove(categoryId);
      _transientCachedAt.remove(categoryId);
    }

    final pendingRequest = _inFlight[categoryId];

    if (pendingRequest != null) {
      return pendingRequest;
    }

    final request = _fetchCategoryExtras(categoryId)
        .then((result) {
          _cache[categoryId] = result;

          if (result.status == CategoryExtrasStatus.found) {
            _transientCachedAt.remove(categoryId);
          } else {
            _transientCachedAt[categoryId] = DateTime.now();
          }

          return result;
        })
        .whenComplete(() {
          _inFlight.remove(categoryId);
        });

    _inFlight[categoryId] = request;

    return request;
  }

  static void clearCache() {
    _cache.clear();
    _inFlight.clear();
    _transientCachedAt.clear();
  }

  static void clearCategory(String category) {
    final categoryId = category.trim().toLowerCase();

    _cache.remove(categoryId);
    _inFlight.remove(categoryId);
    _transientCachedAt.remove(categoryId);
  }

  static Future<CategoryExtrasResult> _fetchCategoryExtras(
    String categoryId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('service_extras')
          .doc(categoryId)
          .get();

      if (!snapshot.exists) {
        return const CategoryExtrasResult.missing();
      }

      final data = snapshot.data();
      final rawExtras = data?['extras'];

      if (rawExtras is! List) {
        return const CategoryExtrasResult.found([]);
      }

      final extras = <ServiceExtra>[];

      for (final rawExtra in rawExtras) {
        if (rawExtra is Map) {
          final extra = ServiceExtra.fromMap(
            Map<String, dynamic>.from(rawExtra),
          );

          if (extra.active) {
            extras.add(extra);
          }
        }
      }

      return CategoryExtrasResult.found(extras);
    } catch (_) {
      return const CategoryExtrasResult.error();
    }
  }
}
