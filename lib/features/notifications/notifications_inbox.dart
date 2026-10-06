import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/icons/home_figma_icons.dart';

enum _InboxFilter { all, unread }

class NotificationsInboxPage extends StatefulWidget {
  const NotificationsInboxPage({super.key});

  @override
  State<NotificationsInboxPage> createState() => _NotificationsInboxPageState();
}

class _NotificationsInboxPageState extends State<NotificationsInboxPage> {
  List<AppNotification> _items = const [];
  bool _loading = true;
  String? _error;
  _InboxFilter _filter = _InboxFilter.all;
  bool _markingAll = false;
  final Set<String> _markingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final items = await context.read<ApiService>().getNotifications();
      if (!mounted) return;
      items.sort((a, b) {
        final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingError(e, fallback: 'Could not load notifications');
      });
    }
  }

  List<AppNotification> get _visible {
    if (_filter == _InboxFilter.unread) {
      return _items.where((n) => !n.read).toList();
    }
    return _items;
  }

  int get _unreadCount => _items.where((n) => !n.read).length;

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.read || _markingIds.contains(notification.id)) return;
    setState(() => _markingIds.add(notification.id));
    try {
      await context.read<ApiService>().markNotificationAsRead(notification.id);
      if (!mounted) return;
      setState(() {
        _items = [
          for (final item in _items)
            if (item.id == notification.id) item.copyWith(read: true) else item,
        ];
      });
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
      if (mounted) setState(() => _markingIds.remove(notification.id));
    }
  }

  Future<void> _markAllRead() async {
    final pending = _items.where((n) => !n.read).toList();
    if (pending.isEmpty || _markingAll) return;
    setState(() => _markingAll = true);
    var failed = 0;
    for (final notification in pending) {
      try {
        await context.read<ApiService>().markNotificationAsRead(notification.id);
        if (!mounted) return;
        setState(() {
          _items = [
            for (final item in _items)
              if (item.id == notification.id) item.copyWith(read: true) else item,
          ];
        });
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() => _markingAll = false);
    if (failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update $failed notification${failed == 1 ? '' : 's'}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w400),
          ),
        ),
      );
    }
  }

  void _openDetail(AppNotification notification) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24 * scale)),
      ),
      builder: (sheetContext) {
        return _NotificationDetailSheet(
          notification: notification,
          scale: scale,
          onOpen: () {
            final page = _pageFor(notification.flutterPage);
            if (page == null) return;
            Navigator.of(sheetContext).pop();
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => page),
            );
          },
        );
      },
    );
    if (!notification.read) _markAsRead(notification);
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    final visible = _visible;

    return LightScreenScaffold(
      title: 'Notifications',
      creditCategory: CreditCategory.server,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InboxToolbar(
            scale: scale,
            unreadCount: _unreadCount,
            filter: _filter,
            markingAll: _markingAll,
            onFilter: (filter) => setState(() => _filter = filter),
            onMarkAll: _unreadCount == 0 ? null : _markAllRead,
          ),
          Expanded(child: _body(scale, visible)),
        ],
      ),
    );
  }

  Widget _body(double scale, List<AppNotification> visible) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: LightScreenTheme.accent),
      );
    }
    if (_error != null && _items.isEmpty) {
      return _InboxMessage(
        scale: scale,
        icon: HomeFigmaIcons.cloudOff,
        title: 'Could not load notifications',
        body: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }
    if (visible.isEmpty) {
      final unreadOnly = _filter == _InboxFilter.unread;
      return _InboxMessage(
        scale: scale,
        icon: HomeFigmaIcons.notificationBing,
        title: unreadOnly ? 'You are all caught up' : 'No notifications yet',
        body: unreadOnly
            ? 'New alerts will show up here when something needs you.'
            : 'Orders, messages, and account updates will land in this inbox.',
      );
    }

    return RefreshIndicator(
      color: LightScreenTheme.accent,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20 * scale, 4 * scale, 20 * scale, 24 * scale),
        itemCount: visible.length,
        separatorBuilder: (_, __) => SizedBox(height: 10 * scale),
        itemBuilder: (context, index) {
          final notification = visible[index];
          return _NotificationTile(
            notification: notification,
            scale: scale,
            marking: _markingIds.contains(notification.id),
            onTap: () => _openDetail(notification),
          );
        },
      ),
    );
  }
}

class _InboxToolbar extends StatelessWidget {
  final double scale;
  final int unreadCount;
  final _InboxFilter filter;
  final bool markingAll;
  final ValueChanged<_InboxFilter> onFilter;
  final VoidCallback? onMarkAll;

  const _InboxToolbar({
    required this.scale,
    required this.unreadCount,
    required this.filter,
    required this.markingAll,
    required this.onFilter,
    required this.onMarkAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 16 * scale, 20 * scale, 12 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  unreadCount == 0
                      ? 'Nothing waiting'
                      : '$unreadCount unread',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: markingAll ? null : onMarkAll,
                style: TextButton.styleFrom(
                  foregroundColor: LightScreenTheme.accent,
                  padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: markingAll
                    ? SizedBox(
                        width: 14 * scale,
                        height: 14 * scale,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: LightScreenTheme.accent,
                        ),
                      )
                    : Text(
                        'Mark all read',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ],
          ),
          SizedBox(height: 10 * scale),
          Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: filter == _InboxFilter.all,
                onTap: () => onFilter(_InboxFilter.all),
              ),
              SizedBox(width: 8 * scale),
              _FilterChip(
                label: 'Unread',
                selected: filter == _InboxFilter.unread,
                onTap: () => onFilter(_InboxFilter.unread),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE8D2F2) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: selected ? LightScreenTheme.accent : const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final double scale;
  final bool marking;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.scale,
    required this.marking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;
    final tone = _toneFor(notification);
    final title = notification.title.trim().isEmpty
        ? 'Notification'
        : notification.title.trim();
    final body = notification.body.trim();
    final showBody = body.isNotEmpty && body != title;

