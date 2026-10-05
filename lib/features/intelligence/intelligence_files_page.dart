import 'dart:io';

import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/app_screen_header.dart';
import 'package:autobus/common_design/widgets/credits_pill.dart';
import 'package:autobus/icons/home_figma_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:url_launcher/url_launcher.dart';

bool _ragDocIsWebsite(Map<String, dynamic> doc) {
  final type = (doc['source_type'] ?? doc['sourceType'] ?? '')
      .toString()
      .toLowerCase();
  if (type == 'website') return true;
  final url = doc['source_url'] ?? doc['sourceUrl'];
  if (url == null) return false;
  return url.toString().trim().isNotEmpty;
}

/// My Files — Figma INTELLIGENCE frame 3237:2074.
class IntelligenceFilesPage extends StatefulWidget {
  const IntelligenceFilesPage({super.key});

  @override
  State<IntelligenceFilesPage> createState() => _IntelligenceFilesPageState();
}

class _IntelligenceFilesPageState extends State<IntelligenceFilesPage> {
  static const _backgroundColor = Color(0xFFF3F3F7);
  static const _surfaceColor = Color(0xFFF8FAFC);
  static const _accentColor = Color(0xFF7F03B9);

  List<Map<String, dynamic>> _files = const [];
  bool _loading = true;
  String? _loadError;

  String _fileName(Map<String, dynamic> doc) =>
      (doc['file_name'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFiles());
  }

