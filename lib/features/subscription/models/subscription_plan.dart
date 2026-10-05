import 'package:autobus/barrel.dart';
import 'package:autobus/features/subscription/data/apple_iap_ids.dart';

class BillingOption extends Equatable {
  final String id;
  final String label;
  final String subtitle;
  final double price;

  const BillingOption({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'subtitle': subtitle,
    'price': price,
  };

  @override
  List<Object?> get props => [id, label, subtitle, price];
}

class SubscriptionPlan extends Equatable {
  final int id;
  final String name;
  final double price;
  final List<String> features;
  final List<String> agents;
  final String description;
  final bool isActive;
  final Map<String, String> appleProductIds;
  final double? creditsTotal;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.features,
    this.agents = const [],
    required this.description,
    required this.isActive,
    this.appleProductIds = const {},
    this.creditsTotal,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString();
    final rawIds = json['apple_product_ids'];
    final appleIds = <String, String>{};
    if (rawIds is Map) {
      rawIds.forEach((key, value) {
        final id = value?.toString() ?? '';
        if (id.isNotEmpty) appleIds[key.toString()] = id;
      });
    }
    if (appleIds.isEmpty) {
      appleIds.addAll(AppleIapIds.forPlanName(name));
    }

    return SubscriptionPlan(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse((json['id'] ?? '0').toString()) ?? 0,
      name: name,
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : double.tryParse((json['price'] ?? '0').toString()) ?? 0,
      features: ((json['features'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      agents: ((json['agents'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      description: (json['description'] ?? '').toString(),
      isActive: json['is_active'] == true,
      appleProductIds: appleIds,
      creditsTotal: _creditsFromJson(json),
    );
  }

  static double? _creditsFromJson(Map<String, dynamic> json) {
    final v =
        json['credits'] ??
        json['total_credits'] ??
        json['credit_amount'] ??
        json['allocated_credits'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'features': features,
      'agents': agents,
      'description': description,
      'is_active': isActive,
      'apple_product_ids': appleProductIds,
      if (creditsTotal != null) 'credits': creditsTotal,
    };
  }

  String? appleProductIdFor(String billingId) {
    final key = billingId == 'annual' || billingId == 'yearly' || billingId == 'y1'
        ? 'annual'
        : 'monthly';
    return appleProductIds[key];
  }

  List<BillingOption> get billing => [
    BillingOption(
      id: 'monthly',
      label: 'Monthly',
      subtitle: 'per month',
      price: price,
    ),
    BillingOption(
      id: 'annual',
      label: 'Annual',
      subtitle: 'per year',
      price: _annualPrice,
    ),
  ];

  /// Full year total: 12 × monthly plan price (no bundled discount factor).
  double get _annualPrice =>
      double.parse((price * 12).toStringAsFixed(2));

  String get priceText => price == 0 ? 'Free' : 'from GHS $price/mo';

  String get shortPriceLabel {
    if (price == 0) return 'Free';
    return '\$${price.toStringAsFixed(2)}';
  }

  String get creditsInTotalLabel {
    final fromField = creditsTotal;
    if (fromField != null && fromField > 0) {
      final shown = fromField == fromField.roundToDouble()
          ? fromField.toStringAsFixed(0)
          : fromField.toStringAsFixed(1);
      return '$shown credits in total';
    }
    final pattern = RegExp(r'(\d+(?:\.\d+)?)\s*credits', caseSensitive: false);
    for (final source in [description, ...features]) {
      final match = pattern.firstMatch(source);
      if (match != null) return '${match.group(1)} credits in total';
    }
    return priceText;
  }

  /// API agent ids are often snake_case (e.g. `email_agent`); show as title text.
  static String formatAgentLabel(String raw) {
    final normalized = raw.trim().replaceAll('_', ' ');
    if (normalized.isEmpty) return raw;
    return normalized
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map(
          (w) =>
              '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1).toLowerCase() : ''}',
        )
        .join(' ');
  }

  @override
  List<Object?> get props => [
    id,
    name,
    price,
    features,
    agents,
    description,
    isActive,
    appleProductIds,
    creditsTotal,
  ];
}
