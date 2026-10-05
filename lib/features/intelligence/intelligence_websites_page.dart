import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/app_screen_header.dart';
import 'package:autobus/common_design/widgets/credits_pill.dart';
import 'package:autobus/icons/home_figma_icons.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

bool _ragDocIsWebsite(Map<String, dynamic> doc) {
  final type = (doc['source_type'] ?? doc['sourceType'] ?? '')
      .toString()
      .toLowerCase();
  if (type == 'website') return true;
  final url = doc['source_url'] ?? doc['sourceUrl'];
  if (url == null) return false;
  return url.toString().trim().isNotEmpty;
}

String? _normalizeWebsiteUrlForApi(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  final lower = s.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    s = 'https://$s';
  }
  final uri = Uri.tryParse(s);
  if (uri == null || !uri.hasScheme) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (!uri.hasAuthority || uri.host.isEmpty) return null;
  return uri.toString();
}

/// Websites — Figma INTELLIGENCE frame 3237:2600.
class IntelligenceWebsitesPage extends StatefulWidget {
  const IntelligenceWebsitesPage({super.key});

  @override
  State<IntelligenceWebsitesPage> createState() =>
      _IntelligenceWebsitesPageState();
}

class _IntelligenceWebsitesPageState extends State<IntelligenceWebsitesPage> {
  static const _backgroundColor = Color(0xFFF3F3F7);
  static const _surfaceColor = Color(0xFFF8FAFC);
  static const _accentColor = Color(0xFF7F03B9);

  List<Map<String, dynamic>> _websites = const [];
  bool _loading = true;
  String? _loadError;

  String _fileName(Map<String, dynamic> doc) =>
      (doc['file_name'] ?? '').toString();

  String _websiteUrlLabel(Map<String, dynamic> doc) {
    final raw = (doc['source_url'] ?? doc['sourceUrl'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    var s = raw;
    if (s.startsWith('https://')) {
      s = s.substring(8);
    } else if (s.startsWith('http://')) {
      s = s.substring(7);
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  String _websiteTitle(Map<String, dynamic> doc) {
    final name = _fileName(doc);
    if (name.isNotEmpty) {
      final dot = name.lastIndexOf('.');
      if (dot > 0) return name.substring(0, dot);
      return name;
    }
    final label = _websiteUrlLabel(doc);
    if (label.isNotEmpty) return label;
    return 'Website name';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWebsites());
  }

  Future<void> _loadWebsites() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final list = await context.read<ApiService>().listMyStorageFiles(
        folder: ApiService.chatbotStorageFolder,
      );
      if (!mounted) return;
      setState(() {
        _websites = list.where(_ragDocIsWebsite).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e, fallback: AppUserMessages.load);
        _loading = false;
      });
    }
  }

  Future<void> _handleIndexWebsite() async {
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _WebsiteUrlDialog(),
    );

    if (!mounted || url == null || url.trim().isEmpty) return;

