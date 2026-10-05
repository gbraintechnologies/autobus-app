import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/app_screen_header.dart';
import 'package:autobus/common_design/widgets/credits_pill.dart';

/// Sent Email history — Figma ANALYTICS frame 3244:3803.
class SentEmailsPage extends StatefulWidget {
  const SentEmailsPage({super.key});

  @override
  State<SentEmailsPage> createState() => _SentEmailsPageState();
}

class _SentEmailsPageState extends State<SentEmailsPage> {
  static const _backgroundColor = Color(0xFFF3F3F7);
  static const _surfaceColor = Color(0xFFF8FAFC);
  static const _bodyColor = Color(0xFF4D4D4D);
  static const _mutedColor = Color(0xFF64748B);
  static const _accentColor = Color(0xFF7F03B9);

  List<Map<String, dynamic>> _emails = const [];
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
      final body = await api.getMySentEmails(limit: 50);
      if (!mounted) return;
      final raw = body['emails'];
      final list = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            list.add(e);
          } else if (e is Map) {
            list.add(Map<String, dynamic>.from(e));
          }
        }
      }
      setState(() {
        _emails = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e);
        _loading = false;
        _emails = const [];
      });
    }
  }

  Widget _sentTile({
    required double scale,
    required String subject,
    required String to,
    required String date,
  }) {
    return Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subject.isEmpty ? '(No subject)' : subject,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8 * scale),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  to.startsWith('To: ') ? to : 'To: $to',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: _mutedColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(width: 12 * scale),
              Text(
                date,
                style: GoogleFonts.poppins(
                  color: _mutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
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

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppScreenHeader(
            scale: scale,
            title: 'Sent Email',
            leading: AppScreenBackButton(scale: scale),
            trailing: CreditsPill(
              scale: scale,
              creditCategory: CreditCategory.email,
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: _accentColor),
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
                            style: GoogleFonts.poppins(
                              color: _bodyColor,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 16 * scale),
                          TextButton(
                            onPressed: _load,
                            child: Text(
                              'Retry',
                              style: GoogleFonts.poppins(
                                color: _accentColor,
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
                    color: _accentColor,
                    onRefresh: _load,
                    child: _emails.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.sizeOf(context).height * 0.32,
                              ),
                              Center(
                                child: Text(
                                  'No sent emails yet..',
                                  style: GoogleFonts.poppins(
                                    color: _bodyColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
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
                            itemCount: _emails.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: 12 * scale),
                            itemBuilder: (context, index) {
                              final m = _emails[index];
                              return _sentTile(
                                scale: scale,
                                subject: (m['subject'] ?? '').toString(),
                                to: (m['to'] ?? '').toString(),
                                date: _formatSentAt(
                                  (m['sent_at'] ?? '').toString(),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
