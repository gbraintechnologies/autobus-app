import 'package:autobus/barrel.dart';

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
      _productsError = productsErr == null ? null : userFacingError(productsErr);
      _loadError = docsErr == null ? null : userFacingError(docsErr);
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
        SnackBar(content: Text('Deleted "$name"', style: GoogleFonts.outfit())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(e),
            style: GoogleFonts.outfit(),
          ),
        ),
      );
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
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

  Widget _productCard(Map<String, dynamic> p) {
    final category = _productCategory(p);
    final stock = _stockLabel(p);
    return GestureDetector(
      onTap: () => _openProduct(context, p),
      behavior: HitTestBehavior.opaque,
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF3F1163), width: 1),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _productName(p),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                _productPriceLabel(p),
                style: GoogleFonts.outfit(
                  color: const Color(0xFFA855F7),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (stock != null) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    stock,
                    textAlign: TextAlign.end,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (category != null) ...[
            const SizedBox(height: 8),
            Text(
              category,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w300,
              ),
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

  Widget _emptyStateList() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
        Center(
          child: Text(
            'No products yet',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _productSectionChildren() {
    if (_products.isEmpty) return [];
    return [
      _sectionTitle('Products'),
      ..._products.map(_productCard),
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _catalogueSectionChildren() {
    if (_documents.isEmpty && _loadError == null) return [];
    return [
      _sectionTitle('Catalogue files'),
      if (_loadError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _loadError!,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: _loadAll,
                child: Text(
                  'Retry',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFA855F7),
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
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _expandedIndex = isExpanded ? null : index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.all(isExpanded ? 32 : 24),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF3F1163), width: 1),
                  borderRadius: BorderRadius.circular(isExpanded ? 38 : 30),
                ),
                child: isExpanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (key != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              key,
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 11,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () => _deleteAt(index),
                              child: Text(
                                'Delete file',
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w300,
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
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (key != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 11,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          );
        }),
    ];
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ManageScreenBackButton(),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          'Product catalogue',
                          style: ManageScreenStyle.headerTitleStyle(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child:                             const AutobusLoadingIndicator(size: 32),
                          )
                        : _blockingError != null && _hasNothingToShow
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    _blockingError!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: _loadAll,
                                  child: Text(
                                    'Retry',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFA855F7),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFFA855F7),
                            onRefresh: _loadAll,
                            child: _showEmptyState
                                ? _emptyStateList()
                                : ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      ..._productSectionChildren(),
                                      ..._catalogueSectionChildren(),
                                    ],
                                  ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
