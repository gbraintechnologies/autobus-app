import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/features/subscription/saved_payment_method.dart';

/// Saved payment methods — Figma [Payment method](`3548:94`).
class PaymentMethodPage extends StatefulWidget {
  const PaymentMethodPage({super.key});

  static const _nameColor = Color(0xFF161616);
  static const _detailColor = Color(0xFF0B3C5D);
  static const _cardFill = Color(0xFFF8FAFC);

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  List<SavedPaymentMethod> _methods = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _methods.isEmpty;
      _error = null;
    });
    try {
      final rows = await context.read<ApiService>().listPaymentMethods();
      if (!mounted) return;
      setState(() {
        _methods = rows.map(SavedPaymentMethod.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(e, action: 'loading payment methods');
        _loading = false;
      });
    }
  }

  Future<void> _openAdd() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const AddPaymentMethodPage()),
    );
    if (mounted) _load();
  }

  Future<bool> _confirmRemove(SavedPaymentMethod method) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Remove payment method?',
          style: GoogleFonts.poppins(
            fontSize: LightScreenTheme.typeTitle,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Text(
          method.detail.isEmpty ? method.name : method.detail,
          style: GoogleFonts.poppins(
            fontSize: LightScreenTheme.typeBody,
            color: LightScreenTheme.body,
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
              'Remove',
              style: GoogleFonts.poppins(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return false;
    try {
      await context.read<ApiService>().deletePaymentMethod(method.id);
      return true;
    } catch (e) {
      if (mounted) showAppSnackBar(context, userFacingError(e));
      return false;
    }
  }

  Widget _buildList(double scale) {
    if (_loading) {
      return const Center(child: AutobusLoadingIndicator(size: 32));
    }
    final message =
        _error ?? (_methods.isEmpty ? 'No payment methods yet.' : null);
    if (message != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 26 * scale),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
          Text(
            message,
            textAlign: TextAlign.center,
            style: LightScreenTheme.emptyState(scale),
          ),
          if (_error != null)
            Center(
              child: TextButton(
                onPressed: _load,
                child: Text(
                  'Retry',
                  style: GoogleFonts.poppins(color: LightScreenTheme.accent),
                ),
              ),
            ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        26 * scale,
        20 * scale,
        26 * scale,
        24 * scale,
      ),
      itemCount: _methods.length,
      separatorBuilder: (_, __) => SizedBox(height: 8 * scale),
      itemBuilder: (context, index) {
        final method = _methods[index];
        return Dismissible(
          key: ValueKey(method.id.isEmpty ? index : method.id),
          direction: method.id.isEmpty
              ? DismissDirection.none
              : DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmRemove(method),
          onDismissed: (_) => setState(() {
            _methods = List.of(_methods)..remove(method);
          }),
          background: Container(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 24 * scale),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14 * scale),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
          child: _PaymentMethodCard(scale: scale, item: method),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Payment method',
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RefreshIndicator(
              color: LightScreenTheme.accent,
              onRefresh: _load,
              child: _buildList(scale),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                35 * scale,
                8 * scale,
                35 * scale,
                24 * scale,
              ),
              child: _AddPaymentButton(scale: scale, onPressed: _openAdd),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final double scale;
  final SavedPaymentMethod item;

  const _PaymentMethodCard({required this.scale, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86 * scale,
      padding: EdgeInsets.symmetric(horizontal: 22 * scale),
      decoration: BoxDecoration(
        color: PaymentMethodPage._cardFill,
        borderRadius: BorderRadius.circular(14 * scale),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(item.logoRadius * scale),
            child: Image.asset(
              item.logoAsset,
              width: 46 * scale,
              height: 36 * scale,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 20 * scale),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: PaymentMethodPage._nameColor,
                    fontSize: LightScreenTheme.typeBody,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  item.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: PaymentMethodPage._detailColor,
                    fontSize: LightScreenTheme.typeLabel,
                    fontWeight: FontWeight.w400,
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

class _AddPaymentButton extends StatelessWidget {
  final double scale;
  final VoidCallback onPressed;

  const _AddPaymentButton({required this.scale, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LightScreenTheme.button,
      borderRadius: BorderRadius.circular(30 * scale),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: double.infinity,
          height: 64 * scale,
          child: Center(
            child: Text(
              'Add payment method',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: LightScreenTheme.typeTitle,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
