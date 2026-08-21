import 'dart:async';
import 'dart:developer';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:autobus/common_design/app_error.dart';
import 'package:autobus/features/home/services/api_service.dart';
import 'package:autobus/features/subscription/data/apple_iap_ids.dart';

class AppleIapPurchaseResult {
  final bool success;
  final bool cancelled;
  final String? signedTransaction;
  final String? productId;
  final String? error;

  const AppleIapPurchaseResult({
    required this.success,
    this.cancelled = false,
    this.signedTransaction,
    this.productId,
    this.error,
  });
}

/// StoreKit 2 purchases via Flutter's [InAppPurchase] plugin.
class AppleIapService {
  AppleIapService._();
  static final AppleIapService instance = AppleIapService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ApiService? _api;
  bool _started = false;

  final Map<String, Completer<PurchaseDetails>> _inflight = {};
  final Map<String, PurchaseDetails> _lastPurchase = {};
  List<PurchaseDetails>? _restoreBuffer;
  Completer<void>? _restoreDone;

  Future<void> start({required ApiService api}) async {
    if (!AppleIapIds.isSupported) return;
    _api = api;
    if (_started) return;
    _started = true;
    _subscription = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) => log('Apple IAP stream error: $error'),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }

  Future<bool> isAvailable() async {
    if (!AppleIapIds.isSupported) return false;
    try {
      return await _iap.isAvailable();
    } catch (e) {
      log('Apple IAP isAvailable failed: $e');
      return false;
    }
  }

  Future<Map<String, ProductDetails>> queryProducts(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final available = await isAvailable();
    if (!available) return {};
    final response = await _iap.queryProductDetails(ids);
    if (response.error != null) {
      log('Apple IAP query error: ${response.error}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      log('Apple IAP products not found: ${response.notFoundIDs}');
    }
    return {for (final product in response.productDetails) product.id: product};
  }

  Future<AppleIapPurchaseResult> buy(ProductDetails product) async {
    final available = await isAvailable();
    if (!available) {
      return const AppleIapPurchaseResult(
        success: false,
        error: 'In-App Purchases are not available on this device.',
      );
    }

    final existing = _inflight[product.id];
    if (existing != null && !existing.isCompleted) {
      return const AppleIapPurchaseResult(
        success: false,
        error: 'A purchase is already in progress.',
      );
    }

    final completer = Completer<PurchaseDetails>();
    _inflight[product.id] = completer;

    try {
      final param = PurchaseParam(productDetails: product);
      final started = await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) {
        _inflight.remove(product.id);
        return const AppleIapPurchaseResult(
          success: false,
          error: 'Could not start the App Store purchase.',
        );
      }

      final purchase = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw TimeoutException('Timed out waiting for App Store purchase');
        },
      );

      if (purchase.status == PurchaseStatus.canceled) {
        return const AppleIapPurchaseResult(success: false, cancelled: true);
      }
      if (purchase.status == PurchaseStatus.error) {
        return AppleIapPurchaseResult(
          success: false,
          error: purchase.error?.message ?? 'App Store purchase failed.',
        );
      }
      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        return const AppleIapPurchaseResult(
          success: false,
          error: 'App Store purchase was not completed.',
        );
      }

      _lastPurchase[product.id] = purchase;
      final signed = purchase.verificationData.serverVerificationData;
      if (signed.isEmpty) {
        return const AppleIapPurchaseResult(
          success: false,
          error: 'App Store did not return a signed transaction.',
        );
      }
      return AppleIapPurchaseResult(
        success: true,
        signedTransaction: signed,
        productId: purchase.productID,
      );
    } on TimeoutException {
      return const AppleIapPurchaseResult(
        success: false,
        error: 'Timed out waiting for the App Store. Try Restore Purchases.',
      );
    } catch (e) {
      return AppleIapPurchaseResult(
        success: false,
        error: userFacingError(e, action: 'completing purchase'),
      );
    } finally {
      _inflight.remove(product.id);
    }
  }

  Future<AppleIapPurchaseResult> purchaseAndActivate({
    required ProductDetails product,
    required int planId,
    required String billingId,
    String? phone,
  }) async {
    final api = _api;
    if (api == null) {
      return const AppleIapPurchaseResult(
        success: false,
        error: 'Apple IAP is not initialized.',
      );
    }

    final purchaseResult = await buy(product);
    if (!purchaseResult.success) return purchaseResult;

    try {
      final verified = await api.verifyAppleIapPurchase(
        signedTransaction: purchaseResult.signedTransaction!,
        planId: planId,
        billingId: billingId,
        phone: phone,
      );
      final purchase = _lastPurchase[product.id];
      if (verified) {
        if (purchase != null) {
          await completeIfNeeded(purchase);
        }
        _lastPurchase.remove(product.id);
        return purchaseResult;
      }
      return const AppleIapPurchaseResult(
        success: false,
        error: 'Apple purchase could not be activated. Try Restore Purchases.',
      );
    } catch (e) {
      return AppleIapPurchaseResult(
        success: false,
        error: userFacingError(e, action: 'activating subscription'),
      );
    }
  }

  Future<AppleIapPurchaseResult> restoreActiveSubscription({
    int? planId,
    String? billingId,
  }) async {
    final api = _api;
    if (api == null) {
      return const AppleIapPurchaseResult(
        success: false,
        error: 'Apple IAP is not initialized.',
      );
    }
    if (!await isAvailable()) {
      return const AppleIapPurchaseResult(
        success: false,
        error: 'In-App Purchases are not available on this device.',
      );
    }

    final restored = <PurchaseDetails>[];
    _restoreBuffer = restored;
    try {
      await _iap.restorePurchases();
      await Future<void>.delayed(const Duration(seconds: 2));
    } catch (_) {
    } finally {
      _restoreBuffer = null;
      _restoreDone = null;
    }

    PurchaseDetails? best;
    for (final purchase in restored) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        best = purchase;
      }
    }
    if (best == null) {
      return const AppleIapPurchaseResult(
        success: false,
        error: 'No Apple subscription was found to restore.',
      );
    }

    final signed = best.verificationData.serverVerificationData;
    if (signed.isEmpty) {
      return const AppleIapPurchaseResult(
        success: false,
        error: 'Restored Apple purchase was missing a signed transaction.',
      );
    }

    try {
      final verified = await api.verifyAppleIapPurchase(
        signedTransaction: signed,
        planId: planId,
        billingId: billingId,
      );
      if (verified) {
        await completeIfNeeded(best);
        return AppleIapPurchaseResult(
          success: true,
          signedTransaction: signed,
          productId: best.productID,
        );
      }
      return const AppleIapPurchaseResult(
        success: false,
        error: 'Restored Apple purchase could not be activated.',
      );
    } catch (e) {
      return AppleIapPurchaseResult(
        success: false,
        error: userFacingError(e, action: 'restoring purchase'),
      );
    }
  }

  Future<void> restorePurchases() async {
    if (!await isAvailable()) return;
    await _iap.restorePurchases();
  }

  Future<void> completeIfNeeded(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    final restoring = _restoreBuffer;
    if (restoring != null) {
      restoring.addAll(purchases);
      final done = _restoreDone;
      if (done != null && !done.isCompleted) {
        done.complete();
      }
    }

    for (final purchase in purchases) {
      final completer = _inflight[purchase.productID];
      if (completer != null && !completer.isCompleted) {
        completer.complete(purchase);
        continue;
      }

      if (restoring != null) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _syncUnconsumed(purchase);
      } else if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  Future<void> _syncUnconsumed(PurchaseDetails purchase) async {
    final api = _api;
    final signed = purchase.verificationData.serverVerificationData;
    if (api == null || signed.isEmpty) return;
    try {
      final verified = await api.verifyAppleIapPurchase(
        signedTransaction: signed,
      );
      if (verified) {
        await completeIfNeeded(purchase);
      }
    } catch (e) {
      log('Apple IAP pending sync failed: $e');
    }
  }
}
