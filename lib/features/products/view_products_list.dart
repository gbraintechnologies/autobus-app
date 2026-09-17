import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_list_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
class ViewProductsPage extends StatefulWidget {
  const ViewProductsPage({super.key});

  @override
  State<ViewProductsPage> createState() => _ViewProductsPageState();
}

class _ViewProductsPageState extends State<ViewProductsPage> {
  List<Map<String, dynamic>> _documents = const [];
  List<Map<String, dynamic>> _products = const [];
  bool _loading = true;
  String? _loadError;
  String? _productsError;
  int? _expandedIndex;

  String _fileName(Map<String, dynamic> doc) =>
      (doc['file_name'] ?? '').toString();

  String? _objectKey(Map<String, dynamic> doc) {
    final k = doc['object_key'];
    if (k == null) return null;
    final s = k.toString();
    return s.isEmpty ? null : s;
  }

  String _productName(Map<String, dynamic> p) =>
      (p['name'] ?? 'Product').toString();

  String? _productCategory(Map<String, dynamic> p) {
    final c = p['category']?.toString().trim();
    return (c == null || c.isEmpty) ? null : c;
  }

  String _productPriceLabel(Map<String, dynamic> p) {
    final raw = p['price'];
    double? v;
    if (raw is num) {
      v = raw.toDouble();
    } else {
      v = double.tryParse(raw?.toString() ?? '');
    }
    if (v == null) return '—';
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  String? _stockLabel(Map<String, dynamic> p) {
    final n = p['number_in_stock'];
    if (n == null) return null;
    if (n is int) return 'In stock: $n';
    if (n is num) return 'In stock: ${n.toInt()}';
    return 'In stock: $n';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _productsError = null;
    });
    final api = context.read<ApiService>();

    List<Map<String, dynamic>> products = const [];
    Object? productsErr;
    try {
      products = await api.listProducts(skip: 0, limit: 200);
    } catch (e) {
      productsErr = e;
    }

    List<Map<String, dynamic>> docs = const [];
    Object? docsErr;
    try {
      docs = await api.listMyStorageFiles(
        folder: ApiService.productCatalogStorageFolder,
      );
    } catch (e) {
      docsErr = e;
    }

