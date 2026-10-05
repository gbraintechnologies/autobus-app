import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/credits_store.dart';
import 'package:autobus/common_design/widgets/app_screen_header.dart';
import 'package:autobus/icons/figma_icons.dart';

/// Header credits badge — Figma `3240:3112` (Notification pill).
class CreditsPill extends StatefulWidget {
  final double scale;
  final String creditCategory;

  const CreditsPill({
    super.key,
    required this.scale,
    required this.creditCategory,
  });

  static const pillColor = Color(0xFFF8FAFC);
  static const textColor = Color(0xFF64748B);

  @override
  State<CreditsPill> createState() => _CreditsPillState();
}

class _CreditsPillState extends State<CreditsPill> {
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
    final text = remaining == remaining.roundToDouble()
        ? remaining.toStringAsFixed(0)
        : remaining.toStringAsFixed(1);
    return '$text credits';
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
    final headerScale = widget.scale.clamp(0.9, 1.0);
    final iconSize = 20 * headerScale;
    final pillHeight = 37 * headerScale;
    final maxWidth = AppScreenHeader.sideSlotWidthFor(widget.scale);

    return Material(
      color: CreditsPill.pillColor,
      borderRadius: BorderRadius.circular(100),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openSubscription,
        borderRadius: BorderRadius.circular(100),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: pillHeight,
            maxWidth: maxWidth,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              5 * headerScale,
              5 * headerScale,
              8 * headerScale,
              5 * headerScale,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
              FigmaSvgIcon(
                FigmaIcons.token,
                size: iconSize,
              ),
                SizedBox(width: 3 * headerScale),
                Flexible(
                  child: ValueListenableBuilder<double?>(
                    valueListenable: _store.walletRemaining,
                    builder: (context, remaining, _) => Text(
                      _displayValue(remaining),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: CreditsPill.textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
