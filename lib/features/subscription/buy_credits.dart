import 'package:autobus/barrel.dart';
import 'package:autobus/features/subscription/models/credit_pack.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class BuyCreditsPage extends StatefulWidget {
  final String userEmail;
  final String? successPopUntilRouteName;

  const BuyCreditsPage({
    this.userEmail = '',
    this.successPopUntilRouteName,
    super.key,
  });

  @override
  State<BuyCreditsPage> createState() => _BuyCreditsPageState();
}

class _BuyCreditsPageState extends State<BuyCreditsPage> {
  List<CreditPack> _packs = [];
  Map<String, ProductDetails> _storeProducts = {};
  double _walletRemaining = 0;
  bool _loading = true;
  bool _buying = false;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final me = await api.getMyCredits();
      final rawPacks = (me?['packs'] as List?) ?? await api.getCreditPacks();
      final packs = rawPacks
          .whereType<Map>()
          .map((e) => CreditPack.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final wallet = me?['wallet'];
      final remaining = wallet is Map
          ? (wallet['remaining'] is num
                ? (wallet['remaining'] as num).toDouble()
                : double.tryParse('${wallet['remaining']}') ?? 0)
          : 0.0;

      var store = <String, ProductDetails>{};
      if (AppleIapIds.usesAppleIap) {
        final ids = packs
            .map((p) => p.storeProductId)
            .where((id) => id.isNotEmpty)
            .toSet();
        ids.addAll(AppleIapIds.creditProductIds);
        store = await AppleIapService.instance.queryProducts(ids);
      }

      if (!mounted) return;
      setState(() {
        _packs = packs;
        _storeProducts = store;
        _walletRemaining = remaining;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  CreditPack? get _selected {
    for (final pack in _packs) {
      if (pack.id == _selectedId) return pack;
    }
    return null;
  }

  String _walletLabel() {
    final v = _walletRemaining;
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  String _priceLabel(CreditPack pack) {
    return '\$${pack.priceUsd.toStringAsFixed(2)}';
  }

  String _payLabel() {
    if (AppleIapIds.usesAppleIap) return 'Pay with Apple';
    return 'Pay now';
  }

  Future<void> _returnToApp() async {
    if (!mounted) return;
    final popName = widget.successPopUntilRouteName?.trim();
    if (popName != null && popName.isNotEmpty) {
      Navigator.of(context).popUntil(
        (route) => route.settings.name == popName || route.isFirst,
      );
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).pushReplacement(Home.routeFromWelcome());
  }

  Future<void> _buyStore(CreditPack pack) async {
    final product = _storeProducts[pack.storeProductId];
    if (product == null) {
      showAppSnackBar(
        context,
        'This credit pack is not available in the App Store yet.',
      );
      return;
    }
    setState(() => _buying = true);
    try {
      final result = await AppleIapService.instance.purchaseAndActivate(
        product: product,
      );
      if (!mounted) return;
      if (result.cancelled) return;
      if (!result.success) {
        showAppSnackBar(
          context,
          result.error ?? 'Purchase could not be completed.',
        );
        return;
      }
      showAppSnackBar(
        context,
        '${pack.credits.toStringAsFixed(0)} credits added.',
        backgroundColor: CustColors.mainCol,
      );
      await _returnToApp();
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _buyPaystack(CreditPack pack) async {
    setState(() => _buying = true);
    try {
      final api = context.read<ApiService>();
      final email = widget.userEmail.trim().isNotEmpty
          ? widget.userEmail.trim()
          : (await api.getUserProfile())['email']?.toString() ?? '';
      final checkout = await api.checkoutCreditPack(
        packId: pack.id,
        email: email,
      );
      if (checkout == null || !mounted) return;
      final reference = (checkout['reference'] ?? '').toString();
      final authUrl = (checkout['authorization_url'] ?? '').toString();
      if (reference.isEmpty) {
        showAppSnackBar(context, 'Could not start checkout.');
        return;
      }
      final charged = checkout['amount'];
      final ghs = charged is num
          ? charged.toDouble()
          : double.tryParse('$charged') ?? 0;
      if (ghs <= 0) {
        showAppSnackBar(context, 'Could not start checkout.');
        return;
      }

      await PaystackService().launch(
        context: context,
        email: email,
        reference: reference,
        authorizationUrl: authUrl,
        amount: ghs,
        callbackUrl: AppConfig.paystackCallbackUrl,
        onSuccess: () async {
          final ok = await api.verifyPaystackTransaction(reference);
          if (!mounted) return;
          if (!ok) {
            showAppSnackBar(context, 'Payment verification failed.');
            return;
          }
          showAppSnackBar(
            context,
            '${pack.credits.toStringAsFixed(0)} credits added.',
            backgroundColor: CustColors.mainCol,
          );
          await _returnToApp();
        },
        onCancelled: () async {
          if (mounted) {
            showAppSnackBar(context, 'Payment cancelled.');
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        userFacingError(e, action: 'buying credits'),
      );
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _pay() async {
    final pack = _selected;
    if (pack == null) return;
    if (AppleIapIds.isAndroidApp || !AppleIapIds.usesAppleIap) {
      await _buyPaystack(pack);
      return;
    }
    await _buyStore(pack);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 244, 244, 244),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: CustColors.mainCol,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  Expanded(
                    child: AppFitText(
                      'Credits',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: AutobusLoadingIndicator(size: 36))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                        children: [
                          Text(
                            'You have ${_walletLabel()} credits',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Choose a pack to add more. Tap a pack to read about it, then pay.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black54,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 18),
                          for (final pack in _packs) ...[
                            _PackTile(
                              pack: pack,
                              price: _priceLabel(pack),
                              expanded: pack.id == _selectedId,
                              paying: _buying && pack.id == _selectedId,
                              payLabel: _payLabel(),
                              onTap: () {
                                setState(() {
                                  _selectedId = pack.id == _selectedId
                                      ? null
                                      : pack.id;
                                });
                              },
                              onPay: _buying ? null : _pay,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  final CreditPack pack;
  final String price;
  final bool expanded;
  final bool paying;
  final String payLabel;
  final VoidCallback onTap;
  final VoidCallback? onPay;

  const _PackTile({
    required this.pack,
    required this.price,
    required this.expanded,
    required this.paying,
    required this.payLabel,
    required this.onTap,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final videos = (pack.credits / 4).floor();
    final images = (pack.credits / 1.25).floor();

    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pack.name,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${pack.credits.toStringAsFixed(0)} credits',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      price,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: CustColors.mainCol,
                      ),
                    ),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(height: 12),
                  Text(
                    pack.details.isNotEmpty ? pack.details : pack.description,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'About $videos videos or $images images. Video generation uses 4 credits.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black45,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: paying ? null : onPay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CustColors.mainCol,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: CustColors.mainCol.withValues(
                          alpha: 0.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: paying
                          ? const AutobusLoadingIndicator(size: 22)
                          : Text(
                              payLabel,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