    final api = context.read<ApiService>();
    try {
      await _runRagIndexWithProgress(
        title: 'Indexing website',
        startJob: () => api.uploadRagUrl(url: url.trim()),
      );
      if (!mounted) return;
      await _loadWebsites();
      if (!mounted) return;
      _showSnack('Website content scraped and indexed.');
    } catch (e) {
      _showSnack(_indexErrorMessage(e));
    }
  }

  Future<void> _runRagIndexWithProgress({
    required String title,
    required Future<Map<String, dynamic>> Function() startJob,
  }) async {
    final api = context.read<ApiService>();
    final error = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _WebsitesRagProgressDialog(
          api: api,
          title: title,
          startJob: startJob,
        );
      },
    );
    if (error != null) throw error;
  }

  String _indexErrorMessage(Object e) {
    return userFacingError(e, fallback: AppUserMessages.upload);
  }

  Future<void> _deleteWebsite(int index) async {
    final doc = _websites[index];
    final name = _fileName(doc);
    if (name.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete website?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Remove "${_websiteTitle(doc)}" from your indexed websites?',
            style: GoogleFonts.poppins(
              color: const Color(0xFF64748B),
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: const Color(0xFF64748B)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(color: const Color(0xFFE11D48)),
              ),
            ),
          ],
        );
      },
    );
    if (!mounted || confirmed != true) return;

    try {
      await context.read<ApiService>().deleteMyStorageFile(
        folder: ApiService.chatbotStorageFolder,
        fileName: name,
      );
      if (!mounted) return;
      setState(() {
        _websites = List<Map<String, dynamic>>.from(_websites)..removeAt(index);
      });
      _showSnack('Deleted "${_websiteTitle(doc)}"');
    } catch (e) {
      _showSnack(userFacingError(e));
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins())),
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
            title: 'Websites',
            titleFontSize: 16,
            leading: AppScreenBackButton(scale: scale),
            trailing: CreditsPill(
              scale: scale,
              creditCategory: CreditCategory.llm,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: _accentColor,
              onRefresh: _loadWebsites,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  21 * scale,
                  20 * scale,
                  21 * scale,
                  32 * scale,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _IndexWebsiteButton(
                      scale: scale,
                      onTap: _handleIndexWebsite,
                    ),
                    SizedBox(height: 40 * scale),
                    Text(
                      'Indexed websites',
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 12 * scale),
                    if (_loading)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 48 * scale),
                        child: const Center(
                          child: AutobusLoadingIndicator(size: 28),
                        ),
                      )
                    else if (_loadError != null)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 32 * scale),
                        child: Column(
                          children: [
                            Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF64748B),
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: _loadWebsites,
                              child: Text(
                                'Retry',
                                style: GoogleFonts.poppins(
                                  color: _accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_websites.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 48 * scale),
                        child: Text(
                          'No websites indexed yet',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      _WebsitesList(
                        scale: scale,
                        websites: _websites,
                        titleFor: _websiteTitle,
                        urlFor: _websiteUrlLabel,
                        onDelete: _deleteWebsite,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndexWebsiteButton extends StatelessWidget {
  final double scale;
  final VoidCallback onTap;

  const _IndexWebsiteButton({
    required this.scale,
    required this.onTap,
  });

  static const _accentColor = Color(0xFF7F03B9);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _accentColor,
      borderRadius: BorderRadius.circular(12 * scale),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 67 * scale,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HomeSfIcon(
                icon: HomeFigmaIcons.website,
                color: Colors.white,
                size: 20 * scale.clamp(0.9, 1.1),
                fontWeight: FontWeight.w500,
              ),
              SizedBox(width: 8 * scale),
              Text(
                'Index website',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFF8EEEE),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebsitesList extends StatelessWidget {
  final double scale;
  final List<Map<String, dynamic>> websites;
  final String Function(Map<String, dynamic>) titleFor;
  final String Function(Map<String, dynamic>) urlFor;
  final ValueChanged<int> onDelete;

  const _WebsitesList({
    required this.scale,
    required this.websites,
    required this.titleFor,
    required this.urlFor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < websites.length; i++) ...[
          if (i > 0) SizedBox(height: 10 * scale),
          _WebsiteCard(
            scale: scale,
            title: titleFor(websites[i]),
            url: urlFor(websites[i]),
            onDelete: () => onDelete(i),
          ),
        ],
      ],
    );
  }
}

class _WebsiteCard extends StatelessWidget {
  final double scale;
  final String title;
  final String url;
  final VoidCallback onDelete;

  const _WebsiteCard({
    required this.scale,
    required this.title,
    required this.url,
    required this.onDelete,
  });

  static const _surfaceColor = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(20 * scale),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(20 * scale),
        child: Row(
          children: [
            _WebsiteGlobeIcon(scale: scale),
            SizedBox(width: 20 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (url.isNotEmpty) ...[
                    SizedBox(height: 4 * scale),
                    Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onDelete,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: EdgeInsets.all(4 * scale),
                  child: HomeSfIcon(
                    icon: SFIcons.sf_trash_fill,
                    color: const Color(0xFFE11D48),
                    size: 22 * scale.clamp(0.9, 1.05),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebsiteGlobeIcon extends StatelessWidget {
  final double scale;

  const _WebsiteGlobeIcon({required this.scale});

  @override
  Widget build(BuildContext context) {
    final size = 44 * scale;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12 * scale),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFA3E635),
              Color(0xFF65A30D),
            ],
          ),
        ),
        child: Center(
          child: HomeSfIcon(
            icon: HomeFigmaIcons.website,
            color: Colors.white,
            size: 22 * scale.clamp(0.9, 1.05),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _WebsiteUrlDialog extends StatefulWidget {
  const _WebsiteUrlDialog();

  @override
  State<_WebsiteUrlDialog> createState() => _WebsiteUrlDialogState();
}

class _WebsiteUrlDialogState extends State<_WebsiteUrlDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final normalized = _normalizeWebsiteUrlForApi(_controller.text);
    if (normalized == null) {
      setState(() {
        _error =
            'Enter a valid website URL (e.g. https://example.com or www.example.com)';
      });
      return;
    }
    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Index website',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We will scrape the public page and add its text to your business knowledge base.',
              style: GoogleFonts.poppins(
                color: const Color(0xFF64748B),
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'https://example.com or www.example.com',
                hintStyle: GoogleFonts.poppins(
                  color: const Color(0xFF94A3B8),
                  fontSize: 13,
                ),
                errorText: _error,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF7F03B9)),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7F03B9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Index',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WebsitesRagProgressDialog extends StatefulWidget {
  final ApiService api;
  final String title;
  final Future<Map<String, dynamic>> Function() startJob;

  const _WebsitesRagProgressDialog({
    required this.api,
    required this.title,
    required this.startJob,
  });

  @override
  State<_WebsitesRagProgressDialog> createState() =>
      _WebsitesRagProgressDialogState();
}

class _WebsitesRagProgressDialogState extends State<_WebsitesRagProgressDialog> {
  int _progress = 0;
  String _message = 'Starting…';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final started = await widget.startJob();
      final jobId = ApiService.ragIndexJobId(started);
      if (jobId == null) {
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      while (mounted) {
        final status = await widget.api.getRagIndexJobStatus(jobId);
        if (!mounted) return;

        final progress = status['progress'];
        final message = (status['message'] ?? '').toString();

        setState(() {
          if (progress is int) {
            _progress = progress.clamp(0, 100);
          } else if (progress is num) {
            _progress = progress.round().clamp(0, 100);
          }
          if (message.isNotEmpty) _message = message;
        });

        if (ApiService.ragIndexJobTerminal(status)) {
          if (!ApiService.ragIndexJobSucceeded(status)) {
            throw Exception(
              (status['error'] ?? status['message'] ?? 'Indexing failed')
                  .toString(),
            );
          }
          if (!mounted) return;
          Navigator.of(context).pop();
          return;
        }

        await Future<void>.delayed(const Duration(milliseconds: 750));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _message = userFacingError(e);
        _progress = 100;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      Navigator.of(context).pop(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress / 100 : null,
                minHeight: 6,
                backgroundColor: const Color(0xFFE2E8F0),
                color: _failed
                    ? Colors.red.shade400
                    : const Color(0xFF7F03B9),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_progress% · $_message',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFF64748B),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
