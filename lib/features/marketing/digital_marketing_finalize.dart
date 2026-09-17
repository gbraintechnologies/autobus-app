part of 'digital_marketing.dart';

class _FinalizePostPage extends StatefulWidget {
  final DigitalMarketingCampaign campaign;
  final List<PostizIntegration> postizIntegrations;
  final List<Map<String, dynamic>> blotatoAccounts;
  final bool usePostiz;
  final bool useBlotato;

  const _FinalizePostPage({
    required this.campaign,
    required this.postizIntegrations,
    required this.blotatoAccounts,
    required this.usePostiz,
    required this.useBlotato,
  });

  @override
  State<_FinalizePostPage> createState() => _FinalizePostPageState();
}

class _FinalizePostPageState extends State<_FinalizePostPage> {
  final ApiService _apiService = ApiService(
    httpClient: SessionAwareHttpClient(tokenService: TokenService()),
  );

  bool _publishing = false;
  String _publishStatus = '';
  bool _showSchedule = false;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  TimeOfDay _selectedTime = TimeOfDay.now();

  DigitalMarketingCampaign get _campaign => widget.campaign;

  List<String> get _phoneShareIds =>
      _campaign.selectedOutlets.where(_isPhoneShareOutlet).toList();

  List<PostizIntegration> get _selectedPostiz {
    final ids = _campaign.selectedOutlets;
    return widget.postizIntegrations.where((p) => ids.contains(p.id)).toList();
  }

  DateTime? get _combinedSchedule {
    final day = _selectedDay;
    if (day == null) return null;
    return DateTime(
      day.year,
      day.month,
      day.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _kHeaderPurple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null && mounted) setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = _phoneShareIds.isNotEmpty;
    final hasPostiz = _selectedPostiz.isNotEmpty ||
        _campaign.selectedOutlets.any((id) => id.startsWith(_kAutobusIgPrefix));

    return _MarketingScaffold(
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Post your campaign',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Share from this phone, or publish and schedule your post',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black45,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  children: [
                    if (hasPhone)
                      _actionCard(
                        icon: Icons.ios_share_rounded,
                        title: 'Share to apps on this phone',
                        subtitle: _phoneShareIds
                            .map(_phoneShareLabel)
                            .join(', '),
                        onTap: _publishing ? null : () => _publish(phoneShare: true),
                      ),
                    if (hasPostiz) ...[
                      const SizedBox(height: 12),
                      _actionCard(
                        icon: Icons.flash_on_rounded,
                        title: 'Post Now',
                        subtitle: 'Publish to your linked accounts at once',
                        onTap: _publishing
                            ? null
                            : () => _publish(postizNow: true),
                      ),
                      const SizedBox(height: 12),
                      _actionCard(
                        icon: Icons.schedule_rounded,
                        title: 'Schedule for later',
                        subtitle: 'Pick a date and time, then we’ll queue it',
                        selected: _showSchedule,
                        onTap: _publishing
                            ? null
                            : () => setState(() => _showSchedule = !_showSchedule),
                      ),
                    ],
                    if (_showSchedule && hasPostiz) ...[
                      const SizedBox(height: 16),
                      _CompactCalendar(
                        focusedMonth: _focusedMonth,
                        selectedDay: _selectedDay,
                        onDaySelected: (d) => setState(() => _selectedDay = d),
                        onMonthChanged: (m) => setState(() => _focusedMonth = m),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickTime,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F5FB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE8E0F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 18,
                                color: _kHeaderPurple,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Time  ·  ${_selectedTime.format(context)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                'Change',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _kHeaderPurple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _DarkButton(
                        label: 'Schedule post',
                        compact: true,
                        onTap: _publishing
                            ? null
                            : () {
                                if (_selectedDay == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Pick a date first',
                                        style: GoogleFonts.poppins(fontSize: 13),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                _publish(postizSchedule: true);
                              },
                      ),
                    ],
                    if (!hasPhone && !hasPostiz)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          'Select at least one platform on the previous screen.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_publishing)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.88),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AutobusLoadingIndicator(size: 36),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _publishStatus.isEmpty ? 'Working…' : _publishStatus,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool selected = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? _kHeaderPurple.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _kHeaderPurple : Colors.grey.shade200,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _kHeaderPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _kHeaderPurple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black45,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  void _setStatus(String status) {
    if (!mounted) return;
    setState(() => _publishStatus = status);
  }

  String _captionForOutlet(String id, String fallback) {
    final d = _campaign.outletDetails[id];
    final c = d?.caption.trim();
    if (c != null && c.isNotEmpty) return c;
    return fallback;
  }

  String _shareFileExtension(
    MarketingContent content, {
    String? sourceName,
    String? mimeType,
  }) {
    final candidate = (sourceName ?? '').trim().toLowerCase();
    final dot = candidate.lastIndexOf('.');
    if (dot >= 0 && dot < candidate.length - 1) {
      return candidate.substring(dot);
    }
    final mime = (mimeType ?? '').trim().toLowerCase();
    if (mime == 'image/png') return '.png';
    if (mime == 'image/webp') return '.webp';
    if (mime == 'image/gif') return '.gif';
    if (mime == 'video/quicktime') return '.mov';
    if (mime.startsWith('video/')) return '.mp4';
    return content.type == MarketingContentType.videos ? '.mp4' : '.jpg';
  }

  Future<XFile?> _materializeShareFile(
    MarketingContent content,
    int index,
  ) async {
    final localPath = content.localFilePath?.trim();
    if (!kIsWeb && localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists() && await file.length() > 0) {
        return XFile(file.path);
      }
    }
    final bytes = content.generatedBytes;
    if (bytes != null && bytes.isNotEmpty) {
      final ext = _shareFileExtension(
        content,
        sourceName: content.generatedResult,
        mimeType: content.generatedResult,
      );
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}${Platform.pathSeparator}autobus-share-$index$ext';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      return XFile(file.path);
    }
    final remote = content.generatedResult?.trim() ?? '';
    if (remote.startsWith('http://') || remote.startsWith('https://')) {
      final response = await http.get(Uri.parse(remote));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Could not prepare media for sharing (${response.statusCode}).',
        );
      }
      final remoteUri = Uri.parse(remote);
      final ext = _shareFileExtension(
        content,
        sourceName: remoteUri.pathSegments.isNotEmpty
            ? remoteUri.pathSegments.last
            : null,
        mimeType: response.headers['content-type'],
      );
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}${Platform.pathSeparator}autobus-share-$index$ext';
      final file = File(path);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return XFile(file.path);
    }
    return null;
  }

