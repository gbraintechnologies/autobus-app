part of 'digital_marketing.dart';

class _ComposePostPage extends StatefulWidget {
  final DigitalMarketingCampaign campaign;

  const _ComposePostPage({required this.campaign});

  @override
  State<_ComposePostPage> createState() => _ComposePostPageState();
}

class _ComposePostPageState extends State<_ComposePostPage> {
  final ApiService _apiService = ApiService(
    httpClient: SessionAwareHttpClient(tokenService: TokenService()),
  );

  List<PostizIntegration> _postizIntegrations = [];
  List<Map<String, dynamic>> _blotatoAccounts = [];
  bool _loadingAccounts = true;
  bool _generatingMeta = false;
  final Map<String, bool> _expanded = {};

  DigitalMarketingCampaign get _campaign => widget.campaign;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    List<PostizIntegration> postiz = [];
    List<Map<String, dynamic>> blotato = [];
    try {
      postiz = List<PostizIntegration>.from(
        await _apiService.listPostizIntegrations(),
      );
    } catch (_) {}
    try {
      final igAccounts = await _apiService.listInstagramAccounts();
      for (final row in igAccounts) {
        final username = (row['username'] ?? '').toString().trim();
        final name = (row['name'] ?? '').toString().trim();
        final dbId = (row['id'] ?? '').toString().trim();
        final igId = (row['ig_user_id'] ?? dbId).toString();
        final label = username.isNotEmpty
            ? '@$username'
            : (name.isNotEmpty ? name : igId);
        final unlinkId = dbId.isNotEmpty ? dbId : igId;
        if (unlinkId.isEmpty) continue;
        postiz.add(
          PostizIntegration(
            id: '$_kAutobusIgPrefix$unlinkId',
            name: label.isNotEmpty ? label : 'Instagram',
            identifier: 'instagram',
            picture: (row['profile_picture_url'] ?? '').toString(),
            disabled: false,
            profile: username.isNotEmpty ? username : null,
          ),
        );
      }
    } catch (_) {}
    try {
      blotato = await _apiService.getSocialAccounts();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _postizIntegrations = postiz
          .where(
            (p) => p.isActive && p.identifier.toLowerCase() != 'whatsapp',
          )
          .toList();
      _blotatoAccounts = blotato;
      _loadingAccounts = false;
    });
  }

  bool get _usePostiz => _postizIntegrations.isNotEmpty;
  bool get _useBlotato => !_usePostiz && _blotatoAccounts.isNotEmpty;

  OutletOption? _outletFor(PostizIntegration p) {
    for (final o in OutletCatalog.all) {
      if (o.matchesIntegration(p)) return o;
    }
    return null;
  }

  void _toggleOutlet(String id) {
    setState(() {
      if (_campaign.selectedOutlets.contains(id)) {
        _campaign.selectedOutlets.remove(id);
      } else {
        _campaign.selectedOutlets.add(id);
        _campaign.outletDetails.putIfAbsent(
          id,
          () => PlatformPostDetails.fromCampaignCaption(_campaign.campaignCaption),
        );
      }
    });
  }

  PlatformPostDetails _detailsFor(String id) {
    return _campaign.outletDetails.putIfAbsent(
      id,
      () => PlatformPostDetails.fromCampaignCaption(_campaign.campaignCaption),
    );
  }

  bool get _hasSelectedContent => _campaign.selectedContents.isNotEmpty;

  bool _manualMetadataComplete() {
    if (_campaign.aiGenerateMetadata) return true;
    if (_campaign.selectedOutlets.isEmpty) return false;
    for (final id in _campaign.selectedOutlets) {
      final d = _detailsFor(id);
      if (d.caption.trim().isEmpty) return false;
      if (id == _kShareYoutubeId ||
          (_postizIntegrations.any(
            (p) => p.id == id && p.identifier.toLowerCase() == 'youtube',
          ))) {
        if (d.youtubeTitle.trim().length < 2) return false;
      }
    }
    return true;
  }

  bool get _canGoNext =>
      _hasSelectedContent &&
      _campaign.selectedOutlets.isNotEmpty &&
      _manualMetadataComplete() &&
      !_generatingMeta;

  Future<void> _goNext() async {
    if (!_canGoNext) return;

    if (_campaign.aiGenerateMetadata) {
      setState(() => _generatingMeta = true);
      try {
        await _generateMetadataWithAi();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(e, action: 'generating captions'),
            ),
          ),
        );
        setState(() => _generatingMeta = false);
        return;
      }
      if (!mounted) return;
      setState(() => _generatingMeta = false);
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FinalizePostPage(
          campaign: _campaign,
          postizIntegrations: _postizIntegrations,
          blotatoAccounts: _blotatoAccounts,
          usePostiz: _usePostiz,
          useBlotato: _useBlotato,
        ),
      ),
    );
  }

  Future<void> _generateMetadataWithAi() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    String userId = '';
    if (userJson != null) {
      final user = jsonDecode(userJson) as Map<String, dynamic>;
      userId = (user['id'] ?? user['phone'] ?? '').toString();
    }

    final platforms = _campaign.selectedOutlets.map((id) {
      if (_isPhoneShareOutlet(id)) return _phoneShareLabel(id);
      for (final p in _postizIntegrations) {
        if (p.id == id) return p.identifier;
      }
      return id;
    }).join(', ');

    final prompt = '''
Based on this marketing conversation, write social post metadata.
Return ONLY valid JSON with this shape (omit keys you cannot fill):
{
  "caption": "default caption for all platforms",
  "youtube_title": "2-100 chars",
  "youtube_tags": "tag1, tag2",
  "tiktok_title": "max 90 chars",
  "instagram_caption": "instagram caption"
}

Platforms: $platforms

Conversation:
${_campaign.conversationTranscript}
''';

    final raw = await _apiService.generateAgentContent(
      userId: userId,
      prompt: prompt,
      agentName: 'digital_marketing',
    );
    final parsed = _extractJson(raw);
    final caption = stripAiMarkdown(
      (parsed?['caption'] ?? raw).toString().trim(),
    );
    final ytTitle = stripAiMarkdown(
      (parsed?['youtube_title'] ?? '').toString().trim(),
    );
    final ytTags = (parsed?['youtube_tags'] ?? '').toString().trim();
    final ttTitle = stripAiMarkdown(
      (parsed?['tiktok_title'] ?? '').toString().trim(),
    );
    final igCaption = stripAiMarkdown(
      (parsed?['instagram_caption'] ?? caption).toString().trim(),
    );

    for (final id in _campaign.selectedOutlets) {
      final d = PlatformPostDetails.fromCampaignCaption(
        caption.isEmpty ? _campaign.campaignCaption : caption,
      );
      if (ytTitle.isNotEmpty) d.youtubeTitle = ytTitle;
      if (ytTags.isNotEmpty) d.youtubeTagsCsv = ytTags;
      if (ttTitle.isNotEmpty) d.tiktokTitle = ttTitle;

      final isIg = id == _kShareInstagramId ||
          _postizIntegrations.any(
            (p) =>
                p.id == id &&
                (p.identifier == 'instagram' ||
                    p.identifier == 'instagram-standalone'),
          );
      if (isIg && igCaption.isNotEmpty) d.caption = igCaption;
      _campaign.outletDetails[id] = d;
    }
  }

  Map<String, dynamic>? _extractJson(String raw) {
    var body = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final m = fence.firstMatch(body);
    if (m != null) body = m.group(1)!.trim();
    final start = body.indexOf('{');
    final end = body.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(body.substring(start, end + 1));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.montserrat(fontSize: 12, color: Colors.black54),
      hintStyle: GoogleFonts.montserrat(fontSize: 12, color: Colors.black38),
      filled: true,
      fillColor: const Color(0xFFF7F5FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE8E0F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE8E0F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kHeaderPurple, width: 1.4),
      ),
    );
  }

  Widget _captionField(PlatformPostDetails d) {
    return TextFormField(
      key: ValueKey('caption-${identityHashCode(d)}'),
      initialValue: d.caption,
      minLines: 3,
      maxLines: 6,
      onTapOutside: dismissAppKeyboard,
      style: GoogleFonts.montserrat(fontSize: 13, height: 1.4),
      decoration: _fieldDecoration('Caption', hint: 'Post caption / description'),
      onChanged: (v) {
        d.caption = v;
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _MarketingScaffold(
      child: Stack(
        children: [
          Column(
            children: [
              Text(
                'Choose what to post',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select generated content, platforms, and captions',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 12, color: Colors.black45),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: [
                    _sectionTitle('Generated content'),
                    const SizedBox(height: 8),
                    ..._campaign.generatedContents.map(_contentTile),
                    if (_campaign.generatedContents.isEmpty)
                      Text(
                        'No generated content yet.',
                        style: GoogleFonts.montserrat(fontSize: 13, color: Colors.black45),
                      ),
                    const SizedBox(height: 22),
                    _sectionTitle('Platforms'),
                    const SizedBox(height: 8),
                    ..._phoneShareTiles(),
                    if (_loadingAccounts)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: AutobusLoadingIndicator()),
                      )
                    else ...[
                      for (final p in _postizIntegrations) ...[
                        const SizedBox(height: 10),
                        _postizTile(p),
                      ],
                    ],
                    const SizedBox(height: 22),
                    _sectionTitle('Captions & metadata'),
                    const SizedBox(height: 8),
                    _metadataModeCard(
                      title: 'Let AI write captions',
                      subtitle:
                          'We’ll send this chat (text only) to Autobus to fill titles and captions.',
                      selected: _campaign.aiGenerateMetadata,
                      onTap: () => setState(() => _campaign.aiGenerateMetadata = true),
                    ),
                    const SizedBox(height: 10),
                    _metadataModeCard(
                      title: 'I’ll write them',
                      subtitle: 'Fill captions for every selected platform before continuing.',
                      selected: !_campaign.aiGenerateMetadata,
                      onTap: () => setState(() => _campaign.aiGenerateMetadata = false),
                    ),
                    if (!_campaign.aiGenerateMetadata) ...[
                      const SizedBox(height: 14),
                      ..._manualMetadataCards(),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              _DarkButton(
                label: 'Next',
                compact: true,
                onTap: _canGoNext ? _goNext : null,
              ),
              const SizedBox(height: 12),
            ],
          ),
          if (_generatingMeta)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.88),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AutobusLoadingIndicator(size: 36),
                      const SizedBox(height: 16),
                      Text(
                        'Writing captions…',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.montserrat(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Widget _contentTile(MarketingContent content) {
    final selected = content.selectedForPost;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => content.selectedForPost = !content.selectedForPost),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? _kSelectGreen.withValues(alpha: 0.06) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? _kSelectGreen : Colors.grey.shade200,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                _contentThumb(content),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.label,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        content.type == MarketingContentType.text
                            ? content.displayText
                            : (content.prompt ?? content.label),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? _kSelectGreen : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contentThumb(MarketingContent content) {
    Widget child;
    if (content.type == MarketingContentType.text) {
      child = Icon(Icons.notes_rounded, color: _kHeaderPurple);
    } else if (content.type == MarketingContentType.pictures) {
      if (content.generatedBytes != null) {
        child = Image.memory(content.generatedBytes!, fit: BoxFit.cover);
      } else if (!kIsWeb &&
          content.localFilePath != null &&
          File(content.localFilePath!).existsSync()) {
        child = Image.file(File(content.localFilePath!), fit: BoxFit.cover);
      } else if (content.hasRemoteUrl) {
        child = Image.network(content.generatedResult!, fit: BoxFit.cover);
      } else {
        child = Icon(Icons.image_outlined, color: _kHeaderPurple);
      }
    } else {
      child = Icon(Icons.play_circle_fill_rounded, color: _kHeaderPurple);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: 52, height: 52, child: child),
    );
  }

  List<Widget> _phoneShareTiles() {
    const targets = <List<dynamic>>[
      [_kShareFacebookId, 'Facebook', FontAwesomeIcons.facebookF, Color(0xFF1877F2)],
      [_kWhatsAppStatusOutletId, 'WhatsApp Status', FontAwesomeIcons.whatsapp, _kWhatsAppStatusGreen],
      [_kShareInstagramId, 'Instagram', FontAwesomeIcons.instagram, Color(0xFFDD2A7B)],
      [_kShareYoutubeId, 'YouTube', FontAwesomeIcons.youtube, Color(0xFFFF0000)],
      [_kShareTiktokId, 'TikTok', FontAwesomeIcons.tiktok, Color(0xFF69C9D0)],
    ];
    final out = <Widget>[];
    for (final t in targets) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _outletTile(
            id: t[0] as String,
            label: t[1] as String,
            subtitle: 'Share from this phone',
            icon: t[2] as FaIconData,
            color: t[3] as Color,
          ),
        ),
      );
    }
    return out;
  }

  Widget _postizTile(PostizIntegration p) {
    final outlet = _outletFor(p);
    final accountName = p.name.trim().isNotEmpty
        ? p.name.trim()
        : (p.profile?.trim() ?? '');
    final pic = p.picture?.trim();
    return _outletTile(
      id: p.id,
      label: outlet?.label ?? (p.identifier.isNotEmpty ? p.identifier : 'Channel'),
      subtitle: accountName.isEmpty
          ? 'Post with Postiz'
          : '$accountName · Postiz',
      icon: outlet?.icon ?? FontAwesomeIcons.globe,
      color: outlet?.iconColor ?? _kPurple,
      avatar: pic != null &&
              (pic.startsWith('http://') || pic.startsWith('https://'))
          ? CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(pic),
              onBackgroundImageError: (_, __) {},
            )
          : null,
    );
  }

  Widget _outletTile({
    required String id,
    required String label,
    String? subtitle,
    required FaIconData icon,
    required Color color,
    Widget? avatar,
  }) {
    final sel = _campaign.selectedOutlets.contains(id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleOutlet(id),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: sel ? _kSelectGreen.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? _kSelectGreen : Colors.grey.shade200,
              width: sel ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              avatar ??
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(child: FaIcon(icon, size: 20, color: color)),
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: sel ? 1 : 0,
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _kSelectGreen,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metadataModeCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? _kHeaderPurple.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _kHeaderPurple : Colors.grey.shade200,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? _kHeaderPurple : Colors.black26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: Colors.black45,
                        height: 1.35,
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

  List<Widget> _manualMetadataCards() {
    final cards = <Widget>[];
    for (final id in _campaign.selectedOutlets) {
      if (_isPhoneShareOutlet(id)) {
        cards.add(_manualCard(
          id: id,
          label: _phoneShareLabel(id),
          icon: FontAwesomeIcons.share,
          color: _kHeaderPurple,
          kind: id == _kShareYoutubeId
              ? PlatformDetailsKind.youtube
              : id == _kShareTiktokId
                  ? PlatformDetailsKind.tiktok
                  : id == _kShareInstagramId
                      ? PlatformDetailsKind.instagram
                      : PlatformDetailsKind.generic,
          autobusIg: false,
        ));
        continue;
      }
      PostizIntegration? match;
      for (final p in _postizIntegrations) {
        if (p.id == id) match = p;
      }
      if (match == null) continue;
      final outlet = _outletFor(match);
      cards.add(_manualCard(
        id: id,
        label: outlet?.label ?? match.identifier,
        icon: outlet?.icon ?? FontAwesomeIcons.globe,
        color: outlet?.iconColor ?? _kPurple,
        kind: platformDetailsKindFor(match.identifier),
        autobusIg: match.id.startsWith(_kAutobusIgPrefix),
      ));
    }
    return cards;
  }

  Widget _manualCard({
    required String id,
    required String label,
    required FaIconData icon,
    required Color color,
    required PlatformDetailsKind kind,
    required bool autobusIg,
  }) {
    final expanded = _expanded[id] ?? true;
    final d = _detailsFor(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded[id] = !expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    FaIcon(icon, size: 18, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.black45,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: _manualFields(d, kind, autobusIg),
              ),
          ],
        ),
      ),
    );
  }

  Widget _manualFields(
    PlatformPostDetails d,
    PlatformDetailsKind kind,
    bool autobusIg,
  ) {
    if (kind == PlatformDetailsKind.youtube) {
      return Column(
        children: [
          TextFormField(
            key: ValueKey('yt-title-${identityHashCode(d)}'),
            initialValue: d.youtubeTitle,
            onTapOutside: dismissAppKeyboard,
            style: GoogleFonts.montserrat(fontSize: 13),
            decoration: _fieldDecoration('Title', hint: '2–100 characters'),
            onChanged: (v) {
              d.youtubeTitle = v;
              setState(() {});
            },
          ),
          const SizedBox(height: 10),
          _captionField(d),
        ],
      );
    }
    if (kind == PlatformDetailsKind.tiktok) {
      return Column(
        children: [
          TextFormField(
            key: ValueKey('tt-title-${identityHashCode(d)}'),
            initialValue: d.tiktokTitle,
            onTapOutside: dismissAppKeyboard,
            style: GoogleFonts.montserrat(fontSize: 13),
            decoration: _fieldDecoration('Title', hint: 'Max 90 characters'),
            onChanged: (v) {
              d.tiktokTitle = v;
              setState(() {});
            },
          ),
          const SizedBox(height: 10),
          _captionField(d),
        ],
      );
    }
    return Column(
      children: [
        _captionField(d),
        if (autobusIg) ...[
          const SizedBox(height: 8),
          Text(
            'Autobus Instagram publishes caption + media only.',
            style: GoogleFonts.montserrat(fontSize: 11, color: Colors.black45),
          ),
        ],
      ],
    );
  }
}
