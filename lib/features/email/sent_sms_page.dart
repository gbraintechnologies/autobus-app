import 'package:autobus/barrel.dart';

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
    required String phone,
    required String message,
    required String date,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF3F1163), width: 1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            phone.isEmpty ? '(No recipient)' : phone,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  status.isEmpty ? 'Sent' : status,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              Text(
                date,
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: ManageScreenStyle.homeDashboardBodyDecoration,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ManageScreenHeader(
                    title: 'Sent SMS',
                    creditCategory: CreditCategory.sms,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: AutobusLoadingIndicator(size: 32),
                          )
                        : _loadError != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    _loadError!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: _load,
                                  child: Text(
                                    'Retry',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFA855F7),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFFA855F7),
                            onRefresh: _load,
                            child: _messages.isEmpty
                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      SizedBox(
                                        height:
                                            MediaQuery.sizeOf(context).height *
                                            0.25,
                                      ),
                                      Center(
                                        child: Text(
                                          'No sent SMS yet',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: _messages.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 16),
                                    itemBuilder: (context, index) {
                                      final m = _messages[index];
                                      return _sentTile(
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
