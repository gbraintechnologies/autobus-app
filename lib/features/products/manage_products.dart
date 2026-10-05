import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_hub_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/home_figma_icons.dart';
class ManageProducts extends StatefulWidget {
  const ManageProducts({super.key});

  @override
  State<ManageProducts> createState() => _ManageProductsState();
}

class _ManageProductsState extends State<ManageProducts> {
  bool _loadRequested = false;
  bool _loading = true;
  String? _loadError;
  bool _hasCatalogueFiles = false;

  String _shortError(String raw, {int max = 160}) {
    final t = raw.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  Future<void> _loadCataloguePresence() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiService>();
      // Prefer listed storefront products; fall back to uploaded catalogue docs.
      final products = await api.listProducts(skip: 0, limit: 1);
      var hasCatalogue = products.isNotEmpty;
      if (!hasCatalogue) {
        final files = await api.listMyStorageFiles(
          folder: ApiService.productCatalogStorageFolder,
        );
        hasCatalogue = files.isNotEmpty;
      }
      if (!mounted) return;
      setState(() {
        _hasCatalogueFiles = hasCatalogue;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e, fallback: AppUserMessages.load);
        _loading = false;
        _hasCatalogueFiles = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadRequested) return;
    _loadRequested = true;
    _loadCataloguePresence();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Manage Products',
      creditCategory: CreditCategory.storageMb,
      body: SingleChildScrollView(
        padding: LightScreenTheme.hubPagePadding(scale),
        child: Column(
          children: [
            Text(
              'Welcome to Products',
              textAlign: TextAlign.center,
              style: LightScreenTheme.hubTitle(scale),
            ),
            SizedBox(height: LightScreenTheme.hubTitleGap * scale),
            Text(
              'Add products, manage stock, and share them to your catalog and social channels.',
              textAlign: TextAlign.center,
              style: LightScreenTheme.hubBody(scale).copyWith(
                color: const Color(0xFF4E4E4E),
              ),
            ),
            SizedBox(height: LightScreenTheme.hubToCards * scale),
            if (_loading) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8 * scale),
                child: const Center(
                  child: AutobusLoadingIndicator(size: 28),
                ),
              ),
              SizedBox(height: LightScreenTheme.sectionGap * scale),
            ] else if (_loadError != null) ...[
              _ProductNoticePanel(
                scale: scale,
                icon: HomeFigmaIcons.cloudOff,
                iconColor: LightScreenTheme.warning,
                trailing: IconButton(
                  onPressed: _loadCataloguePresence,
                  icon: HomeSfIcon(
                    icon: HomeFigmaIcons.refresh,
                    color: LightScreenTheme.accent,
                    size: 22 * scale,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: 32 * scale,
                    minHeight: 32 * scale,
                  ),
                ),
                child: Text(
                  'Could not verify your product catalogue.\n${_shortError(_loadError!)}',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF4E4E4E),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                  ),
                ),
              ),
              SizedBox(height: LightScreenTheme.hubToCards * scale),
            ] else if (!_hasCatalogueFiles) ...[
              _ProductNoticePanel(
                scale: scale,
                icon: HomeFigmaIcons.warning,
                iconColor: const Color(0xFFE3800E),
                child: Text(
                  'You have no product in your catalogue',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF4E4E4E),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(height: LightScreenTheme.hubToCards * scale),
            ] else
              SizedBox(height: LightScreenTheme.rowGap * scale),
            LightHubGrid(
              scale: scale,
              children: [
                LightHubCard(
                  scale: scale,
                  title: 'Add Product',
                  subtitle: 'New products',
                  icon: HomeFigmaIcons.addProduct,
                  iconGradient: HomeFigmaIcons.addProductGradient,
                  onTap: () {
                    Navigator.push<bool?>(
                      context,
                      MaterialPageRoute<bool?>(
                        builder: (context) => const AddProductScreen(),
                      ),
                    ).then((created) {
                      if (created == true && mounted) {
                        _loadCataloguePresence();
                      }
                    });
                  },
                ),
                LightHubCard(
                  scale: scale,
                  title: 'View Product',
                  subtitle: 'Added products',
                  icon: HomeFigmaIcons.viewProducts,
                  iconGradient: HomeFigmaIcons.viewProductsGradient,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => const ViewProductsPage(),
                      ),
                    ).then((_) {
                      if (mounted) _loadCataloguePresence();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductNoticePanel extends StatelessWidget {
  final double scale;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final Widget child;

  const _ProductNoticePanel({
    required this.scale,
    required this.icon,
    required this.iconColor,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 71 * scale),
      padding: EdgeInsets.symmetric(
        horizontal: 20 * scale,
        vertical: 16 * scale,
      ),
      decoration: BoxDecoration(
        color: LightScreenTheme.surface,
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Row(
        children: [
          HomeSfIcon(icon: icon, color: iconColor, size: 28 * scale),
          SizedBox(width: 10 * scale),
          Expanded(child: child),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
