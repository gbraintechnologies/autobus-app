part of 'digital_marketing.dart';

class _TikTokConsentPage extends StatefulWidget {
  final DigitalMarketingCampaign campaign;
  final List<PostizIntegration> tiktokIntegrations;
  final List<PostizIntegration> postizIntegrations;
  final List<Map<String, dynamic>> blotatoAccounts;
  final bool usePostiz;
  final bool useBlotato;

  const _TikTokConsentPage({
    required this.campaign,
    required this.tiktokIntegrations,
    required this.postizIntegrations,
    required this.blotatoAccounts,
    required this.usePostiz,
    required this.useBlotato,
  });

  @override
  State<_TikTokConsentPage> createState() => _TikTokConsentPageState();
}

class _TikTokConsentPageState extends State<_TikTokConsentPage> {
  final ApiService _apiService = ApiService(
    httpClient: SessionAwareHttpClient(tokenService: TokenService()),
  );
  final Map<String, bool> _ready = {};
  final Map<String, Duration> _videoDurations = {};
  Duration? _videoDuration;

  DigitalMarketingCampaign get _campaign => widget.campaign;

  bool get _isPhotoPost => !_campaign.selectedContents.any(
        (c) => c.type == MarketingContentType.videos,
      );

  bool get _canContinue {
    for (final p in widget.tiktokIntegrations) {
      if (_ready[p.id] != true) return false;
    }
    return widget.tiktokIntegrations.isNotEmpty;
  }

  PlatformPostDetails _detailsFor(String id) {
    return _campaign.outletDetails.putIfAbsent(
      id,
      () => PlatformPostDetails.fromCampaignCaption(_campaign.campaignCaption),
    );
  }

  void _safeSetState(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(fn);
    });
  }

  void _onPreviewDuration(String contentId, Duration duration) {
    if (duration <= Duration.zero) return;
    if (_videoDurations[contentId] == duration) return;
    _videoDurations[contentId] = duration;
    Duration? longest;
    for (final c in _campaign.selectedContents) {
      if (c.type != MarketingContentType.videos) continue;
      final d = _videoDurations[c.id];
      if (d == null) continue;
      if (longest == null || d > longest) longest = d;
    }
    if (!mounted || _videoDuration == longest) return;
    _safeSetState(() => _videoDuration = longest);
  }

  void _continue() {
    if (!_canContinue) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FinalizePostPage(
          campaign: _campaign,
          postizIntegrations: widget.postizIntegrations,
          blotatoAccounts: widget.blotatoAccounts,
          usePostiz: widget.usePostiz,
          useBlotato: widget.useBlotato,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _MarketingScaffold(
      child: Column(
        children: [
          Text(
            'Post to TikTok',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Review the preview and settings, then tap Yes to continue.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.black45,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: [
                for (final p in widget.tiktokIntegrations) ...[
                  TikTokDirectPostForm(
                    key: ValueKey('tt-consent-${p.id}'),
                    api: _apiService,
                    integration: p,
                    details: _detailsFor(p.id),
                    isPhotoPost: _isPhotoPost,
                    videoDuration: _videoDuration,
                    preview: _preview(),
                    onChanged: (_) => _safeSetState(() {}),
                    onValidityChanged: (ok) {
                      if (_ready[p.id] == ok) return;
                      _safeSetState(() => _ready[p.id] = ok);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          _DarkButton(
            label: 'Yes, continue',
            compact: true,
            onTap: _canContinue ? _continue : null,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _preview() {
    final media = _campaign.selectedContents
        .where((c) => c.type != MarketingContentType.text)
        .toList();
    if (media.isEmpty) {
      return Container(
        height: 88,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F5FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Select a photo or video to preview what will be posted.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.black45),
        ),
      );
    }
    return Column(
      children: [
        for (final content in media.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: content.type == MarketingContentType.videos
                    ? _videoPreview(content)
                    : (_imagePreview(content) ?? _fallbackThumb(content)),
              ),
            ),
          ),
      ],
    );
  }

  Widget? _imagePreview(MarketingContent content) {
    if (content.generatedBytes != null) {
      return Image.memory(content.generatedBytes!, fit: BoxFit.cover);
    }
    if (!kIsWeb &&
        content.localFilePath != null &&
        File(content.localFilePath!).existsSync()) {
      return Image.file(File(content.localFilePath!), fit: BoxFit.cover);
    }
    if (content.hasRemoteUrl) {
      return Image.network(content.generatedResult!, fit: BoxFit.cover);
    }
    return null;
  }

  Widget _videoPreview(MarketingContent content) {
    final ref = (content.localFilePath?.trim().isNotEmpty == true
            ? content.localFilePath
            : content.generatedResult)
        ?.trim();
    if (ref != null && ref.isNotEmpty) {
      return ColoredBox(
        color: Colors.black,
        child: _MarketingInlineVideoPlayer(
          key: ValueKey('tt-consent-preview-${content.id}'),
          videoRef: ref,
          autoPlay: false,
          looping: false,
          onDuration: (duration) => _onPreviewDuration(content.id, duration),
        ),
      );
    }
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Icon(Icons.play_circle_fill_rounded, color: _kHeaderPurple, size: 48),
      ),
    );
  }

  Widget _fallbackThumb(MarketingContent content) {
    return ColoredBox(
      color: const Color(0xFFF7F5FB),
      child: Icon(
        content.type == MarketingContentType.pictures
            ? Icons.image_outlined
            : Icons.play_circle_fill_rounded,
        color: _kHeaderPurple,
      ),
    );
  }
}
