import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showProductRequirementsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const ProductRequirementsSheet(),
  );
}

class ProductRequirementsSheet extends StatelessWidget {
  const ProductRequirementsSheet({super.key});

  static const _requiredFields = <_ProductFieldInfo>[
    _ProductFieldInfo(
      label: 'Name',
      detail: 'Product name (1–255 characters).',
    ),
    _ProductFieldInfo(
      label: 'Price',
      detail: 'Selling price (0 or greater).',
    ),
    _ProductFieldInfo(
      label: 'Condition',
      detail: 'e.g. New, Used, Refurbished (up to 100 characters).',
    ),
    _ProductFieldInfo(
      label: 'Media',
      detail:
          'Add photos, video, or both. Video-only products are allowed. You can also paste image or video URLs in your message.',
    ),
  ];

  static const _optionalFields = <_ProductFieldInfo>[
    _ProductFieldInfo(
      label: 'Description',
      detail: 'Longer product details for customers.',
    ),
    _ProductFieldInfo(
      label: 'Category',
      detail: 'e.g. Electronics, Clothing (up to 100 characters).',
    ),
    _ProductFieldInfo(
      label: 'Number in stock',
      detail: 'How many units you have (0 or greater).',
    ),
    _ProductFieldInfo(
      label: 'Link',
      detail: 'Optional external product page URL.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E0C37), Color(0xFF0C0418)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF3F1163), width: 1.2),
          left: BorderSide(color: Color(0xFF3F1163), width: 1.2),
          right: BorderSide(color: Color(0xFF3F1163), width: 1.2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Product information',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'When you add a product, provide the fields below. Describe your item to the assistant in this chat.',
                  style: GoogleFonts.montserrat(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProductFieldSection(
                          title: 'Required',
                          badgeColor: const Color(0xFF9333EA),
                          fields: _requiredFields,
                        ),
                        const SizedBox(height: 16),
                        _ProductFieldSection(
                          title: 'Optional',
                          badgeColor: Colors.white.withValues(alpha: 0.35),
                          fields: _optionalFields,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9333EA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductFieldInfo {
  final String label;
  final String detail;

  const _ProductFieldInfo({required this.label, required this.detail});
}

class _ProductFieldSection extends StatelessWidget {
  final String title;
  final Color badgeColor;
  final List<_ProductFieldInfo> fields;

  const _ProductFieldSection({
    required this.title,
    required this.badgeColor,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        ...fields.map(
          (field) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ProductFieldRow(
              label: field.label,
              detail: field.detail,
              badgeColor: badgeColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductFieldRow extends StatelessWidget {
  final String label;
  final String detail;
  final Color badgeColor;

  const _ProductFieldRow({
    required this.label,
    required this.detail,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: const Color(0xFF3F1163).withValues(alpha: 0.85),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.montserrat(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: GoogleFonts.montserrat(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
