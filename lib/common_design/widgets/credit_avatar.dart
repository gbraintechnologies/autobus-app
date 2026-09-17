import 'package:autobus/common_design/credit_category.dart';
import 'package:autobus/common_design/manage_screen_style.dart';
import 'package:autobus/features/home/services/api_service.dart';
import 'package:autobus/features/settings/manage_subscription.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autobus/icons/figma_icons.dart';

/// Compact header chip showing remaining credits for one category.
/// Tapping navigates to the subscription page for full credit breakdown.
class CreditAvatar extends StatefulWidget {
  final String creditCategory;

  const CreditAvatar({super.key, required this.creditCategory});

  @override
  State<CreditAvatar> createState() => _CreditAvatarState();
}

class _CreditAvatarState extends State<CreditAvatar> {
  double? _remaining;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<ApiService>().getMyCredits();
      if (!mounted) return;
      final wallet = data?['wallet'];
      if (wallet is Map) {
        final rem = wallet['remaining'];
        setState(() {
          _remaining = rem is num
              ? rem.toDouble()
              : double.tryParse(rem?.toString() ?? '');
          _loading = false;
        });
        return;
      }
      final credits = data?['credits'];
      if (credits is Map) {
        final item = credits[widget.creditCategory];
        if (item is Map) {
          final rem = item['remaining'];
          setState(() {
            _remaining = rem is num
                ? rem.toDouble()
                : double.tryParse(rem?.toString() ?? '');
            _loading = false;
          });
          return;
        }
      }
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _displayValue() {
    if (_loading) return '…';
    if (_remaining == null) return '—';
    final v = _remaining!;
    if (widget.creditCategory == CreditCategory.storageMb) {
      if (v >= 1024) return '${(v / 1024).toStringAsFixed(1)}G';
      return '${v.toStringAsFixed(0)}M';
    }
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
  }

  void _openSubscription() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: kManageSubscriptionRouteName),
        builder: (_) => const ManageSubscriptionPage(),
      ),
    );
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
                  Text(
                    _displayValue(),
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    short,
                    style: GoogleFonts.montserrat(
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
