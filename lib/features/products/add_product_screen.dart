import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/features/marketing/models/postiz_integration.dart';
import 'package:autobus/features/products/product_chat_image_attachments.dart';
import 'package:autobus/features/products/product_form_images.dart';
import 'package:autobus/features/products/pricing_currency.dart';
import 'package:autobus/features/products/product_social_post.dart';

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
  String _currency = kDefaultPricingCurrency;
  List<PostizIntegration> _linkedChannels = [];
  final Set<String> _selectedChannelIds = {};

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrency();
      _loadLinkedChannels();
    });
  }

  Future<void> _loadCurrency() async {
    final api = context.read<ApiService>();
    final code = await loadBusinessCurrency(api);
    if (!mounted) return;
    setState(() => _currency = code);
  }

  Future<void> _loadLinkedChannels() async {
    try {
      final channels = await loadLinkedMarketingIntegrations(
        context.read<ApiService>(),
      );
      if (!mounted) return;
      setState(() => _linkedChannels = channels);
    } catch (_) {}
  }

  void _toggleChannel(String id) {
    setState(() {
      if (_selectedChannelIds.contains(id)) {
        _selectedChannelIds.remove(id);
      } else {
        _selectedChannelIds.add(id);
      }
    });
  }

  Future<void> _onCurrencyChanged(String code) async {
    setState(() => _currency = code);
    try {
      await saveBusinessCurrency(context.read<ApiService>(), code);
    } catch (_) {
      // Preference save is best-effort; product create still proceeds.
    }
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.montserrat(
        color: Colors.black54,
        fontSize: 13,
      ),
      hintStyle: GoogleFonts.montserrat(
        color: Colors.black38,
        fontSize: 13,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: LightScreenTheme.hint.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LightScreenTheme.accent),
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
      () {
        if (slot.looksLikeVideo) {
          pickProductVideoForSlot(context, _imageSlots, index, setState);
        } else {
          pickProductImageForSlot(context, _imageSlots, index, setState);
        }
      },
      () => removeProductStagingSlot(_imageSlots, index, setState),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final hasMedia = _imageSlots.any((s) => !s.isEmpty);
    if (!hasMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one photo or video')),
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
      final media = await uploadStagedProductMedia(api, _imageSlots);
      if (media.isEmpty) {
        throw Exception('Could not upload product media');
      }

      await api.createProduct(
        name: _nameCtrl.text.trim(),
        description: _descriptionCtrl.text,
        price: price,
        category: _categoryCtrl.text,
        condition: _conditionCtrl.text.trim(),
        numberInStock: stock,
        link: _linkCtrl.text,
        photos: media.photos,
        videos: media.videos,
      );

      var createdMsg = 'Product created';
      if (_selectedChannelIds.isNotEmpty) {
        final caption = buildProductSocialCaption(
          name: _nameCtrl.text.trim(),
          description: _descriptionCtrl.text,
          priceLabel: formatProductPrice(price, currency: _currency),
          link: _linkCtrl.text,
        );
        final posted = await publishProductToSocialChannels(
          api: api,
          allIntegrations: _linkedChannels,
          selectedIds: _selectedChannelIds,
          caption: caption,
          mediaUrls: media.all,
        );
        if (posted.publishedCount > 0 && posted.errors.isEmpty) {
          createdMsg =
              'Product created and posted to ${posted.publishedCount} channel(s)';
        } else if (posted.publishedCount > 0) {
          createdMsg =
              'Product created. Posted to ${posted.publishedCount} channel(s). Some failed: ${posted.errors.join('; ')}';
        } else if (posted.errors.isNotEmpty) {
          createdMsg =
              'Product created, but social posting failed: ${posted.errors.join('; ')}';
        }
      }

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(createdMsg, style: GoogleFonts.outfit())),
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
    return LightScreenScaffold(
      title: 'Add Product',
      titleFontSize: 16,
      creditCategory: CreditCategory.storageMb,
      resizeToAvoidBottomInset: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                          onAddVideos: () => pickMultipleProductVideos(
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 128,
                              child: PricingCurrencyDropdown(
                                value: _currency,
                                enabled: !_saving,
                                onChanged: _onCurrencyChanged,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _textField(
                                controller: _priceCtrl,
                                label: 'Price',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                            ),
                          ],
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
                        const SizedBox(height: 24),
                        ProductSocialChannelPicker(
                          integrations: _linkedChannels,
                          selectedIds: _selectedChannelIds,
                          hasVideo: _imageSlots.any(
                            (s) => !s.isEmpty && s.looksLikeVideo,
                          ),
                          busy: _saving,
                          onToggle: _toggleChannel,
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
                            _selectedChannelIds.isEmpty
                                ? 'Create product'
                                : 'Create and post',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
      style: GoogleFonts.montserrat(color: Colors.black87, fontSize: 14),
      cursorColor: LightScreenTheme.accent,
      decoration: _fieldDecoration(label),
    );
  }
}
