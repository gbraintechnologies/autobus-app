import 'package:autobus/barrel.dart';
import 'package:url_launcher/url_launcher.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  late final ApiService _api = ApiService(
    httpClient: SessionAwareHttpClient(tokenService: TokenService()),
  );

  Map<String, dynamic>? _preview;
  bool _loading = true;
  bool _deleting = false;
  String? _error;
  String _pin = '';
  int _pinNonce = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreview());
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preview = await _api.getAccountDeletionPreview();
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingError(e, action: 'loading account deletion details');
      });
    }
  }

  List<Map<String, dynamic>> _maps(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map<String, dynamic>)
          item
        else if (item is Map)
          Map<String, dynamic>.from(item),
    ];
  }

  Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  Future<void> _openAppleSubscriptions() async {
    final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmDelete() async {
    if (_pin.length != 4 || _deleting) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Delete permanently?',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'This cannot be undone. Your Autobus login, every attached business, and the data listed on the previous screen will be deleted.',
            style: GoogleFonts.montserrat(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (go != true || !mounted) return;
    await _delete();
  }

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await _api.deleteMyAccount(password: _pin);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: Text(
              'Account deleted',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Your Autobus account has been deleted.',
              style: GoogleFonts.montserrat(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      context.read<AuthBloc>().add(LogoutEvent());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = userFacingError(e, action: 'deleting your account');
        _pin = '';
        _pinNonce += 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoggedOutGate()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        body: _SettingsWash(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _deleting ? null : () => Navigator.pop(context),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: CustColors.mainCol,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Delete account',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: AutobusLoadingIndicator())
                      : RefreshIndicator(
                          onRefresh: _loadPreview,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
                            children: [
                              Text(
                                'This permanently deletes your Autobus login and every business attached to it. Connections are removed automatically — you do not need to unlink them first.',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13.5,
                                  height: 1.4,
                                  color: Colors.black87,
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: GoogleFonts.montserrat(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              if (_preview != null) ..._previewSections(_preview!),
                              const SizedBox(height: 28),
                              Text(
                                'Enter your PIN to confirm',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              PinDigitInput(
                                key: ValueKey(_pinNonce),
                                enabled: !_deleting,
                                autofocus: false,
                                onChanged: (value) => setState(() => _pin = value),
                                onCompleted: (value) => setState(() => _pin = value),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _pin.length == 4 && !_deleting
                                      ? _confirmDelete
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.red.withValues(
                                      alpha: 0.35,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _deleting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'Delete permanently',
                                          style: GoogleFonts.montserrat(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ],
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

  List<Widget> _previewSections(Map<String, dynamic> preview) {
    final businesses = _maps(preview['businesses']);
    final connections = _maps(preview['connections']);
    final notes = preview['notes'] is List
        ? preview['notes'].whereType<String>().toList()
        : const <String>[];
    final summary = _map(preview['data_summary']);
    final subscription = _map(preview['subscription']);
    final hasApple = (subscription['provider'] ?? '')
        .toString()
        .toLowerCase()
        .contains('apple');

    return [
      const SizedBox(height: 22),
      _sectionTitle('Businesses that will be deleted'),
      const SizedBox(height: 8),
      _card(
        children: businesses.isEmpty
            ? [_row('This Autobus login')]
            : [
                for (final biz in businesses)
                  _row(
                    (biz['company'] ?? biz['fullname'] ?? 'Business').toString(),
                    subtitle: [
                      if (biz['is_manager'] == true) 'Primary login',
                      if (biz['email'] != null) biz['email'].toString(),
                    ].where((s) => s.isNotEmpty).join(' · '),
                  ),
              ],
      ),
      const SizedBox(height: 18),
      _sectionTitle('Autobus will disconnect'),
      const SizedBox(height: 8),
      _card(
        children: connections.isEmpty
            ? [_row('No linked channels or outlets')]
            : [
                for (final item in connections)
                  _row(
                    (item['label'] ?? item['kind'] ?? 'Connection').toString(),
                    subtitle: (item['detail'] ?? '').toString(),
                  ),
              ],
      ),
      const SizedBox(height: 18),
      _sectionTitle('Data that will be deleted'),
      const SizedBox(height: 8),
      _card(
        children: [
          _row('${summary['customers'] ?? 0} customers'),
          _row('${summary['products'] ?? 0} products'),
          _row('${summary['orders'] ?? 0} orders'),
          _row('Profile, chats, campaigns, files, and AI history'),
        ],
      ),
      if (notes.isNotEmpty) ...[
        const SizedBox(height: 18),
        _sectionTitle('What you should know'),
        const SizedBox(height: 8),
        _card(
          children: [
            for (final note in notes) _row(note),
            if (hasApple)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: TextButton(
                  onPressed: _openAppleSubscriptions,
                  child: Text(
                    'Manage Apple subscription',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ],
    ];
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }

  Widget _row(String title, {String? subtitle}) {
    return ListTile(
      dense: true,
      title: Text(
        title,
        style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      subtitle: (subtitle == null || subtitle.isEmpty)
          ? null
          : Text(
              subtitle,
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.black54),
            ),
    );
  }
}

class _SettingsWash extends StatelessWidget {
  const _SettingsWash({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 244, 244, 244),
            Color.fromARGB(255, 240, 240, 240),
            Color.fromARGB(255, 236, 236, 236),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}
