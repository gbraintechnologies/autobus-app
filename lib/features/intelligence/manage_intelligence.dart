import 'dart:io';

import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/app_screen_header.dart';
import 'package:autobus/common_design/widgets/credits_pill.dart';
import 'package:autobus/features/intelligence/intelligence_files_page.dart';
import 'package:autobus/features/intelligence/intelligence_my_ai_page.dart';
import 'package:autobus/features/intelligence/intelligence_websites_page.dart';
import 'package:autobus/icons/figma_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

String? _ragDocSourceUrl(Map<String, dynamic> doc) {
  final url = doc['source_url'] ?? doc['sourceUrl'];
  if (url == null) return null;
  final s = url.toString().trim();
  return s.isEmpty ? null : s;
}

bool _ragDocIsWebsite(Map<String, dynamic> doc) {
  final type = (doc['source_type'] ?? doc['sourceType'] ?? '')
      .toString()
      .toLowerCase();
  if (type == 'website') return true;
  return _ragDocSourceUrl(doc) != null;
}

bool _ragFileLooksLikePlainText(String fileName) {
  final lower = fileName.trim().toLowerCase();
  return lower.endsWith('.txt') || lower.endsWith('.csv');
}

class ManageIntelligence extends StatefulWidget {
  const ManageIntelligence({super.key});

  @override
  State<ManageIntelligence> createState() => _ManageIntelligenceState();
}

class _ManageIntelligenceState extends State<ManageIntelligence> {
  bool _presenceRequested = false;
  bool _presenceLoading = true;
  String? _presenceError;
  Map<String, String> _onboardingAnswers = const {};
  bool _onboardingCompleted = false;