  Future<void> _loadFiles() async {
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
        _files = list.where((doc) => !_ragDocIsWebsite(doc)).toList();
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

  Future<void> _handleUploadFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'pdf', 'docx', 'csv', 'xlsx'],
      allowMultiple: true,
    );

    if (!mounted || result == null || result.files.isEmpty) return;

    final api = context.read<ApiService>();
    var successCount = 0;

    try {
      for (final picked in result.files) {
        final name = picked.name.trim().isEmpty ? 'upload' : picked.name;
        final path = picked.path?.trim();

        Future<Map<String, dynamic>> startJob() async {
          if (path != null && path.isNotEmpty) {
            return api.uploadRagDocument(
              filename: name,
              filePath: path,
              asyncMode: true,
            );
          }
          if (picked.bytes != null && picked.bytes!.isNotEmpty) {
            return api.uploadRagDocument(
              filename: name,
              fileBytes: picked.bytes!.toList(),
              asyncMode: true,
            );
          }
          throw Exception(
            'Could not read "$name". On this device, try choosing the file again.',
          );
        }

        await _runRagIndexWithProgress(
          title: result.files.length > 1 ? 'Indexing ($name)' : 'Indexing document',
          startJob: startJob,
        );
        successCount++;
      }

      if (!mounted) return;
      await _loadFiles();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successCount == 1
                ? 'Document uploaded and indexed.'
                : '$successCount documents uploaded and indexed.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _uploadErrorMessage(e),
            style: GoogleFonts.poppins(),
          ),
        ),
      );
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
        return _MyFilesRagProgressDialog(
          api: api,
          title: title,
          startJob: startJob,
        );
      },
    );
    if (error != null) throw error;
  }

  String _uploadErrorMessage(Object e) {
    return userFacingError(e, fallback: AppUserMessages.upload);
  }

  Future<void> _openFile(Map<String, dynamic> doc) async {
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

    final name = _fileName(doc);
    if (name.isEmpty || kIsWeb) {
      _showSnack('No download link for this file');
      return;
    }

    try {
      if (!mounted) return;
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
      final ok = await launchUrl(
        Uri.file(dest.path),
        mode: LaunchMode.platformDefault,
      );
      if (!ok) _showSnack('Downloaded "$name", but no app could open it.');
    } catch (e) {
      _showSnack(userFacingError(e));
    }
  }

  Future<void> _deleteFile(int index) async {
    final doc = _files[index];
    final name = _fileName(doc);
    if (name.isEmpty) return;
    try {
      await context.read<ApiService>().deleteMyStorageFile(
        folder: ApiService.chatbotStorageFolder,
        fileName: name,
      );
      if (!mounted) return;
      setState(() {
        _files = List<Map<String, dynamic>>.from(_files)..removeAt(index);
      });
      _showSnack('Deleted "$name"');
    } catch (e) {
      _showSnack(userFacingError(e));
    }
  }

  Future<void> _showFileActions(int index) async {
    final doc = _files[index];
    final name = _fileName(doc);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  name.isEmpty ? 'File' : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.open_in_new_outlined),
                  title: Text('Open file', style: GoogleFonts.poppins()),
                  onTap: () => Navigator.pop(context, 'open'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text('Delete file', style: GoogleFonts.poppins()),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    if (action == 'open') {
      await _openFile(doc);
    } else if (action == 'delete') {
      await _deleteFile(index);
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
                title: 'My Files',
                titleFontSize: 16,
                leading: AppScreenBackButton(scale: scale),
                trailing: CreditsPill(
                  scale: scale,
                  creditCategory: CreditCategory.storageMb,
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: _accentColor,
                  onRefresh: _loadFiles,
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
                        _MyFilesUploadButton(
                          scale: scale,
                          onTap: _handleUploadFiles,
                        ),
                        SizedBox(height: 40 * scale),
                        Text(
                          'Uploaded files',
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
                                  onPressed: _loadFiles,
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
                        else if (_files.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 48 * scale),
                            child: Text(
                              'No files uploaded yet',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF64748B),
                                fontSize: 14,
                              ),
                            ),
                          )
                        else
                          _MyFilesGrid(
                            scale: scale,
                            files: _files,
                            fileName: _fileName,
                            onTap: _showFileActions,
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

class _MyFilesUploadButton extends StatelessWidget {
  final double scale;
  final VoidCallback onTap;

  const _MyFilesUploadButton({
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
                icon: SFIcons.sf_icloud_and_arrow_up,
                color: Colors.white,
                size: 20 * scale.clamp(0.9, 1.1),
                fontWeight: FontWeight.w500,
              ),
              SizedBox(width: 8 * scale),
              Text(
                'Upload files',
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

class _MyFilesGrid extends StatelessWidget {
  final double scale;
  final List<Map<String, dynamic>> files;
  final String Function(Map<String, dynamic>) fileName;
  final ValueChanged<int> onTap;

  const _MyFilesGrid({
    required this.scale,
    required this.files,
    required this.fileName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gap = 12 * scale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - gap) / 2;
        final cardHeight = 146 * scale;

        return Wrap(
          spacing: gap,
          runSpacing: 8 * scale,
          children: [
            for (var i = 0; i < files.length; i++)
              SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: _MyFilesGridCard(
                  scale: scale,
                  label: fileName(files[i]),
                  onTap: () => onTap(i),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MyFilesGridCard extends StatelessWidget {
  final double scale;
  final String label;
  final VoidCallback onTap;

  const _MyFilesGridCard({
    required this.scale,
    required this.label,
    required this.onTap,
  });

  static const _surfaceColor = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(20 * scale),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: _FileThumbnailPlaceholder(size: 64 * scale),
                ),
              ),
              if (label.isNotEmpty) ...[
                SizedBox(height: 8 * scale),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FileThumbnailPlaceholder extends StatelessWidget {
  final double size;

  const _FileThumbnailPlaceholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FileThumbnailPainter(),
      ),
    );
  }
}

class _FileThumbnailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final frame = Path()
      ..moveTo(w * 0.062, h * 0.104)
      ..lineTo(w * 0.938, h * 0.104)
      ..lineTo(w * 0.938, h * 0.896)
      ..lineTo(w * 0.062, h * 0.896)
      ..close();

    canvas.drawPath(
      frame,
      Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.fill,
    );

    final hills = Path()
      ..moveTo(w * 0.083, h * 0.72)
      ..lineTo(w * 0.35, h * 0.45)
      ..lineTo(w * 0.58, h * 0.62)
      ..lineTo(w * 0.92, h * 0.38)
      ..lineTo(w * 0.92, h * 0.92)
      ..lineTo(w * 0.083, h * 0.92)
      ..close();

    canvas.drawPath(
      hills,
      Paint()
        ..color = const Color(0xFF6EE7B7)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset(w * 0.25, h * 0.28),
      w * 0.125,
      Paint()..color = const Color(0xFFFCD34D),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MyFilesRagProgressDialog extends StatefulWidget {
  final ApiService api;
  final String title;
  final Future<Map<String, dynamic>> Function() startJob;

  const _MyFilesRagProgressDialog({
    required this.api,
    required this.title,
    required this.startJob,
  });

  @override
  State<_MyFilesRagProgressDialog> createState() =>
      _MyFilesRagProgressDialogState();
}

class _MyFilesRagProgressDialogState extends State<_MyFilesRagProgressDialog> {
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
