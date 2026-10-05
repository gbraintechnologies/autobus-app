import 'package:autobus/common_design/credits_store.dart';
import 'package:autobus/common_design/manage_screen_style.dart';
import 'package:autobus/features/home/services/api_service.dart';
import 'package:autobus/features/settings/manage_subscription.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autobus/icons/figma_icons.dart';

/// Compact header chip showing the shared wallet balance.
/// Tapping navigates to the subscription page for full credit breakdown.
class CreditAvatar extends StatefulWidget {
  final String creditCategory;

  const CreditAvatar({super.key, required this.creditCategory});

  @override
  State<CreditAvatar> createState() => _CreditAvatarState();
}

class _CreditAvatarState extends State<CreditAvatar> {
  final _store = CreditsStore.instance;
  late bool _loading = !_store.hasLoaded;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh({bool force = false}) async {
    await _store.refresh(context.read<ApiService>(), force: force);
    if (mounted && _loading) setState(() => _loading = false);
  }

  String _displayValue(double? remaining) {
    if (remaining == null) return _loading ? '…' : '—';
    final v = remaining;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
  }

  void _openSubscription() {
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: kManageSubscriptionRouteName),
            builder: (_) => const ManageSubscriptionPage(),
          ),
        )
        .then((_) {
          if (mounted) _refresh(force: true);
        });
  }

  @override
  Widget build(BuildContext context) {
    final short = 'Credits';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openSubscription,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 48,
          constraints: const BoxConstraints(minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ManageScreenStyle.headerRingBorder),
            color: Colors.white.withValues(alpha: 0.06),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FigmaSvgIcon(
                FigmaIcons.token,
                size: 18,
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<double?>(
                    valueListenable: _store.walletRemaining,
                    builder: (context, remaining, _) => Text(
                      _displayValue(remaining),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ),
                  Text(
                    short,
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 9,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