  Map<String, String> _answersFromOnboarding(Map<String, dynamic>? data) {
    if (data == null) return {};
    final profile = data['profile'];
    if (profile is! Map) return {};
    final map = Map<String, dynamic>.from(profile);
    final raw = map['answers'] is Map
        ? Map<String, dynamic>.from(map['answers'] as Map)
        : map;
    final out = <String, String>{};
    raw.forEach((key, value) {
      if (key == 'answers' ||
          key == 'completed_at' ||
          key == 'updated_at' ||
          key == 'version') {
        return;
      }
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) out[key.toString()] = text;
    });
    return out;
  }

  Future<void> _loadRagPresence() async {
    if (!mounted) return;
    setState(() {
      _presenceLoading = true;
      _presenceError = null;
    });
    try {
      final onboarding =
          await context.read<ApiService>().getBusinessOnboarding();
      if (!mounted) return;
      final answers = _answersFromOnboarding(onboarding);
      setState(() {
        _onboardingAnswers = answers;
        _onboardingCompleted =
            onboarding['completed'] == true || answers.isNotEmpty;
        _presenceLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _presenceError = userFacingError(e);
        _presenceLoading = false;
      });
    }
  }

  Future<void> _openOnboardingEditor() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const BusinessOnboarding(editMode: true),
      ),
    );
    if (updated == true && mounted) {
      await _loadRagPresence();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_presenceRequested) return;
    _presenceRequested = true;
    _loadRagPresence();
  }

  Future<void> _push(Widget page) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) _loadRagPresence();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F7),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppScreenHeader(
            scale: scale,
            title: 'Manage Intelligence',
            titleFontSize: 16,
            leading: AppScreenBackButton(scale: scale),
            trailing: CreditsPill(
              scale: scale,
              creditCategory: CreditCategory.llm,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: LightScreenTheme.accent,
              onRefresh: _loadRagPresence,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  21 * scale,
                  20 * scale,
                  21 * scale,
                  32 * scale,
                ),
                children: [
                  _OnboardingProfileCard(
                    scale: scale,
                    answers: _onboardingAnswers,
                    completed: _onboardingCompleted,
                    loading: _presenceLoading,
                    error: _presenceError,
                    onEdit: _openOnboardingEditor,
                    onRetry: _loadRagPresence,
                  ),
                  SizedBox(height: 20 * scale),
                  Row(
                    children: [
                      Expanded(
                        child: _IntelligenceTile(
                          scale: scale,
                          iconAsset: FigmaIcons.files,
                          gradient: const [
                            Color(0xFF22D3EE),
                            Color(0xFF0891B2),
                          ],
                          title: 'Files',
                          subtitle: 'Upload/view files',
                          onTap: () => _push(const IntelligenceFilesPage()),
                        ),
                      ),
                      SizedBox(width: 12 * scale),
                      Expanded(
                        child: _IntelligenceTile(
                          scale: scale,
                          iconAsset: FigmaIcons.website,
                          gradient: const [
                            Color(0xFFA3E635),
                            Color(0xFF65A30D),
                          ],
                          title: 'Websites',
                          subtitle: 'View/index websites',
                          onTap: () => _push(const IntelligenceWebsitesPage()),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20 * scale),
                  _MyAiButton(
                    scale: scale,
                    onTap: () => _push(const IntelligenceMyAiPage()),
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

class IntelligenceHistoryPage extends StatefulWidget {
  const IntelligenceHistoryPage({super.key});

  @override
  State<IntelligenceHistoryPage> createState() =>
      _IntelligenceHistoryPageState();
}

class _IntelligenceHistoryPageState extends State<IntelligenceHistoryPage> {
  List<Map<String, dynamic>> _documents = const [];
  bool _loading = true;
  String? _loadError;
  int? _expandedIndex;

  String _fileName(Map<String, dynamic> doc) =>
      (doc['file_name'] ?? '').toString();

  String? _objectKey(Map<String, dynamic> doc) {
    final k = doc['object_key'];
    if (k == null) return null;
    final s = k.toString();
    return s.isEmpty ? null : s;
  }

  String _displayTitle(Map<String, dynamic> doc) {
    final url = _ragDocSourceUrl(doc);
    if (url != null) return url;
    return _fileName(doc);
  }

  String _subtitle(Map<String, dynamic> doc) {
    if (_ragDocIsWebsite(doc)) {
      final name = _fileName(doc);
      return name.isEmpty ? 'Indexed website' : 'Saved as $name';
    }
    final key = _objectKey(doc);
    return key ?? '';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnack('Invalid URL');
      return;
    }
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (!ok) _showSnack('Could not open website');
    } catch (_) {
      _showSnack('Could not open website');
    }
  }

  Future<void> _openFileUrl(Map<String, dynamic> doc) async {
    final raw = (doc['file_url'] ?? '').toString().trim();
    if (raw.isNotEmpty) {
      final uri = Uri.tryParse(raw);
      if (uri != null) {
        try {
          final ok = await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
            webOnlyWindowName: '_blank',
          );
          if (ok) return;
        } catch (_) {}
      }
    }

    // Fallback: authenticated download then open a local temp copy.
    final name = _fileName(doc);
    if (name.isEmpty) {
      _showSnack('No download link for this file');
      return;
    }
    if (kIsWeb) {
      _showSnack(
        'Could not open this file in the browser. The download link may have expired — try again from history.',
      );
      return;
    }
    try {
      _showSnack('Preparing file…');
      final api = context.read<ApiService>();
      final bytes = await api.downloadMyStorageFileBytes(
        folder: ApiService.chatbotStorageFolder,
        fileName: name,
      );
      final dest = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}$name',
      );
      await dest.writeAsBytes(bytes, flush: true);
      final fileUri = Uri.file(dest.path);
      final ok = await launchUrl(
        fileUri,
        mode: LaunchMode.platformDefault,
      );
      if (!ok) {
        _showSnack(
          'Downloaded "$name", but no app could open it on this device.',
        );
      }
    } catch (e) {
      _showSnack(userFacingError(e));
    }
  }

  Future<void> _viewScrapedContent(Map<String, dynamic> doc) async {
    final isWebsite = _ragDocIsWebsite(doc);
    final name = _fileName(doc);
    final rawUrl = (doc['file_url'] ?? '').toString().trim();

    if (!isWebsite && name.isEmpty && rawUrl.isEmpty) {
      _showSnack('No content link available');
      return;
    }

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A0A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF3F1163)),
          ),
          title: Text(
            isWebsite ? 'Indexed content' : 'Indexed text preview',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: FutureBuilder<String>(
              future: _loadPreviewText(doc),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: AutobusLoadingIndicator(size: 28),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    userFacingError(
                      snapshot.error!,
                      action: 'previewing file',
                    ),
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                    ),
                  );
                }
                final text = snapshot.data ?? '';
                if (text.trim().isEmpty) {
                  return Text(
                    'No preview available.',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                    ),
                  );
                }
                return Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            if (!isWebsite)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _openFileUrl(doc);
                },
                child: Text(
                  'Open original',
                  style: GoogleFonts.outfit(color: Colors.white70),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.outfit(color: const Color(0xFFA855F7)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String> _loadPreviewText(Map<String, dynamic> doc) async {
    final isWebsite = _ragDocIsWebsite(doc);
    final name = _fileName(doc);
    final rawUrl = (doc['file_url'] ?? '').toString().trim();

    // Websites and plain text can be shown from the stored object URL.
    if (isWebsite || _ragFileLooksLikePlainText(name)) {
      if (rawUrl.isEmpty) {
        throw Exception('No content link available');
      }
      return _fetchTextPreview(rawUrl);
    }

    // Word/PDF/spreadsheet: never render binary as text — use extracted index text.
    if (name.isEmpty) {
      throw Exception('No file name available for preview');
    }
    final api = context.read<ApiService>();
    return api.previewMyRagFileText(
      folder: ApiService.chatbotStorageFolder,
      fileName: name,
    );
  }

  Future<String> _fetchTextPreview(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load content (${response.statusCode})');
    }
    // Guard against accidentally treating binary as UTF-8 text.
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (contentType.contains('application/pdf') ||
        contentType.contains('officedocument') ||
        contentType.contains('msword') ||
        contentType.contains('octet-stream')) {
      throw Exception(
        'This file cannot be previewed as plain text. Use Open original.',
      );
    }
    final body = response.body.trim();
    if (body.contains('\u0000')) {
      throw Exception(
        'This file cannot be previewed as plain text. Use Open original.',
      );
    }
    const maxChars = 12000;
    if (body.length <= maxChars) return body;
    return '${body.substring(0, maxChars)}\n\n…';
  }

  Future<void> _clearIntelligence() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A0A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF3F1163)),
          ),
          title: Text(
            'Clear intelligence?',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
          ),
          content: Text(
            'This removes all uploaded documents and websites from storage '
            'and from the search index. Chat history is kept. '
            'You can upload your data again afterwards.',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Clear all',
                style: GoogleFonts.outfit(color: const Color(0xFFFF6B6B)),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    try {
      final api = context.read<ApiService>();
      final message = await api.clearMyIntelligence();
      if (!mounted) return;
      await _loadDocuments();
      _showSnack(message);
    } catch (e) {
      if (!mounted) return;
      _showSnack(userFacingError(e));
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.outfit())),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDocuments());
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiService>();
      final list = await api.listMyStorageFiles(
        folder: ApiService.chatbotStorageFolder,
      );
      if (!mounted) return;
      setState(() {
        _documents = list;
        _loading = false;
        _expandedIndex = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(e);
        _loading = false;
      });
    }
  }

  Future<void> _deleteAt(int index) async {
    final doc = _documents[index];
    final name = _fileName(doc);
    if (name.isEmpty) return;
    try {
      final api = context.read<ApiService>();
      await api.deleteMyStorageFile(
        folder: ApiService.chatbotStorageFolder,
        fileName: name,
      );
      if (!mounted) return;
      setState(() {
        _documents = List<Map<String, dynamic>>.from(_documents)
          ..removeAt(index);
        _expandedIndex = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "$name"', style: GoogleFonts.outfit())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(e),
            style: GoogleFonts.outfit(),
          ),
        ),
      );
    }
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
                    title: 'Manage Intelligence',
                    creditCategory: CreditCategory.llm,
                    padding: EdgeInsets.zero,
                  ),
                  if (!_loading &&
                      _loadError == null &&
                      _documents.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _clearIntelligence,
                        icon: const Icon(
                          Icons.delete_sweep_outlined,
                          color: Color(0xFFFF6B6B),
                          size: 18,
                        ),
                        label: Text(
                          'Clear intelligence',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFFF6B6B),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child:                             const AutobusLoadingIndicator(size: 32),
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
                                  onPressed: _loadDocuments,
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
                        : _documents.isEmpty
                        ? Center(
                            child: Text(
                              'No documents or websites indexed yet',
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 16,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFFA855F7),
                            onRefresh: _loadDocuments,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _documents.length,
                              itemBuilder: (context, index) {
                                final doc = _documents[index];
                                final isWebsite = _ragDocIsWebsite(doc);
                                final title = _displayTitle(doc);
                                final subtitle = _subtitle(doc);
                                final sourceUrl = _ragDocSourceUrl(doc);
                                final isExpanded = _expandedIndex == index;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _expandedIndex = isExpanded
                                            ? null
                                            : index;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      padding: EdgeInsets.all(
                                        isExpanded ? 32 : 24,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFF3F1163),
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          isExpanded ? 38 : 30,
                                        ),
                                      ),
                                      child: isExpanded
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      isWebsite
                                                          ? Icons.language
                                                          : Icons
                                                                .description_outlined,
                                                      color: const Color(
                                                        0xFFA855F7,
                                                      ),
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        isWebsite
                                                            ? 'Website'
                                                            : 'Document',
                                                        style:
                                                            GoogleFonts.outfit(
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                    alpha: 0.7,
                                                                  ),
                                                              fontSize: 12,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  title,
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                                if (subtitle.isNotEmpty) ...[
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    subtitle,
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.65,
                                                          ),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w300,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 16),
                                                if (isWebsite &&
                                                    sourceUrl != null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 8,
                                                        ),
                                                    child: SizedBox(
                                                      width: double.infinity,
                                                      child: TextButton(
                                                        onPressed: () =>
                                                            _openUrl(
                                                              sourceUrl,
                                                            ),
                                                        child: Text(
                                                          'Open website',
                                                          style:
                                                              GoogleFonts.outfit(
                                                                color: const Color(
                                                                  0xFFA855F7,
                                                                ),
                                                                fontSize: 13,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: TextButton(
                                                    onPressed: () =>
                                                        _viewScrapedContent(
                                                          doc,
                                                        ),
                                                    child: Text(
                                                      isWebsite
                                                          ? 'View indexed content'
                                                          : 'View indexed text',
                                                      style: GoogleFonts.outfit(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.85,
                                                            ),
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (!isWebsite)
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: TextButton(
                                                      onPressed: () =>
                                                          _openFileUrl(doc),
                                                      child: Text(
                                                        'Open original',
                                                        style:
                                                            GoogleFonts.outfit(
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                    alpha: 0.75,
                                                                  ),
                                                              fontSize: 13,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                const SizedBox(height: 4),
                                                Center(
                                                  child: TextButton(
                                                    onPressed: () =>
                                                        _deleteAt(index),
                                                    child: Text(
                                                      isWebsite
                                                          ? 'Remove website'
                                                          : 'Delete file',
                                                      style: GoogleFonts.outfit(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.75,
                                                            ),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w300,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      isWebsite
                                                          ? Icons.language
                                                          : Icons
                                                                .description_outlined,
                                                      color: const Color(
                                                        0xFFA855F7,
                                                      ),
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        title,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.outfit(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w400,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (subtitle.isNotEmpty) ...[
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    subtitle,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.45,
                                                          ),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w300,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                    ),
                                  ),
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

const _onboardingLabels = <String, String>{
  'business_name': 'Business name',
  'business_description': 'About the business',
  'target_customers': 'Target customers',
  'products_services': 'Products & services',
  'industry': 'Industry',
  'service_area': 'Service area',
  'differentiator': 'What makes you unique',
  'chatbot_greeting': 'Chatbot greeting',
};

/// Figma `3399:1096` — onboarding answers indexed into Intelligence.
class _OnboardingProfileCard extends StatelessWidget {
  const _OnboardingProfileCard({
    required this.scale,
    required this.answers,
    required this.completed,
    required this.loading,
    required this.error,
    required this.onEdit,
    required this.onRetry,
  });

  final double scale;
  final Map<String, String> answers;
  final bool completed;
  final bool loading;
  final String? error;
  final VoidCallback onEdit;
  final VoidCallback onRetry;

  static const _valueColor = Color(0xFF4A6491);
  static const _figmaRows = ['industry', 'service_area', 'business_name'];

  List<MapEntry<String, String>> get _rows {
    final picked = <MapEntry<String, String>>[
      for (final key in _figmaRows)
        if (answers[key] != null) MapEntry(key, answers[key]!),
    ];
    if (picked.length >= 3) return picked;
    for (final e in answers.entries) {
      if (picked.length >= 3) break;
      if (!_figmaRows.contains(e.key)) picked.add(e);
    }
    return picked;
  }

  @override
  Widget build(BuildContext context) {
    final rowStyle = GoogleFonts.poppins(
      color: Colors.black,
      fontSize: LightScreenTheme.typeLabel,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );

    final Widget body;
    if (loading && answers.isEmpty) {
      body = Padding(
        padding: EdgeInsets.symmetric(vertical: 12 * scale),
        child: const Center(child: AutobusLoadingIndicator(size: 24)),
      );
    } else if (error != null && answers.isEmpty) {
      body = Row(
        children: [
          Expanded(
            child: Text(
              'Could not load your business profile.',
              style: rowStyle.copyWith(color: LightScreenTheme.body),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.poppins(
                color: LightScreenTheme.accent,
                fontSize: LightScreenTheme.typeLabel,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    } else if (answers.isEmpty) {
      body = Text(
        'Answer a few questions so your AI can talk about your business before you upload files or websites.',
        style: rowStyle.copyWith(color: LightScreenTheme.body),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in _rows)
            Padding(
              padding: EdgeInsets.only(top: 8 * scale),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${_onboardingLabels[e.key] ?? e.key} : '),
                    TextSpan(
                      text: e.value,
                      style: const TextStyle(color: _valueColor),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: rowStyle,
              ),
            ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        color: LightScreenTheme.surface,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(20 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FigmaSvgIcon(FigmaIcons.ai, size: 35 * scale.clamp(0.9, 1.05)),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: Text(
                  completed || answers.isNotEmpty ? 'Update' : 'Add',
                  style: GoogleFonts.poppins(
                    color: LightScreenTheme.accent,
                    fontSize: LightScreenTheme.typeBody,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * scale),
          Text(
            completed || answers.isNotEmpty
                ? 'Indexed from onboarding'
                : 'Train your AI with a business profile',
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4 * scale),
          body,
        ],
      ),
    );
  }
}

/// Figma `3399:1111` / `3399:1119` — Files and Websites tiles.
class _IntelligenceTile extends StatelessWidget {
  const _IntelligenceTile({
    required this.scale,
    required this.iconAsset,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final double scale;
  final String iconAsset;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LightScreenTheme.surface,
      borderRadius: BorderRadius.circular(20 * scale),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(20 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44 * scale,
                height: 44 * scale,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
                alignment: Alignment.center,
                child: FigmaSvgIcon(
                  iconAsset,
                  size: 22 * scale.clamp(0.9, 1.05),
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20 * scale),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4 * scale),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: LightScreenTheme.muted,
                  fontSize: LightScreenTheme.typeLabel,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma `3399:1105` — My AI entry.
class _MyAiButton extends StatelessWidget {
  const _MyAiButton({required this.scale, required this.onTap});

  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20 * scale);
    return Material(
      color: LightScreenTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: LightScreenTheme.accent.withValues(alpha: 0.6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 93 * scale,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FigmaSvgIcon(FigmaIcons.ai, size: 35 * scale.clamp(0.9, 1.05)),
              SizedBox(width: 7 * scale),
              Text(
                'My AI',
                style: GoogleFonts.poppins(
                  color: Colors.black,
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
