import 'package:autobus/icons/figma_icons.dart';

/// One row from `GET /billing/payment-methods`.
class SavedPaymentMethod {
  final String id;
  final String type;
  final String name;
  final String detail;
  final bool isDefault;

  const SavedPaymentMethod({
    required this.id,
    required this.type,
    required this.name,
    required this.detail,
    this.isDefault = false,
  });

  bool get isCard => type.contains('card');

  String get logoAsset => isCard ? FigmaImages.visaLogo : FigmaImages.mtnLogo;

  double get logoRadius => isCard ? 7.5 : 5.1;

  static String _first(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  factory SavedPaymentMethod.fromJson(Map<String, dynamic> json) {
    final type = _first(json, ['type', 'method_type', 'channel']).toLowerCase();
    final isCard = type.contains('card');
    var detail = '';
    if (isCard) {
      final last4 = _first(json, ['last4', 'card_last4', 'last_four']);
      detail = last4.isNotEmpty
          ? '•••• •••• •••• $last4'
          : _first(json, ['masked_pan', 'card_number']);
    } else {
      detail = _first(json, [
        'phone_number',
        'phone',
        'mobile_number',
        'account_number',
      ]);
    }
    return SavedPaymentMethod(
      id: _first(json, ['id', 'payment_method_id', 'method_id']),
      type: type.isEmpty ? 'mobile_money' : type,
      name: _first(json, ['account_name', 'name', 'holder_name', 'card_name']),
      detail: detail,
      isDefault: json['is_default'] == true,
    );
  }
}