    return Material(
      color: LightScreenTheme.surface,
      borderRadius: BorderRadius.circular(18 * scale),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18 * scale),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.all(14 * scale),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40 * scale,
                height: 40 * scale,
                decoration: BoxDecoration(
                  color: tone.background,
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
                alignment: Alignment.center,
                child: Iconify(tone.icon, size: 20 * scale, color: tone.foreground),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (marking)
                          SizedBox(
                            width: 12 * scale,
                            height: 12 * scale,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: LightScreenTheme.accent,
                            ),
                          )
                        else if (unread)
                          Container(
                            width: 8 * scale,
                            height: 8 * scale,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (showBody) ...[
                      SizedBox(height: 4 * scale),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                        ),
                      ),
                    ],
                    SizedBox(height: 6 * scale),
                    Text(
                      _timeLabel(notification.createdAt),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationDetailSheet extends StatelessWidget {
  final AppNotification notification;
  final double scale;
  final VoidCallback onOpen;

  const _NotificationDetailSheet({
    required this.notification,
    required this.scale,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(notification);
    final title = notification.title.trim().isEmpty
        ? 'Notification'
        : notification.title.trim();
    final body = notification.body.trim();
    final destination = _pageFor(notification.flutterPage);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        22 * scale,
        12 * scale,
        22 * scale,
        24 * scale + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          SizedBox(height: 18 * scale),
          Row(
            children: [
              Container(
                width: 44 * scale,
                height: 44 * scale,
                decoration: BoxDecoration(
                  color: tone.background,
                  borderRadius: BorderRadius.circular(14 * scale),
                ),
                alignment: Alignment.center,
                child: Iconify(tone.icon, size: 22 * scale, color: tone.foreground),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2 * scale),
                    Text(
                      _timeLabel(notification.createdAt),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            SizedBox(height: 16 * scale),
            Text(
              body,
              style: GoogleFonts.poppins(
                color: const Color(0xFF334155),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          SizedBox(height: 20 * scale),
          if (destination != null)
            _SheetButton(
              label: 'Open',
              filled: true,
              onTap: onOpen,
            ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _SheetButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? LightScreenTheme.accent : const Color(0xFFF3F3F7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 46,
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: filled ? Colors.white : Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InboxMessage extends StatelessWidget {
  final double scale;
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InboxMessage({
    required this.scale,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 36 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HomeSfIcon(
              icon: icon,
              size: 36 * scale,
              color: LightScreenTheme.accent,
            ),
            SizedBox(height: 14 * scale),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 6 * scale),
            Text(
              body,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFF64748B),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 14 * scale),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: GoogleFonts.poppins(
                    color: LightScreenTheme.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tone {
  final String icon;
  final Color background;
  final Color foreground;

  const _Tone(this.icon, this.background, this.foreground);
}

_Tone _toneFor(AppNotification notification) {
  final text = '${notification.title} ${notification.body} ${notification.flutterPage ?? ''}'
      .toLowerCase();
  if (text.contains('order')) {
    return const _Tone(Ph.storefront, Color(0xFFFCE7F3), Color(0xFFDB2777));
  }
  if (text.contains('message') || text.contains('chat') || text.contains('inbox')) {
    return const _Tone(Ph.chat_circle, Color(0xFFDBEAFE), Color(0xFF2563EB));
  }
  if (text.contains('pay') || text.contains('credit') || text.contains('subscription')) {
    return const _Tone(Ph.wallet, Color(0xFFFEF3C7), Color(0xFFD97706));
  }
  if (text.contains('customer')) {
    return const _Tone(Ph.users, Color(0xFFEDE9FE), Color(0xFF7C3AED));
  }
  return const _Tone(Ph.bell, Color(0xFFF3E8FF), Color(0xFF7F03B9));
}

String _timeLabel(DateTime? time) {
  if (time == null) return 'Just now';
  final local = time.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${local.day}/${local.month}/${local.year}';
}

Widget? _pageFor(String? page) {
  switch (page?.trim().toLowerCase()) {
    case 'profile':
      return const Profile();
    case 'security':
    case 'password':
    case 'password & security':
      return const Security();
    case 'notifications':
    case 'notification':
    case 'notification settings':
      return const NotificationsPage();
    case 'credits':
    case 'subscription':
      return const ManageSubscriptionPage();
    case 'payment':
    case 'payment method':
      return const PaymentMethodPage();
    case 'help':
    case 'support':
      return const HelpPage();
    case 'customers':
    case 'customer':
      return const ManageCustomers();
    case 'products':
    case 'product':
      return const ManageProducts();
    case 'orders':
    case 'order':
      return const ManageOrders();
    case 'inbox':
    case 'messages':
    case 'chats':
      return const ManageChats();
    default:
      return null;
  }
}
