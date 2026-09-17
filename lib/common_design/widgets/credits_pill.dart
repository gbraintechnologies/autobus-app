import 'package:autobus/barrel.dart';
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
    return '${_remaining!.round()} credits';
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
                  child: Text(
                    _displayValue(),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: CreditsPill.textColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      height: 1,
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