  Future<bool> _shareToPlatform({
    required String outletId,
    required String fallbackCaption,
  }) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      throw Exception('Phone sharing is available on Android and iPhone only.');
    }
    final files = <XFile>[];
    var fileIndex = 0;
    for (final content in _campaign.selectedContents) {
      if (content.type == MarketingContentType.text) continue;
      final file = await _materializeShareFile(content, fileIndex++);
      if (file != null) files.add(file);
    }
    final caption = _captionForOutlet(outletId, fallbackCaption).trim();
    if (files.isEmpty && caption.isEmpty) {
      throw Exception('Add text, image, or video before sharing.');
    }
    final result = await SharePlus.instance.share(
      ShareParams(
        title: 'Share to ${_phoneShareLabel(outletId)}',
        text: caption.isEmpty ? null : caption,
        files: files.isEmpty ? null : files,
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  Future<void> _publish({
    bool phoneShare = false,
    bool postizNow = false,
    bool postizSchedule = false,
  }) async {
    if (_publishing) return;

    for (final p in _selectedPostiz) {
      if (p.identifier.toLowerCase() != 'tiktok') continue;
      if (!postizNow && !postizSchedule) continue;
      final d = _campaign.outletDetails[p.id];
      if (d == null || d.tiktokPrivacy.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Complete the Post to TikTok settings first.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
        );
        return;
      }
    }

    for (final p in _selectedPostiz) {
      if (p.identifier.toLowerCase() != 'youtube') continue;
      if (p.id.startsWith(_kAutobusIgPrefix)) continue;
      if (!postizNow && !postizSchedule) continue;
      final d = _campaign.outletDetails[p.id] ??
          PlatformPostDetails.fromCampaignCaption(_campaign.campaignCaption);
      final title = d.youtubeTitle.trim().isNotEmpty
          ? d.youtubeTitle.trim()
          : PlatformPostDetails.fromCampaignCaption(d.caption).youtubeTitle;
      if (title.trim().length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'YouTube needs a title (at least 2 characters).',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
        );
        return;
      }
      d.youtubeTitle = title;
      final hasVideo = _campaign.selectedContents.any((c) {
        if (c.type == MarketingContentType.videos) return true;
        final hint = [
          c.generatedResult,
          c.localFilePath,
        ].whereType<String>().join(' ');
        return postizMediaLooksLikeVideo(hint);
      });
      if (!hasVideo) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'YouTube needs an MP4 video. Photos cannot be posted to YouTube.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _publishing = true;
      _publishStatus = 'Preparing content…';
    });

    final messenger = ScaffoldMessenger.of(context);
    final textContent = _campaign.campaignCaption;

    try {
      if (postizSchedule) {
        _campaign.postRightAway = false;
        _campaign.scheduledDate = _combinedSchedule;
      } else {
        _campaign.postRightAway = true;
        _campaign.scheduledDate = null;
      }

      var publishedCount = 0;
      var sharedCount = 0;
      final errors = <String>[];
      final tracks = <_TrackedPublish>[];

      if (phoneShare) {
        for (final id in _phoneShareIds) {
          _setStatus('Opening share sheet for ${_phoneShareLabel(id)}…');
          try {
            final ok = await _shareToPlatform(
              outletId: id,
              fallbackCaption: textContent,
            );
            if (ok) {
              sharedCount++;
              tracks.add(_trackPhoneShare(id, success: true));
            } else {
              errors.add('${_phoneShareLabel(id)} share was dismissed.');
              tracks.add(_trackPhoneShare(id, success: false));
            }
          } catch (e) {
            errors.add(
              userFacingError(e, action: 'sharing to ${_phoneShareLabel(id)}'),
            );
            tracks.add(
              _trackPhoneShare(
                id,
                success: false,
                message: userFacingError(
                  e,
                  action: 'sharing to ${_phoneShareLabel(id)}',
                ),
              ),
            );
          }
        }
      }

      final selectedIds = _campaign.selectedOutlets.toList();
      final igIds = selectedIds
          .where((id) => id.startsWith(_kAutobusIgPrefix))
          .map((id) => id.substring(_kAutobusIgPrefix.length))
          .where((id) => id.isNotEmpty)
          .toList();
      final postizIds = selectedIds
          .where(
            (id) =>
                !id.startsWith(_kAutobusIgPrefix) && !_isPhoneShareOutlet(id),
          )
          .toList();

      if ((postizNow || postizSchedule) && (igIds.isNotEmpty || postizIds.isNotEmpty)) {
        final mediaUrls = <String>[];
        _setStatus('Uploading media…');
        for (final c in _campaign.selectedContents) {
          if (c.type == MarketingContentType.text) continue;
          final existing = c.generatedResult?.trim();
          if (existing != null &&
              existing.isNotEmpty &&
              (existing.startsWith('http://') || existing.startsWith('https://'))) {
            mediaUrls.add(existing);
            continue;
          }
          final localPath = c.localFilePath?.trim();
          if (!kIsWeb && localPath != null && localPath.isNotEmpty) {
            try {
              final file = File(localPath);
              if (await file.exists() && await file.length() > 0) {
                final url = await _apiService.uploadFile(
                  file: file,
                  filename: file.uri.pathSegments.isNotEmpty
                      ? file.uri.pathSegments.last
                      : null,
                );
                mediaUrls.add(url);
                continue;
              }
            } catch (_) {}
          }
          final bytes = c.generatedBytes;
          if (bytes != null && bytes.isNotEmpty) {
            final filename = c.type == MarketingContentType.videos
                ? 'marketing-video.mp4'
                : (c.generatedResult?.trim().isNotEmpty == true
                    ? c.generatedResult!.trim()
                    : 'marketing-image.jpg');
            final url = await _apiService.uploadFileBytes(
              fileBytes: bytes,
              filename: filename,
            );
            mediaUrls.add(url);
          }
        }

        if (igIds.isNotEmpty) {
          if (mediaUrls.isEmpty) {
            throw Exception('Instagram needs at least one uploaded image or video URL.');
          }
          _setStatus('Publishing to Instagram…');
          for (final accountId in igIds) {
            final outletKey = '$_kAutobusIgPrefix$accountId';
            try {
              await _apiService.publishInstagramPost(
                accountId: accountId,
                caption: _captionForOutlet(outletKey, textContent),
                mediaUrls: mediaUrls,
              );
              publishedCount++;
              tracks.add(_trackInstagram(outletKey, success: true));
            } catch (e) {
              errors.add(
                userFacingError(e, action: 'sharing to Instagram'),
              );
              tracks.add(
                _trackInstagram(
                  outletKey,
                  success: false,
                  message: userFacingError(e, action: 'sharing to Instagram'),
                ),
              );
            }
          }
        }

        if (postizIds.isNotEmpty && widget.usePostiz) {
          final selected = widget.postizIntegrations
              .where((p) => postizIds.contains(p.id))
              .toList();
          if (selected.isEmpty) {
            throw Exception('No matching Postiz channels for the selection.');
          }
          _setStatus(postizSchedule ? 'Scheduling…' : 'Publishing…');
          final tiktokSelected =
              selected.where((p) => p.identifier.toLowerCase() == 'tiktok');
          if (tiktokSelected.isNotEmpty) {
            _setStatus(kTikTokProcessingNotice);
          }
          final payload = buildPostizCreatePostPayload(
            selectedIntegrations: selected,
            content: textContent,
            mediaUrls: mediaUrls,
            postRightAway: _campaign.postRightAway,
            scheduledUtc: _campaign.scheduledDate,
            outletDetails: _campaign.outletDetails,
          );
          try {
            final created = await _apiService.createPostizPost(
              payload,
              agentName: 'digital_marketing',
            );
            publishedCount += selected.length;
            final publishIds = _publishIdsFrom(created);
            var tiktokIndex = 0;
            for (final p in selected) {
              final isTikTok = p.identifier.toLowerCase() == 'tiktok';
              String? publishId;
              if (isTikTok && tiktokIndex < publishIds.length) {
                publishId = publishIds[tiktokIndex++];
              }
              tracks.add(
                _trackPostiz(
                  p,
                  scheduled: postizSchedule,
                  publishId: publishId,
                ),
              );
            }
          } catch (e) {
            final message = userFacingError(e, action: 'publishing');
            errors.add(message);
            for (final p in selected) {
              tracks.add(
                _trackPostiz(
                  p,
                  scheduled: postizSchedule,
                  success: false,
                  message: message,
                ),
              );
            }
          }
        } else if (postizIds.isNotEmpty && widget.useBlotato) {
          _setStatus('Publishing…');
          var blotatoContent = textContent;
          for (final id in postizIds) {
            final c = _campaign.outletDetails[id]?.caption.trim();
            if (c != null && c.isNotEmpty) {
              blotatoContent = c;
              break;
            }
          }
          try {
            await _apiService.publishSocialPost(
              accountIds: postizIds,
              content: blotatoContent.isEmpty ? ' ' : blotatoContent,
              mediaUrls: mediaUrls,
              scheduleTime: _campaign.scheduledDate?.toUtc().toIso8601String(),
            );
            publishedCount += postizIds.length;
            for (final id in postizIds) {
              tracks.add(_trackGeneric(id, scheduled: postizSchedule));
            }
          } catch (e) {
            final message = userFacingError(e, action: 'publishing');
            errors.add(message);
            for (final id in postizIds) {
              tracks.add(
                _TrackedPublish(
                  id: id,
                  platform: id,
                  label: _platformLabel(id),
                  accountName: _accountNameFor(id),
                  phase: _PublishPhase.fail,
                  message: message,
                ),
              );
            }
          }
        }
      }

      if (!mounted) return;

      if (tracks.isEmpty && publishedCount == 0 && sharedCount == 0 && errors.isNotEmpty) {
        throw Exception(errors.join('\n'));
      }

      if (tracks.isEmpty && publishedCount == 0 && sharedCount == 0) {
        throw Exception('Nothing was posted.');
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _PublishStatusPage(
              items: tracks,
              scheduled: postizSchedule,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(e, action: 'publishing campaign'),
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishing = false;
          _publishStatus = '';
        });
      }
    }
  }

  List<String> _publishIdsFrom(Map<String, dynamic> created) {
    final out = <String>[];
    void take(dynamic value) {
      if (value is! List) return;
      for (final e in value) {
        final s = e.toString().trim();
        if (s.isNotEmpty && !out.contains(s)) out.add(s);
      }
    }

    take(created['tiktok_publish_ids']);
    final nested = created['value'];
    if (nested is Map) take(nested['tiktok_publish_ids']);
    return out;
  }

  String _accountNameFor(String outletId) {
    for (final p in widget.postizIntegrations) {
      if (p.id != outletId) continue;
      final name = p.name.trim();
      if (name.isNotEmpty) return name;
      return (p.profile ?? '').trim();
    }
    return '';
  }

  String _platformLabel(String identifier) {
    final key = identifier.toLowerCase();
    for (final o in OutletCatalog.all) {
      if (o.postizIdentifiers.contains(key)) return o.label;
    }
    if (key.contains('facebook')) return 'Facebook';
    if (key.contains('tiktok')) return 'TikTok';
    if (key.contains('instagram')) return 'Instagram';
    if (key.contains('youtube')) return 'YouTube';
    return identifier.isEmpty ? 'Channel' : identifier;
  }

  _TrackedPublish _trackPhoneShare(
    String outletId, {
    required bool success,
    String? message,
  }) {
    final platform = switch (outletId) {
      _kShareFacebookId => 'facebook',
      _kShareTiktokId => 'tiktok',
      _ => outletId,
    };
    return _TrackedPublish(
      id: outletId,
      platform: platform,
      label: _phoneShareLabel(outletId),
      accountName: 'Share from this phone',
      phase: success ? _PublishPhase.success : _PublishPhase.fail,
      message: message ??
          (success ? 'Opened the share sheet.' : 'Share was dismissed.'),
    );
  }

  _TrackedPublish _trackInstagram(
    String outletKey, {
    required bool success,
    String? message,
  }) {
    return _TrackedPublish(
      id: outletKey,
      platform: 'instagram',
      label: 'Instagram',
      accountName: _accountNameFor(outletKey),
      phase: success ? _PublishPhase.success : _PublishPhase.fail,
      message: message ??
          (success ? 'Published to Instagram.' : 'Instagram publish failed.'),
    );
  }

  _TrackedPublish _trackPostiz(
    PostizIntegration p, {
    required bool scheduled,
    String? publishId,
    bool success = true,
    String? message,
  }) {
    final processing = success && !scheduled;
    return _TrackedPublish(
      id: p.id,
      platform: p.identifier,
      label: _platformLabel(p.identifier),
      accountName: p.name.trim().isNotEmpty
          ? p.name.trim()
          : (p.profile ?? '').trim(),
      phase: success
          ? (processing ? _PublishPhase.processing : _PublishPhase.success)
          : _PublishPhase.fail,
      message: message ??
          (success
              ? (scheduled
                  ? 'Scheduled. We’ll confirm when it goes out.'
                  : 'Sent. Checking publish status…')
              : 'Publish failed.'),
      integrationId: p.id,
      publishId: publishId,
      pollable: success,
      scheduled: scheduled,
    );
  }

  _TrackedPublish _trackGeneric(String id, {required bool scheduled}) {
    PostizIntegration? match;
    for (final p in widget.postizIntegrations) {
      if (p.id == id) {
        match = p;
        break;
      }
    }
    if (match != null) {
      return _trackPostiz(match, scheduled: scheduled);
    }
    return _TrackedPublish(
      id: id,
      platform: id,
      label: _platformLabel(id),
      accountName: _accountNameFor(id),
      phase: scheduled ? _PublishPhase.success : _PublishPhase.processing,
      message: scheduled ? 'Scheduled.' : 'Sent. Checking publish status…',
      integrationId: id,
      pollable: true,
      scheduled: scheduled,
    );
  }
}
