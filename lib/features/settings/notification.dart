import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_list_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/home_figma_icons.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final ApiService _apiService;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool showNotifications = true;
  bool smsNotifications = true;
  String sound = "Pulse";

  @override
  void initState() {
    super.initState();
    _apiService = context.read<ApiService>();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _apiService.getUserProfile();
      if (!mounted) return;

      final inApp =
          user['in_app_notification'] ??
          user['in_app_notifications'];
      final sms =
          user['sms_notification'] ??
          user['sms_notifications'] ??
          user['sms_nofiticaitons'];

      setState(() {
        showNotifications = inApp is bool ? inApp : true;
        smsNotifications = sms is bool ? sms : true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = userFacingError(e, fallback: AppUserMessages.load));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persist({
    bool? inAppNotifications,
    bool? smsNotifications,
    required VoidCallback rollback,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _apiService.patchMyNotificationSettings(
        inAppNotification: inAppNotifications,
        smsNotification: smsNotifications,
      );

      final updated = await _apiService.getUserProfile();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updated));
      } catch (_) {}
    } catch (e) {
      rollback();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingError(e, fallback: AppUserMessages.save)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Notifications',
      creditCategory: CreditCategory.server,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20 * scale,
          20 * scale,
          20 * scale,
          32 * scale,
        ),
        child: LightListCard(
          scale: scale,
          padding: EdgeInsets.symmetric(vertical: 4 * scale),
          child: Column(
            children: [
              if (_loading)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * scale,
                    vertical: 10 * scale,
                  ),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: LightScreenTheme.accent,
                  ),
                ),
              if (_error != null && _error!.trim().isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * scale,
                    vertical: 8 * scale,
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.poppins(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              _PreferenceSwitchTile(
                scale: scale,
                title: 'Show Notifications',
                value: showNotifications,
                enabled: !(_loading || _saving),
                onChanged: (val) {
                  final prev = showNotifications;
                  setState(() => showNotifications = val);
                  _persist(
                    inAppNotifications: val,
                    rollback: () => setState(() => showNotifications = prev),
                  );
                },
              ),
              ListTile(
                onTap: () {},
                contentPadding: EdgeInsets.symmetric(horizontal: 16 * scale),
                title: Text('Sound', style: LightScreenTheme.listTitle(scale)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sound,
                      style: LightScreenTheme.listSubtitle(scale),
                    ),
                    SizedBox(width: 6 * scale),
                    HomeSfIcon(
                      icon: HomeFigmaIcons.chevronRight,
                      color: LightScreenTheme.muted,
                      size: 20 * scale,
                    ),
                  ],
                ),
              ),
              _PreferenceSwitchTile(
                scale: scale,
                title: 'SMS Notifications',
                value: smsNotifications,
                enabled: !(_loading || _saving),
                onChanged: (val) {
                  final prev = smsNotifications;
                  setState(() => smsNotifications = val);
                  _persist(
                    smsNotifications: val,
                    rollback: () => setState(() => smsNotifications = prev),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferenceSwitchTile extends StatelessWidget {
  final double scale;
  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _PreferenceSwitchTile({
    required this.scale,
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 12 * scale,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: LightScreenTheme.listTitle(scale)),
            ),
            _AnimatedToggleSwitch(value: value, enabled: enabled),
          ],
        ),
      ),
    );
  }
}

class _AnimatedToggleSwitch extends StatelessWidget {
  final bool value;
  final bool enabled;

  const _AnimatedToggleSwitch({required this.value, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final trackColor = value
        ? CustColors.mainCol
        : Colors.black.withValues(alpha: 0.12);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.55,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 58,
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: trackColor,
          boxShadow: [
            BoxShadow(
              color: trackColor.withValues(alpha: value ? 0.28 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              value ? Icons.check_rounded : Icons.remove_rounded,
              size: 16,
              color: value ? CustColors.mainCol : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }
}
