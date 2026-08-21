import 'package:autobus/barrel.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:autobus/features/onboarding/onboarding_storage.dart';

import 'services/subscription_storage.dart';

class SubscriptionBillPage extends StatefulWidget {
  final SubscriptionPlan plan;
  final String userEmail;
  final bool isUpgrade;
  /// When non-null, success pops the stack back to this [RouteSettings.name] instead of [Welcome].
  final String? successPopUntilRouteName;

  const SubscriptionBillPage({
    required this.plan,
    required this.userEmail,
    this.isUpgrade = false,
    this.successPopUntilRouteName,
    super.key,
  });

  @override
  State<SubscriptionBillPage> createState() => _SubscriptionBillPageState();
}

class _SubscriptionBillPageState extends State<SubscriptionBillPage> {
  late BillingOption _selected;
  final _storage = SubscriptionStorage();
  bool _isLoading = false;

  String? _fullname;
  String? _email;
  String? _phone;
  Map<String, ProductDetails> _storeProducts = {};
  bool _storeProductsReady = false;

  Future<void> _finalizeSubscription({
    required ApiService api,
    required ScaffoldMessengerState messenger,
    required SuccessBloc successBloc,
    required NavigatorState navigator,
    required String reference,
    bool verifyPaystackPayment = true,
  }) async {
    if (verifyPaystackPayment) {
      final verified = await api.verifyPaystackTransaction(reference);

      if (!verified) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Payment verification failed.')),
        );
        return;
      }
    }

    var phone = (_phone ?? '').trim();
    if (phone.isEmpty) {
      try {
        final user = await api.getUserProfile();
        phone =
            (user['phone'] ??
                    user['phone_number'] ??
                    user['user_phone'] ??
                    user['mobile'] ??
                    user['msisdn'] ??
                    '')
                .toString()
                .trim();
        if (mounted && phone.isNotEmpty) {
          setState(() => _phone = phone);
        }
      } catch (_) {}
    }

    if (phone.isEmpty && !widget.isUpgrade) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Phone number is required to activate your subscription. Please add your phone number in your profile and try again.',
          ),
        ),
      );
      return;
    }

    final bool upgraded;
    if (widget.isUpgrade) {
      upgraded = await api.upgradeMySubscription(
        newPlanId: widget.plan.id,
        paymentReference: reference,
      );
    } else {
      upgraded = await api.subscribeToPlan(
        planId: widget.plan.id.toString(),
        billingId: _selected.id.toString(),
        reference: reference,
        phone: phone,
      );
    }

    if (!upgraded) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.isUpgrade
                ? 'Plan change failed. Check that you chose a higher-priced plan.'
                : 'Subscription activation failed.',
          ),
        ),
      );
      return;
    }

    await _persistAndNavigate(
      messenger: messenger,
      successBloc: successBloc,
      navigator: navigator,
    );
  }

  Future<void> _persistAndNavigate({
    required ScaffoldMessengerState messenger,
    required SuccessBloc successBloc,
    required NavigatorState navigator,
  }) async {
    try {
      await _storage.saveSelection(
        planId: widget.plan.id.toString(),
        billingId: _selected.id,
      );
      await _storage.savePlanSnapshot(widget.plan, _selected);
    } catch (e) {
      debugPrint('Failed to persist subscription snapshot: $e');
    }

    if (!mounted) return;
    // Avoid ShowSuccessEvent here: Signup (and other screens) listen to
    // SuccessBloc and would push the generic Success page on top after Paystack
    // closes. Subscription completion goes straight to Welcome.
    successBloc.add(ClearSuccessEvent());

    final popName = widget.successPopUntilRouteName?.trim();
    if (popName != null && popName.isNotEmpty) {
      navigator.popUntil(
        (route) => route.settings.name == popName || route.isFirst,
      );
      return;
    }

    try {
      final api = context.read<ApiService>();
      final user = await api.getUserProfile();
      if (!mounted) return;

      final userKey = OnboardingStorage.userKeyFromMap(user);
      final showWelcome =
          userKey.isNotEmpty &&
          !await OnboardingStorage().hasCompletedWelcome(userKey);

      if (showWelcome) {
        navigator.pushReplacement(
          PageTransition(
            type: PageTransitionType.rightToLeftWithFade,
            duration: const Duration(milliseconds: 600),
            child: const Welcome(),
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('Welcome routing fallback after subscription: $e');
      if (!widget.isUpgrade) {
        navigator.pushReplacement(
          PageTransition(
            type: PageTransitionType.rightToLeftWithFade,
            duration: const Duration(milliseconds: 600),
            child: const Welcome(),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    navigator.pushReplacement(Home.routeFromWelcome());
  }

  @override
  void initState() {
    super.initState();
    _selected = widget.plan.billing.first;
    _loadUserProfile();
    _loadStoreProducts();
  }

  Future<void> _loadStoreProducts() async {
    if (!AppleIapIds.isSupported) {
      setState(() => _storeProductsReady = true);
      return;
    }
    final ids = widget.plan.appleProductIds.values
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    final products = await AppleIapService.instance.queryProducts(ids);
    if (!mounted) return;
    setState(() {
      _storeProducts = products;
      _storeProductsReady = true;
    });
  }

  String _priceLabel(BillingOption option) {
    if (AppleIapIds.isSupported) {
      final productId = widget.plan.appleProductIdFor(option.id);
      final product = productId == null ? null : _storeProducts[productId];
      if (product != null) return product.price;
      if (!_storeProductsReady) return '…';
      return 'Unavailable';
    }
    return '\$ ${option.price.toStringAsFixed(0)}';
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await context.read<ApiService>().getUserProfile();
      if (!mounted) return;
      setState(() {
        _fullname = (user['fullname'] ?? user['name'] ?? '').toString();
        _email = (user['email'] ?? user['user_email'] ?? '').toString();
        _phone =
            (user['phone'] ??
                    user['phone_number'] ??
                    user['user_phone'] ??
                    user['mobile'] ??
                    user['msisdn'] ??
                    '')
                .toString();
      });
    } catch (_) {}
  }

  /// True when Paystack init would send a zero amount, or the user picked an explicit free tier.
  bool _skipPaystackForSelectedBilling() {
    if ((_selected.price * 100).toInt() <= 0) return true;
    final id = _selected.id.toLowerCase().trim();
    final label = _selected.label.toLowerCase().trim();
    return id == 'free' || label == 'free';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleAppleIap({
    required ScaffoldMessengerState messenger,
    required SuccessBloc successBloc,
    required NavigatorState navigator,
  }) async {
    final productId = widget.plan.appleProductIdFor(_selected.id);
    final product = productId == null ? null : _storeProducts[productId];
    if (product == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            productId == null
                ? 'This plan is not configured for the App Store.'
                : 'App Store product "$productId" is not available yet. Create it in App Store Connect and try again.',
          ),
        ),
      );
      return;
    }

    final result = await AppleIapService.instance.purchaseAndActivate(
      product: product,
      planId: widget.plan.id,
      billingId: _selected.id,
      phone: _phone,
    );
    if (!mounted) return;
    if (result.cancelled) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Purchase was cancelled.')),
      );
      return;
    }
    if (!result.success) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.error ?? 'App Store purchase failed.')),
      );
      return;
    }
    await _persistAndNavigate(
      messenger: messenger,
      successBloc: successBloc,
      navigator: navigator,
    );
  }

  Future<void> _restoreApplePurchases() async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final successBloc = context.read<SuccessBloc>();
    final navigator = Navigator.of(context);
    try {
      final result = await AppleIapService.instance.restoreActiveSubscription(
        planId: widget.plan.id,
        billingId: _selected.id,
      );
      if (!mounted) return;
      if (!result.success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'No Apple subscription to restore.'),
          ),
        );
        return;
      }
      await _persistAndNavigate(
        messenger: messenger,
        successBloc: successBloc,
        navigator: navigator,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSubscription() async {
    setState(() => _isLoading = true);

    try {
      final api = context.read<ApiService>();
      final messenger = ScaffoldMessenger.of(context);
      final successBloc = context.read<SuccessBloc>();
      final navigator = Navigator.of(context);

      final skipPaystack = _skipPaystackForSelectedBilling();

      if (AppleIapIds.isSupported && !skipPaystack) {
        await _handleAppleIap(
          messenger: messenger,
          successBloc: successBloc,
          navigator: navigator,
        );
        return;
      }

      final paystack = context.read<PaystackService>();

      var userEmail = widget.userEmail.trim();
      if (userEmail.isEmpty) userEmail = (_email ?? '').trim();
      if (userEmail.isEmpty) {
        try {
          final user = await api.getUserProfile();
          userEmail = (user['email'] ?? user['user_email'] ?? '')
              .toString()
              .trim();
        } catch (_) {}
      }

      debugPrint('email resolved: "$userEmail"');
      if (!skipPaystack && userEmail.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Email is required to initialize payment. Please update your profile email and try again.',
            ),
          ),
        );
        return;
      }

      if (!skipPaystack && AppConfig.paystackCallbackUrl.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Missing PAYSTACK_CALLBACK_URL. Set it in .env and ensure it matches your Paystack dashboard redirect/callback.',
            ),
          ),
        );
      }

      if (skipPaystack) {
        final freeRef =
            'free_${widget.plan.id}_${_selected.id}_${DateTime.now().millisecondsSinceEpoch}';
        await _finalizeSubscription(
          api: api,
          messenger: messenger,
          successBloc: successBloc,
          navigator: navigator,
          reference: freeRef,
          verifyPaystackPayment: false,
        );
        return;
      }

      // Step 1 — initialize transaction on your backend
      final init = await api.initializePaystackTransaction(
        email: userEmail,
        amount: _selected.price,
      );

      if (!mounted || init == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to initialize payment.')),
        );
        return;
      }

      var handled = false;

      // Step 2 — launch Paystack UI
      await paystack.launch(
        context: context,
        email: userEmail,
        reference: init.reference,
        amount: _selected.price.toInt(),
        callbackUrl: AppConfig.paystackCallbackUrl,
        authorizationUrl: init.authorizationUrl,
        onSuccess: () async {
          if (handled) return;
          handled = true;
          await _finalizeSubscription(
            api: api,
            messenger: messenger,
            successBloc: successBloc,
            navigator: navigator,
            reference: init.reference,
          );
        },
        onCancelled: () async {
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('Payment was not completed.')),
          );
        },
      );

      // Fallback: if callback URL was not detected, still verify after WebView closes.
      if (!handled) {
        handled = true;
        await _finalizeSubscription(
          api: api,
          messenger: messenger,
          successBloc: successBloc,
          navigator: navigator,
          reference: init.reference,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(userFacingError(e, action: 'starting payment')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // String _getPlanCode(String planId, String billingId) {
  //   const codes = {'pro_monthly': 'PLN_xxxx', 'pro_annual': 'PLN_yyyy'};
  //   return codes['${planId}_$billingId'] ?? '';
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Subscription Bill',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '${widget.plan.name} \nAccount',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  height: 62,
                  width: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(31),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                _AccountMeta(
                  fullname: _fullname,
                  email: widget.userEmail,
                  phone: _phone,
                ),
                const SizedBox(height: 22),
                _BillingSelector(
                  options: widget.plan.billing,
                  selectedId: _selected.id,
                  onSelect: (opt) => setState(() => _selected = opt),
                  priceLabel: _priceLabel,
                ),
                const SizedBox(height: 18),
                if (AppleIapIds.isSupported) ...[
                  Text(
                    'Payment will be charged to your Apple ID at confirmation. '
                    'Subscription automatically renews unless cancelled at least '
                    '24 hours before the end of the current period. Manage or cancel '
                    'in your Apple ID account settings.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    children: [
                      TextButton(
                        onPressed: () => _openUrl(AppConfig.privacyPolicyUrl),
                        child: Text(
                          'Privacy Policy',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openUrl(AppConfig.termsOfServiceUrl),
                        child: Text(
                          'Terms of Use',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _restoreApplePurchases,
                    child: Text(
                      'Restore Purchases',
                      style: GoogleFonts.montserrat(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _isLoading
                    ? const AutobusLoadingIndicator(size: 28)
                    : _BottomCta(
                        label: AppleIapIds.isSupported
                            ? 'Subscribe'
                            : 'Subscribe Now',
                        onPressed: _handleSubscription,
                      ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountMeta extends StatelessWidget {
  final String? fullname;
  final String email;
  final String? phone;

  const _AccountMeta({
    required this.fullname,
    required this.email,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle metaStyle(Color c) => GoogleFonts.montserrat(
      color: c,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );

    return Column(
      children: [
        if (fullname != null && fullname!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              fullname!,
              style: metaStyle(Colors.white.withOpacity(0.9)),
            ),
          ),
        Text(email, style: metaStyle(Colors.white.withOpacity(0.75))),
        if (phone != null && phone!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(phone!, style: metaStyle(Colors.white.withOpacity(0.75))),
        ],
      ],
    );
  }
}

class _BillingSelector extends StatelessWidget {
  final List<BillingOption> options;
  final String selectedId;
  final ValueChanged<BillingOption> onSelect;
  final String Function(BillingOption option)? priceLabel;

  const _BillingSelector({
    required this.options,
    required this.selectedId,
    required this.onSelect,
    this.priceLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < options.length; i++) ...[
            Expanded(
              child: _BillingOptionTile(
                option: options[i],
                active: options[i].id == selectedId,
                onTap: () => onSelect(options[i]),
                priceLabel: priceLabel?.call(options[i]),
              ),
            ),
            if (i != options.length - 1)
              Container(
                width: 1,
                height: 74,
                color: Colors.white.withOpacity(0.18),
              ),
          ],
        ],
      ),
    );
  }
}

class _BillingOptionTile extends StatelessWidget {
  final BillingOption option;
  final bool active;
  final VoidCallback onTap;
  final String? priceLabel;

  const _BillingOptionTile({
    required this.option,
    required this.active,
    required this.onTap,
    this.priceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? Colors.white.withOpacity(0.1) : Colors.transparent;
    final labelColor = active ? Colors.white : Colors.white.withOpacity(0.82);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              option.label,
              style: GoogleFonts.montserrat(
                color: labelColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              option.subtitle,
              style: GoogleFonts.montserrat(
                color: labelColor.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              priceLabel ?? '\$ ${option.price.toStringAsFixed(0)}',
              style: GoogleFonts.montserrat(
                color: labelColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomCta extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _BottomCta({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withOpacity(0.7)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 34),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.chevron_right, color: Colors.white, size: 18),
                  Icon(Icons.chevron_right, color: Colors.white54, size: 18),
                  Icon(Icons.chevron_right, color: Colors.white38, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientBackground extends StatelessWidget {
  final Widget child;
  const _GradientBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF130522), Color(0xFF2D0C51), Color(0xFF130522)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}
