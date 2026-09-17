import 'package:autobus/barrel.dart';

const kDefaultPricingCurrency = 'GHS';

class PricingCurrencyOption {
  final String code;
  final String name;
  final String symbol;

  const PricingCurrencyOption(this.code, this.name, this.symbol);

  String get dropdownLabel => '$code ($symbol)';
}

const kPricingCurrencies = <PricingCurrencyOption>[
  PricingCurrencyOption('GHS', 'Ghanaian Cedi', '₵'),
  PricingCurrencyOption('USD', 'US Dollar', '\$'),
  PricingCurrencyOption('NGN', 'Nigerian Naira', '₦'),
  PricingCurrencyOption('XOF', 'West African CFA', 'CFA'),
  PricingCurrencyOption('EUR', 'Euro', '€'),
  PricingCurrencyOption('GBP', 'British Pound', '£'),
];

String normalizePricingCurrency(Object? raw) {
  final code = (raw ?? '').toString().trim().toUpperCase();
  for (final option in kPricingCurrencies) {
    if (option.code == code) return option.code;
  }
  return kDefaultPricingCurrency;
}

String formatProductPrice(Object? raw, {String currency = kDefaultPricingCurrency}) {
  double? value;
  if (raw is num) {
    value = raw.toDouble();
  } else {
    value = double.tryParse(raw?.toString() ?? '');
  }
  if (value == null) return '—';
  final amount = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '${normalizePricingCurrency(currency)} $amount';
}

Future<String> loadBusinessCurrency(ApiService api) async {
  try {
    final me = await api.getUserProfile();
    return normalizePricingCurrency(me['currency_code']);
  } catch (_) {
    return kDefaultPricingCurrency;
  }
}

Future<void> saveBusinessCurrency(ApiService api, String code) async {
  await api.updateUserProfile(currencyCode: normalizePricingCurrency(code));
}

class PricingCurrencyDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const PricingCurrencyDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final selected = normalizePricingCurrency(value);
    return DropdownButtonFormField<String>(
      value: selected,
      isExpanded: true,
      dropdownColor: const Color(0xFF1E0A32),
      iconEnabledColor: Colors.white70,
      style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Currency',
        labelStyle: GoogleFonts.outfit(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 13,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: const Color(0xFF3F1163).withValues(alpha: 0.8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFA855F7)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: [
        for (final option in kPricingCurrencies)
          DropdownMenuItem(
            value: option.code,
            child: Text(option.dropdownLabel),
          ),
      ],
      onChanged: enabled
          ? (next) {
              if (next != null) onChanged(next);
            }
          : null,
    );
  }
}
