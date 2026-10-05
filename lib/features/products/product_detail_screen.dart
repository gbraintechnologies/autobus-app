import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/features/products/pricing_currency.dart';
import 'package:autobus/features/products/product_existing_gallery.dart';
import 'package:autobus/features/products/product_media.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final String? initialName;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.initialName,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _conditionCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _linkCtrl;

  bool _loading = true;
  bool _saving = false;
  bool _photoBusy = false;
  String? _loadError;
  String? _inventoryId;
  String _currency = kDefaultPricingCurrency;
  List<ProductGalleryPhoto> _photos = const [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _categoryCtrl = TextEditingController();
    _conditionCtrl = TextEditingController();
    _stockCtrl = TextEditingController();
    _linkCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

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

  void _populateForm(Map<String, dynamic> p) {
    _inventoryId = (p['inventory_id'] ?? '').toString();
    _nameCtrl.text = (p['name'] ?? '').toString();
    _descriptionCtrl.text = (p['description'] ?? '').toString();
    final price = p['price'];
    if (price is num) {
      _priceCtrl.text = price == price.roundToDouble()
          ? price.toStringAsFixed(0)
          : price.toString();
    } else {
      _priceCtrl.text = price?.toString() ?? '';
    }
    _categoryCtrl.text = (p['category'] ?? '').toString();
    _conditionCtrl.text = (p['condition'] ?? '').toString();
    final stock = p['number_in_stock'];
    _stockCtrl.text = stock == null ? '' : stock.toString();
    _linkCtrl.text = (p['link'] ?? '').toString();
  }

  ProductGalleryPhoto? get _coverPhoto {
    final images = _photos.where((p) => !p.isVideo).toList();
    if (images.isEmpty) return null;
    return images.firstWhere((p) => p.isPrimary, orElse: () => images.first);
  }

  List<ProductGalleryPhoto> _photosFromProduct(Map<String, dynamic> p) {
    final rawPhotos = p['photos'];
    if (rawPhotos is List && rawPhotos.isNotEmpty) {
      return rawPhotos
          .map((e) => e.toString())
          .where((url) => url.trim().isNotEmpty)
          .toList()
          .asMap()
          .entries
          .map(
            (entry) => ProductGalleryPhoto(
              imageId: 'legacy-${entry.key}',
              url: entry.value,
              isPrimary: entry.key == 0,
              isVideo: productMediaLooksLikeVideo(entry.value),
            ),
          )
          .toList();
    }
    final single = (p['photo'] ?? '').toString().trim();
    if (single.isNotEmpty) {
      return [
        ProductGalleryPhoto(
          imageId: 'legacy-0',
          url: single,
          isPrimary: true,
          isVideo: productMediaLooksLikeVideo(single),
        ),
      ];
    }
    return const [];
  }

  Future<void> _load({bool photosOnly = false}) async {
    if (!photosOnly) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final api = context.read<ApiService>();
      final p = photosOnly
          ? null
          : await api.getProduct(widget.productId);
      List<ProductGalleryPhoto> photos = const [];
      try {
        final photoRows = await api.listProductPhotos(widget.productId);
        photos = photoRows
            .map(ProductGalleryPhoto.fromJson)
            .where((photo) => photo.url.trim().isNotEmpty)
            .toList();
      } catch (_) {
        if (p != null) {
          photos = _photosFromProduct(p);
        }
      }
      if (!mounted) return;
      if (p != null) {
        _populateForm(p);
      }
      String currency = _currency;
      if (!photosOnly) {
        currency = await loadBusinessCurrency(api);
      }
      if (!mounted) return;
      setState(() {
        _photos = photos;
        _currency = currency;
        _loading = false;
        _photoBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!photosOnly) {
          _loadError = userFacingError(e);
        }
        _loading = false;
        _photoBusy = false;
      });
    }
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.poppins(
        color: Colors.black54,
        fontSize: 13,
      ),
      hintStyle: GoogleFonts.poppins(
        color: Colors.black38,
        fontSize: 13,
      ),
      filled: true,
      fillColor: LightScreenTheme.surface,
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

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
      await api.updateProduct(
        widget.productId,
        name: _nameCtrl.text.trim(),
        description: _descriptionCtrl.text,
        price: price,
        category: _categoryCtrl.text,
        condition: _conditionCtrl.text.trim(),
        numberInStock: stock,
        link: _linkCtrl.text,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product saved', style: GoogleFonts.outfit()),
        ),
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

  Future<void> _addPhotos() async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      final api = context.read<ApiService>();
      await pickAndUploadProductPhotos(
        context: context,
        api: api,
        productId: widget.productId,
        currentCount: _photos.where((p) => !p.isVideo).length,
      );
      if (!mounted) return;
      await _load(photosOnly: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingError(e)),
        ),
      );
      setState(() => _photoBusy = false);
    }
  }

  Future<void> _addVideos() async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      final api = context.read<ApiService>();
      await pickAndUploadProductVideos(
        context: context,
        api: api,
        productId: widget.productId,
        currentVideoCount: _photos.where((p) => p.isVideo).length,
      );
      if (!mounted) return;
      await _load(photosOnly: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingError(e)),
        ),
      );
      setState(() => _photoBusy = false);
    }
  }

  Future<void> _onPhotoTap(ProductGalleryPhoto photo) async {
    if (_photoBusy) return;
    final action = await showProductPhotoActionsSheet(
      context,
      photo,
      canDelete: _photos.length > 1,
    );
    if (!mounted || action == null) return;

    setState(() => _photoBusy = true);
    try {
      final api = context.read<ApiService>();
      if (action == 'primary') {
        await api.setPrimaryProductPhoto(widget.productId, photo.imageId);
      } else if (action == 'delete') {
        await api.deleteProductPhoto(widget.productId, photo.imageId);
      }
      if (!mounted) return;
      await _load(photosOnly: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _photoBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingError(e)),
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : 'this product';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Delete product?',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Text(
          'Remove "$name" permanently? This cannot be undone.',
          style: GoogleFonts.poppins(
            color: LightScreenTheme.body,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: LightScreenTheme.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      await api.deleteProduct(widget.productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product deleted', style: GoogleFonts.outfit())),
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
    final title = widget.initialName?.trim().isNotEmpty == true
        ? widget.initialName!.trim()
        : 'Product';

    return LightScreenScaffold(
      title: title,
      titleFontSize: 16,
      creditCategory: CreditCategory.storageMb,
      resizeToAvoidBottomInset: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildBody()),
          if (!_loading && _loadError == null) _buildActions(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: AutobusLoadingIndicator(size: 32));
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: LightScreenTheme.body,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _load,
                child: Text(
                  'Retry',
                  style: GoogleFonts.poppins(color: LightScreenTheme.accent),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        children: [
          if (_coverPhoto != null) ...[
            _ProductCoverImage(
              photo: _coverPhoto!,
              onTap: () => _onPhotoTap(_coverPhoto!),
            ),
            const SizedBox(height: 16),
          ],
          if (_inventoryId != null && _inventoryId!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'SKU: $_inventoryId',
                style: GoogleFonts.poppins(
                  color: LightScreenTheme.muted,
                  fontSize: 12,
                ),
              ),
            ),
          ProductExistingGallery(
            photos: _photos,
            busy: _photoBusy,
            onAddPhotos: _addPhotos,
            onAddVideos: _addVideos,
            onPhotoTap: _onPhotoTap,
          ),
          const SizedBox(height: 20),
          _textField(
            controller: _nameCtrl,
            label: 'Name',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
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
                  onChanged: (code) async {
                    setState(() => _currency = code);
                    try {
                      await saveBusinessCurrency(
                        context.read<ApiService>(),
                        code,
                      );
                    } catch (_) {}
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _textField(
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
              ),
            ],
          ),
          const SizedBox(height: 14),
          _textField(controller: _categoryCtrl, label: 'Category'),
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
          _textField(controller: _linkCtrl, label: 'Product link'),
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
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      onTapOutside: dismissAppKeyboard,
      style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
      cursorColor: LightScreenTheme.accent,
      decoration: _fieldDecoration(label),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: _saving ? null : _save,
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
                    'Save changes',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _saving ? null : _confirmDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.7)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Delete product',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCoverImage extends StatelessWidget {
  final ProductGalleryPhoto photo;
  final VoidCallback onTap;

  const _ProductCoverImage({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: ColoredBox(
            color: LightScreenTheme.surface,
            child: productRemoteImage(photo.url, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}
