import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_list_card.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';

class SentSmsPage extends StatefulWidget {
  const SentSmsPage({super.key});

  @override
  State<SentSmsPage> createState() => _SentSmsPageState();
}

class _SentSmsPageState extends State<SentSmsPage> {
  List<Map<String, dynamic>> _messages = const [];
  bool _loading = true;
  String? _loadError;

  String _formatSentAt(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw.isEmpty ? '—' : raw;
    final d = dt.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd / $mm / ${d.year}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiService>();
      final messages = await api.getMySentSms();
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e);
        _loading = false;
        _messages = const [];
      });
    }
  }

  Widget _sentTile({
    required double scale,
    required String phone,
    required String message,
    required String date,
    required String status,
  }) {
    return LightListCard(
      scale: scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            phone.isEmpty ? '(No recipient)' : phone,
            style: LightScreenTheme.listTitle(scale).copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (message.isNotEmpty) ...[
            SizedBox(height: 8 * scale),
            Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: LightScreenTheme.listSubtitle(scale).copyWith(
                color: LightScreenTheme.body,
              ),
            ),
          ],
          SizedBox(height: 12 * scale),
          Row(
            children: [
              Expanded(
                child: Text(
                  status.isEmpty ? 'Sent' : status,
                  style: LightScreenTheme.listSubtitle(scale),
                ),
              ),
              Text(
                date,
                style: LightScreenTheme.listSubtitle(scale),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Sent SMS',
      creditCategory: CreditCategory.sms,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: LightScreenTheme.accent),
            )
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28 * scale),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: LightScreenTheme.emptyState(scale),
                        ),
                        SizedBox(height: 16 * scale),
                        TextButton(
                          onPressed: _load,
                          child: Text(
                            'Retry',
                            style: GoogleFonts.poppins(
                              color: LightScreenTheme.accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: LightScreenTheme.accent,
                  onRefresh: _load,
                  child: _messages.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.32,
                            ),
                            Center(
                              child: Text(
                                'No sent SMS yet',
                                style: LightScreenTheme.emptyState(scale),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            20 * scale,
                            8 * scale,
                            20 * scale,
                            24 * scale,
                          ),
                          itemCount: _messages.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: 12 * scale),
                          itemBuilder: (context, index) {
                            final m = _messages[index];
                            return _sentTile(
                              scale: scale,
                              phone: (m['phone'] ?? '').toString(),
                              message: (m['message'] ?? '').toString(),
                              date: _formatSentAt(
                                (m['sent_at'] ?? '').toString(),
                              ),
                              status: (m['status'] ?? '').toString(),
                            );
                          },
                        ),
                ),
    );
  }
}
