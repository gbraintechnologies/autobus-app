import 'package:autobus/features/home/services/api_service.dart';
import 'package:autobus/features/marketing/models/postiz_integration.dart';
import 'package:autobus/features/marketing/platform_post_details.dart';
import 'package:autobus/features/marketing/tiktok_creator_info.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

const _kPurple = Color(0xFF2A1447);
const _kFill = Color(0xFFF7F5FB);
const _kBorder = Color(0xFFE8E0F0);

class TikTokDirectPostForm extends StatefulWidget {
  final ApiService api;
  final PostizIntegration integration;
  final PlatformPostDetails details;
  final bool isPhotoPost;
  final Duration? videoDuration;
  final Widget preview;
  final ValueChanged<PlatformPostDetails> onChanged;
  final ValueChanged<bool> onValidityChanged;

  const TikTokDirectPostForm({
    super.key,
    required this.api,
    required this.integration,
    required this.details,
    required this.isPhotoPost,
    required this.preview,
    required this.onChanged,
    required this.onValidityChanged,
    this.videoDuration,
  });

  @override
  State<TikTokDirectPostForm> createState() => _TikTokDirectPostFormState();
}

class _TikTokDirectPostFormState extends State<TikTokDirectPostForm> {
  TikTokCreatorInfo? _info;
  String? _loadError;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCreatorInfo();
    });
  }

  @override
  void didUpdateWidget(covariant TikTokDirectPostForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.integration.id != widget.integration.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadCreatorInfo();
      });
    } else if (oldWidget.videoDuration != widget.videoDuration ||
        oldWidget.isPhotoPost != widget.isPhotoPost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emitValidity();
      });
    }
  }

  Future<void> _loadCreatorInfo() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    widget.onValidityChanged(false);
    try {
      final info = await widget.api.getTikTokCreatorInfo(widget.integration.id);
      if (!mounted) return;
      final d = widget.details;
      if (info.commentDisabled) d.tiktokComment = false;
      if (info.duetDisabled) d.tiktokDuet = false;
      if (info.stitchDisabled) d.tiktokStitch = false;
      if (d.tiktokPrivacy.isNotEmpty &&
          info.privacyLevelOptions.isNotEmpty &&
          !info.privacyLevelOptions.contains(d.tiktokPrivacy)) {
        d.tiktokPrivacy = '';
      }
      setState(() {
        _info = info;
        _loading = false;
      });
      widget.onChanged(d);
      _emitValidity();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
        _info = null;
      });
      _emitValidity();
    }
  }

  void _emitValidity() {
    final blocked = tiktokDirectPostBlockReason(
      details: widget.details,
      info: _info,
      isPhotoPost: widget.isPhotoPost,
      videoDuration: widget.videoDuration,
      creatorInfoLoading: _loading,
    );
    widget.onValidityChanged(blocked == null);
  }

  void _patch(void Function(PlatformPostDetails d) fn) {
    fn(widget.details);
    widget.onChanged(widget.details);
    setState(() {});
    _emitValidity();
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
      hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.black38),
      filled: true,
      fillColor: _kFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPurple, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.details;
    final info = _info;
    final blocked = tiktokDirectPostBlockReason(
      details: d,
      info: info,
      isPhotoPost: widget.isPhotoPost,
      videoDuration: widget.videoDuration,
      creatorInfoLoading: _loading,
    );
    final privacyOptions = info?.privacyLevelOptions ?? const <String>[];
    final brandedLocksPrivate = d.tiktokBrandContent;
    final privateLocksBranded = d.tiktokPrivacy == 'SELF_ONLY';
    final commentOff = info?.commentDisabled == true;
    final duetOff = info?.duetDisabled == true;
    final stitchOff = info?.stitchDisabled == true;
    final labelPrompt = commercialLabelPrompt(d);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Post to TikTok',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            _creatorHeader(info),
            if (info != null && !info.canPost) ...[
              const SizedBox(height: 10),
              _notice(
                info.cannotPostReason.isNotEmpty
                    ? info.cannotPostReason
                    : 'This TikTok account cannot post right now. Try again later.',
                color: Colors.orange.shade800,
              ),
            ],
            if (_loadError != null) ...[
              const SizedBox(height: 10),
              _notice(_loadError!, color: Colors.red.shade700),
              TextButton(
                onPressed: _loadCreatorInfo,
                child: Text(
                  'Retry',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Text(
            'Preview',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          widget.preview,
          if (!widget.isPhotoPost && info?.maxVideoPostDurationSec != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.videoDuration == null
                  ? 'Longest video TikTok allows right now: ${info!.maxVideoPostDurationSec} seconds.'
                  : 'This video is ${widget.videoDuration!.inSeconds}s. TikTok allows up to ${info!.maxVideoPostDurationSec}s.',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.black45),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('tt-title-${widget.integration.id}'),
            initialValue: d.tiktokTitle,
            maxLength: 90,
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: _decoration('Title', hint: 'Edit before posting'),
            onChanged: (v) => _patch((x) => x.tiktokTitle = v),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('tt-caption-${widget.integration.id}'),
            initialValue: d.caption,
            minLines: 2,
            maxLines: 5,
            style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
            decoration: _decoration(
              'Caption / hashtags',
              hint: 'Editable before posting',
            ),
            onChanged: (v) => _patch((x) => x.caption = v),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: privacyOptions.contains(d.tiktokPrivacy)
                ? d.tiktokPrivacy
                : null,
            decoration: _decoration('Privacy status'),
            hint: Text(
              'Select privacy status',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.black38),
            ),
            items: [
              for (final key in privacyOptions)
                DropdownMenuItem(
                  value: key,
                  enabled: !(brandedLocksPrivate && key == 'SELF_ONLY'),
                  child: Tooltip(
                    message: brandedLocksPrivate && key == 'SELF_ONLY'
                        ? kTikTokBrandedPrivateHint
                        : '',
                    child: Text(
                      kTikTokPrivacyLabels[key] ?? key,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: brandedLocksPrivate && key == 'SELF_ONLY'
                            ? Colors.black38
                            : Colors.black87,
                      ),
                    ),
                  ),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              if (brandedLocksPrivate && v == 'SELF_ONLY') return;
              _patch((x) => x.tiktokPrivacy = v);
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Allow people to',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          _interactionTile(
            label: 'Allow Comment',
            value: d.tiktokComment,
            disabled: commentOff,
            onChanged: (v) => _patch((x) => x.tiktokComment = v),
          ),
          if (!widget.isPhotoPost) ...[
            _interactionTile(
              label: 'Allow Duet',
              value: d.tiktokDuet,
              disabled: duetOff,
              onChanged: (v) => _patch((x) => x.tiktokDuet = v),
            ),
            _interactionTile(
              label: 'Allow Stitch',
              value: d.tiktokStitch,
              disabled: stitchOff,
              onChanged: (v) => _patch((x) => x.tiktokStitch = v),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Disclose commercial content',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Turn on if this content promotes yourself, a brand, product, or service.',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.black45),
            ),
            value: d.tiktokDiscloseCommercial,
            activeThumbColor: _kPurple,
            onChanged: (v) => _patch((x) {
              x.tiktokDiscloseCommercial = v;
              if (!v) {
                x.tiktokBrandOrganic = false;
                x.tiktokBrandContent = false;
              }
            }),
          ),
          if (d.tiktokDiscloseCommercial) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'Your brand',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              subtitle: Text(
                'You are promoting yourself or your own business.',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.black45),
              ),
              value: d.tiktokBrandOrganic,
              onChanged: (v) =>
                  _patch((x) => x.tiktokBrandOrganic = v ?? false),
            ),
            Tooltip(
              message: privateLocksBranded ? kTikTokBrandedPrivateHint : '',
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Branded content',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: privateLocksBranded ? Colors.black38 : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  privateLocksBranded
                      ? kTikTokBrandedPrivateHint
                      : 'You are promoting another brand or a third party.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.black45,
                  ),
                ),
                value: d.tiktokBrandContent,
                onChanged: privateLocksBranded
                    ? null
                    : (v) => _patch((x) => x.tiktokBrandContent = v ?? false),
              ),
            ),
            if (!d.tiktokBrandOrganic && !d.tiktokBrandContent)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  kTikTokDisclosureHint,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            if (labelPrompt.isNotEmpty)
              _notice(labelPrompt, color: _kPurple),
          ],
          const SizedBox(height: 8),
          _consentLine(tiktokConsentText(d)),
          const SizedBox(height: 8),
          Text(
            kTikTokProcessingNotice,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.black45,
              height: 1.35,
            ),
          ),
          if (blocked != null && info?.canPost != false && !_loading) ...[
            const SizedBox(height: 10),
            _notice(blocked, color: Colors.orange.shade800),
          ],
        ],
      ),
    );
  }

  Widget _creatorHeader(TikTokCreatorInfo? info) {
    final name = info?.displayName ?? widget.integration.name;
    final handle = info?.handle ?? '';
    final avatar = info?.avatarUrl.trim() ?? '';
    return Row(
      children: [
        if (avatar.startsWith('http'))
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(avatar),
            onBackgroundImageError: (_, __) {},
          )
        else
          const CircleAvatar(
            radius: 18,
            backgroundColor: _kFill,
            child: Icon(Icons.person, color: _kPurple, size: 18),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Posting as $name',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (handle.isNotEmpty)
                Text(
                  handle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.black45,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _interactionTile({
    required String label,
    required bool value,
    required bool disabled,
    required ValueChanged<bool> onChanged,
  }) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: disabled ? Colors.black38 : Colors.black87,
        ),
      ),
      value: disabled ? false : value,
      onChanged: disabled
          ? null
          : (v) => onChanged(v ?? false),
    );
  }

  Widget _consentLine(String text) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          text,
          style: GoogleFonts.poppins(fontSize: 11, height: 1.35),
        ),
        TextButton(
          onPressed: () => _open(kTikTokMusicUsageUrl),
          child: Text(
            'Music Usage Confirmation',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (widget.details.tiktokBrandContent)
          TextButton(
            onPressed: () => _open(kTikTokBrandedContentPolicyUrl),
            child: Text(
              'Branded Content Policy',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _notice(String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 12, color: color, height: 1.35),
      ),
    );
  }
}
