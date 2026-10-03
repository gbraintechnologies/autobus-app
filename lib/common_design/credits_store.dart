import 'package:autobus/features/home/services/api_service.dart';
import 'package:flutter/foundation.dart';

/// App-wide wallet balance shown in every header credits pill.
///
/// Every `GET /credits/me` response is ingested here, so the value stays the
/// same across screens and updates everywhere after a purchase or usage.
class CreditsStore {
  CreditsStore._();

  static final CreditsStore instance = CreditsStore._();

  static const _maxAge = Duration(seconds: 30);

  final ValueNotifier<double?> walletRemaining = ValueNotifier<double?>(null);

  DateTime? _fetchedAt;
  Future<void>? _inFlight;

  bool get hasLoaded => _fetchedAt != null;

  void ingest(Map<String, dynamic>? data) {
    if (data == null) return;
    final wallet = data['wallet'];
    double? remaining;
    if (wallet is Map) {
      final raw = wallet['remaining'];
      remaining = raw is num
          ? raw.toDouble()
          : double.tryParse(raw?.toString() ?? '');
    }
    _fetchedAt = DateTime.now();
    walletRemaining.value = remaining;
  }

  Future<void> refresh(ApiService api, {bool force = false}) {
    final fetchedAt = _fetchedAt;
    if (!force &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < _maxAge) {
      return Future.value();
    }
    return _inFlight ??= api
        .getMyCredits()
        .then((_) {})
        .whenComplete(() => _inFlight = null);
  }

  void clear() {
    _fetchedAt = null;
    walletRemaining.value = null;
  }
}