    if (!mounted) return;
    setState(() {
      _products = products;
      _documents = docs;
      _productsError = productsErr == null
          ? null
          : userFacingError(productsErr, fallback: AppUserMessages.load);
      _loadError = docsErr == null
          ? null
          : userFacingError(docsErr, fallback: AppUserMessages.load);
      _loading = false;
      _expandedIndex = null;
    });
  }

  Future<void> _deleteAt(int index) async {
    final doc = _documents[index];
    final name = _fileName(doc);
    if (name.isEmpty) return;
    try {
      final api = context.read<ApiService>();
      await api.deleteMyStorageFile(
        folder: ApiService.productCatalogStorageFolder,
        fileName: name,
      );
      if (!mounted) return;
      setState(() {
        _documents = List<Map<String, dynamic>>.from(_documents)
          ..removeAt(index);
        _expandedIndex = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "$name"', style: GoogleFonts.poppins()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(e),
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }
  }

  Widget _sectionTitle(double scale, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12 * scale),
      child: Text(
        text,
        style: LightScreenTheme.hubTitle(scale),
      ),
    );
  }

  void _openProduct(BuildContext context, Map<String, dynamic> p) {
    final id = (p['product_id'] ?? '').toString().trim();
    if (id.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          productId: id,
          initialName: _productName(p),
        ),
      ),
    ).then((refreshed) {
      if (refreshed == true && mounted) _loadAll();
    });
  }

  Widget _productCard(double scale, Map<String, dynamic> p) {
    final category = _productCategory(p);
    final stock = _stockLabel(p);
    return Padding(
      padding: EdgeInsets.only(bottom: 12 * scale),
      child: LightListCard(
        scale: scale,
        onTap: () => _openProduct(context, p),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _productName(p),
              style: LightScreenTheme.listTitle(scale),
            ),
            SizedBox(height: 10 * scale),
            Row(
              children: [
                Text(
                  _productPriceLabel(p),
                  style: GoogleFonts.poppins(
                    color: LightScreenTheme.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (stock != null) ...[
                  SizedBox(width: 14 * scale),
                  Expanded(
                    child: Text(
                      stock,
                      textAlign: TextAlign.end,
                      style: LightScreenTheme.listSubtitle(scale),
                    ),
                  ),
                ],
              ],
            ),
            if (category != null) ...[
              SizedBox(height: 8 * scale),
              Text(
                category,
                style: LightScreenTheme.listSubtitle(scale),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasNothingToShow => _products.isEmpty && _documents.isEmpty;

  bool get _showEmptyState =>
      _hasNothingToShow && _productsError == null && _loadError == null;

  String? get _blockingError => _productsError ?? _loadError;

  Widget _emptyStateList(double scale) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
        Center(
          child: Text(
            'No products yet',
            style: LightScreenTheme.emptyState(scale),
          ),
        ),
      ],
    );
  }

  List<Widget> _productSectionChildren(double scale) {
    if (_products.isEmpty) return [];
    return [
      _sectionTitle(scale, 'Products'),
      ..._products.map((p) => _productCard(scale, p)),
      SizedBox(height: 8 * scale),
    ];
  }

  List<Widget> _catalogueSectionChildren(double scale) {
    if (_documents.isEmpty && _loadError == null) return [];
    return [
      _sectionTitle(scale, 'Catalogue files'),
      if (_loadError != null)
        Padding(
          padding: EdgeInsets.only(bottom: 12 * scale),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _loadError!,
                  style: LightScreenTheme.emptyState(scale),
                ),
              ),
              TextButton(
                onPressed: _loadAll,
                child: Text(
                  'Retry',
                  style: GoogleFonts.poppins(
                    color: LightScreenTheme.accent,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        )
      else
        ...List.generate(_documents.length, (index) {
          final doc = _documents[index];
          final name = _fileName(doc);
          final key = _objectKey(doc);
          final isExpanded = _expandedIndex == index;

          return Padding(
            padding: EdgeInsets.only(bottom: 12 * scale),
            child: LightListCard(
              scale: scale,
              padding: EdgeInsets.all(isExpanded ? 24 * scale : 20 * scale),
              onTap: () {
                setState(() {
                  _expandedIndex = isExpanded ? null : index;
                });
              },
              child: isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: LightScreenTheme.listTitle(scale),
                        ),
                        if (key != null) ...[
                          SizedBox(height: 12 * scale),
                          Text(
                            key,
                            style: LightScreenTheme.listSubtitle(scale),
                          ),
                        ],
                        SizedBox(height: 16 * scale),
                        Center(
                          child: TextButton(
                            onPressed: () => _deleteAt(index),
                            child: Text(
                              'Delete file',
                              style: GoogleFonts.poppins(
                                color: LightScreenTheme.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: LightScreenTheme.listTitle(scale),
                        ),
                        if (key != null) ...[
                          SizedBox(height: 6 * scale),
                          Text(
                            key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LightScreenTheme.listSubtitle(scale),
                          ),
                        ],
                      ],
                    ),
            ),
          );
        }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Product catalogue',
      creditCategory: CreditCategory.storageMb,
      body: Padding(
        padding: EdgeInsets.fromLTRB(20 * scale, 20 * scale, 20 * scale, 24 * scale),
        child: _loading
            ? const Center(child: AutobusLoadingIndicator(size: 32))
            : _blockingError != null && _hasNothingToShow
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                      child: Text(
                        _blockingError!,
                        textAlign: TextAlign.center,
                        style: LightScreenTheme.emptyState(scale),
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    TextButton(
                      onPressed: _loadAll,
                      child: Text(
                        'Retry',
                        style: GoogleFonts.poppins(
                          color: LightScreenTheme.accent,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                color: LightScreenTheme.accent,
                onRefresh: _loadAll,
                child: _showEmptyState
                    ? _emptyStateList(scale)
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          ..._productSectionChildren(scale),
                          ..._catalogueSectionChildren(scale),
                        ],
                      ),
              ),
      ),
    );
  }
}
