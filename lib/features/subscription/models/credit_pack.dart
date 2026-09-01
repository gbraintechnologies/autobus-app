import 'package:autobus/features/subscription/data/apple_iap_ids.dart';

class CreditPack {
  final String id;
  final String name;
  final double credits;
  final double priceUsd;
  final double paystackAmount;
  final String appleProductId;
  final String googlePlayProductId;
  final String description;
  final String details;

  const CreditPack({
    required this.id,
    required this.name,
    required this.credits,
    required this.priceUsd,
    required this.paystackAmount,
    required this.appleProductId,
    required this.googlePlayProductId,
    required this.description,
    this.details = '',
  });

  String get storeProductId =>
      AppleIapIds.isAndroidApp && googlePlayProductId.isNotEmpty
      ? googlePlayProductId
      : appleProductId;

  factory CreditPack.fromJson(Map<String, dynamic> json) {
    final appleId = (json['apple_product_id'] ?? '').toString();
    return CreditPack(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      credits: (json['credits'] is num)
          ? (json['credits'] as num).toDouble()
          : double.tryParse('${json['credits']}') ?? 0,
      priceUsd: (json['price_usd'] is num)
          ? (json['price_usd'] as num).toDouble()
          : double.tryParse('${json['price_usd']}') ?? 0,
      paystackAmount: (json['paystack_amount'] is num)
          ? (json['paystack_amount'] as num).toDouble()
          : double.tryParse('${json['paystack_amount']}') ?? 0,
      appleProductId: appleId,
      googlePlayProductId: (json['google_play_product_id'] ?? appleId)
          .toString(),
      description: (json['description'] ?? '').toString(),
      details: (json['details'] ?? json['description'] ?? '').toString(),
    );
  }
}
