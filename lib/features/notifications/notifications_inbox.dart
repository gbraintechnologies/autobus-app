import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_list_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';

class NotificationsInboxPage extends StatefulWidget {
  const NotificationsInboxPage({super.key});

  @override
  State<NotificationsInboxPage> createState() => _NotificationsInboxPageState();
}

class _NotificationsInboxPageState extends State<NotificationsInboxPage> {
  late Future<List<AppNotification>> _future;
  final Set<String> _markingIds = {};

  @override
  void initState() {
    super.initState();
    _future = _loadUnread();
  }

  Future<List<AppNotification>> _loadUnread() {
    return context.read<ApiService>().getUnreadNotifications();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadUnread();
    });
    await _future;
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (_markingIds.contains(notification.id)) return;
    setState(() => _markingIds.add(notification.id));
    try {
      await context.read<ApiService>().markNotificationAsRead(notification.id);
      if (!mounted) return;
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not mark notification as read',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w400),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _markingIds.remove(notification.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Notifications',
      creditCategory: CreditCategory.server,
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(color: LightScreenTheme.accent),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Failed to load notifications',
                style: LightScreenTheme.emptyState(scale),
              ),
            );
          }

          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No notifications yet',
                style: LightScreenTheme.emptyState(scale),
              ),
            );
          }

          return RefreshIndicator(
            color: LightScreenTheme.accent,
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20 * scale,
                8 * scale,
                20 * scale,
                24 * scale,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(height: 12 * scale),
              itemBuilder: (context, i) {
                final n = items[i];
                final created = n.createdAt;
                final subtitle = [
                  if (created != null)
                    '${created.toLocal()}'.split('.').first,
                ].join('\n');
                final marking = _markingIds.contains(n.id);

                return LightListCard(
                  scale: scale,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * scale,
                    vertical: 14 * scale,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 10 * scale,
                        height: 10 * scale,
                        margin: EdgeInsets.only(top: 5 * scale),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 10 * scale),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.displayText.isNotEmpty ? n.displayText : n.title,
                              style: LightScreenTheme.listTitle(scale).copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              SizedBox(height: 6 * scale),
                              Text(
                                subtitle,
                                style: LightScreenTheme.listSubtitle(scale),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      TextButton(
                        onPressed: marking ? null : () => _markAsRead(n),
                        style: TextButton.styleFrom(
                          foregroundColor: LightScreenTheme.accent,
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 * scale,
                            vertical: 4 * scale,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: marking
                            ? SizedBox(
                                width: 16 * scale,
                                height: 16 * scale,
                                child: AutobusLoadingIndicator(size: 16 * scale),
                              )
                            : Text(
                                'Mark read',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
