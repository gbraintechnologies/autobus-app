import 'package:autobus/barrel.dart';
import 'package:autobus/features/products/product_chat_image_attachments.dart';
import 'package:autobus/features/products/product_form_images.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController(text: 'New');
  final _stockCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();

  final List<ProductStagingSlot> _imageSlots = [];
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    _categoryCtrl.dispose();
    _conditionCtrl.dispose();
    _stockCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.outfit(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 13,
      ),
      hintStyle: GoogleFonts.outfit(
        color: Colors.white.withValues(alpha: 0.35),
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
    );
  }

  Future<void> _onImageSlotTap(int index) async {
    if (_saving) return;
    final slot = _imageSlots[index];
    if (slot.isEmpty) {
      await pickMultipleProductImages(context, _imageSlots, setState);
      return;
    }
    await showProductSlotActionsSheet(
      context,
      () => pickProductImageForSlot(context, _imageSlots, index, setState),
      () => removeProductStagingSlot(_imageSlots, index, setState),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final hasImages = _imageSlots.any((s) => !s.isEmpty);
    if (!hasImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product photo')),
      );
      return;
    }

    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price')),
      );
      return;
    }

    int? stock;
    final stockText = _stockCtrl.text.trim();
    if (stockText.isNotEmpty) {
      stock = int.tryParse(stockText);
      if (stock == null || stock < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock must be a non-negative number')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      final photoUrls = await uploadStagedProductImageUrls(api, _imageSlots);
      if (photoUrls.isEmpty) {
        throw Exception('Could not upload product images');
      }

      await api.createProduct(
        name: _nameCtrl.text.trim(),
        description: _descriptionCtrl.text,
        price: price,
        category: _categoryCtrl.text,
        condition: _conditionCtrl.text.trim(),
        numberInStock: stock,
        link: _linkCtrl.text,
        photos: photoUrls,
      );

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product created', style: GoogleFonts.outfit())),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingError(e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: ManageScreenStyle.homeDashboardBodyDecoration,
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: Row(
                    children: [
                      const ManageScreenBackButton(),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          'Add Product',
                          style: ManageScreenStyle.headerTitleStyle(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      children: [
                        ProductFormImageSection(
                          slots: _imageSlots,
                          busy: _saving,
                          onSlotTap: _onImageSlotTap,
                          onAddImages: () => pickMultipleProductImages(
                            context,
                            _imageSlots,
                            setState,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _textField(
                          controller: _nameCtrl,
                          label: 'Name',
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Name is required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _textField(
                          controller: _descriptionCtrl,
                          label: 'Description',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 14),
                        _textField(
                          controller: _priceCtrl,
                          label: 'Price',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Price is required';
                            }
                            if (double.tryParse(v.trim()) == null) {
                              return 'Invalid price';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _textField(
                          controller: _categoryCtrl,
                          label: 'Category',
                        ),
                        const SizedBox(height: 14),
                        _textField(
                          controller: _conditionCtrl,
                          label: 'Condition',
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Condition is required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _textField(
                          controller: _stockCtrl,
                          label: 'Stock quantity',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),
                        _textField(
                          controller: _linkCtrl,
                          label: 'Product link',
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFA855F7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _saving
                        ? const AutobusLoadingIndicator(size: 22)
                        : Text(
                            'Create product',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onTapOutside: dismissAppKeyboard,
      style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
      cursorColor: const Color(0xFFA855F7),
      decoration: _fieldDecoration(label),
    );
  }
}
