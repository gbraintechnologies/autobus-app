import 'package:autobus/features/home/services/api_service.dart';
import 'package:autobus/features/marketing/models/postiz_integration.dart';
import 'package:autobus/features/marketing/outlet_catalog.dart';
import 'package:autobus/features/marketing/platform_post_details.dart';
import 'package:autobus/features/marketing/postiz_create_post_payload.dart';
import 'package:autobus/features/products/product_media.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

Future<List<PostizIntegration>> loadLinkedMarketingIntegrations(
  ApiService api,
) async {
  final integrations = <PostizIntegration>[];
  try {
    integrations.addAll(await api.listPostizIntegrations());
  } catch (_) {}
  try {
    final igAccounts = await api.listInstagramAccounts();
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
      integrations.add(
        PostizIntegration(
          id: '$kAutobusIgPrefix$unlinkId',
          name: label.isNotEmpty ? label : 'Instagram',
          identifier: 'instagram',
          picture: (row['profile_picture_url'] ?? '').toString(),
          disabled: false,
          profile: username.isNotEmpty ? username : null,
        ),
      );
    }
  } catch (_) {}

  return integrations
      .where(
        (p) =>
            p.isActive &&
            p.identifier.toLowerCase() != 'whatsapp' &&
            p.identifier.toLowerCase() != 'facebook',
      )
      .toList();
}

String buildProductSocialCaption({
  required String name,
  String? description,
  required String priceLabel,
  String? link,
}) {
  final parts = <String>[name.trim()];
  final desc = description?.trim() ?? '';
  if (desc.isNotEmpty) parts.add(desc);
  if (priceLabel.trim().isNotEmpty) parts.add(priceLabel.trim());
  final href = link?.trim() ?? '';
  if (href.isNotEmpty) parts.add(href);
  return parts.join('\n\n');
}

class ProductSocialPublishResult {
  final int publishedCount;
  final List<String> errors;

  const ProductSocialPublishResult({
    required this.publishedCount,
    required this.errors,
  });

  bool get hasWork => publishedCount > 0 || errors.isNotEmpty;
}

/// Publishes product media to the selected linked marketing channels.
Future<ProductSocialPublishResult> publishProductToSocialChannels({
  required ApiService api,
  required List<PostizIntegration> allIntegrations,
  required Set<String> selectedIds,
  required String caption,
  required List<String> mediaUrls,
}) async {
  if (selectedIds.isEmpty) {
    return const ProductSocialPublishResult(publishedCount: 0, errors: []);
  }

  final selected = allIntegrations
      .where((p) => selectedIds.contains(p.id) && p.isActive)
      .toList();
  if (selected.isEmpty) {
    return const ProductSocialPublishResult(
      publishedCount: 0,
      errors: ['No matching linked channels for the selection.'],
    );
  }

  final hasVideo = mediaUrls.any(productMediaLooksLikeVideo);
  final errors = <String>[];
  var publishedCount = 0;

  final igIds = <String>[];
  final postiz = <PostizIntegration>[];
  for (final p in selected) {
    if (p.id.startsWith(kAutobusIgPrefix)) {
      igIds.add(p.id.substring(kAutobusIgPrefix.length));
      continue;
    }
    final id = p.identifier.toLowerCase();
    if ((id == 'youtube' || id == 'tiktok') && !hasVideo) {
      errors.add('${p.name.isNotEmpty ? p.name : p.identifier} needs a video.');
      continue;
    }
    postiz.add(p);
  }

  if (igIds.isNotEmpty) {
    if (mediaUrls.isEmpty) {
      errors.add('Instagram needs at least one image or video.');
    } else {
      for (final accountId in igIds) {
        try {
          await api.publishInstagramPost(
            accountId: accountId,
            caption: caption,
            mediaUrls: mediaUrls,
          );
          publishedCount++;
        } catch (e) {
          errors.add(e.toString());
        }
      }
    }
  }

  if (postiz.isNotEmpty) {
    try {
      final details = <String, PlatformPostDetails>{};
      for (final p in postiz) {
        details[p.id] = PlatformPostDetails.fromCampaignCaption(caption);
      }
      await api.createPostizPost(
        buildPostizCreatePostPayload(
          selectedIntegrations: postiz,
          content: caption,
          mediaUrls: mediaUrls,
          postRightAway: true,
          outletDetails: details,
        ),
        agentName: 'digital_marketing',
      );
      publishedCount += postiz.length;
    } catch (e) {
      errors.add(e.toString());
    }
  }

  return ProductSocialPublishResult(
    publishedCount: publishedCount,
    errors: errors,
  );
}

class ProductSocialChannelPicker extends StatelessWidget {
  final List<PostizIntegration> integrations;
  final Set<String> selectedIds;
  final bool hasVideo;
  final bool busy;
  final ValueChanged<String> onToggle;

  const ProductSocialChannelPicker({
    super.key,
    required this.integrations,
    required this.selectedIds,
    required this.hasVideo,
    required this.onToggle,
    this.busy = false,
  });

  OutletOption? _outletFor(PostizIntegration p) {
    for (final o in OutletCatalog.all) {
      if (o.matchesIntegration(p)) return o;
    }
    return null;
  }

  bool _needsVideo(PostizIntegration p) {
    final id = p.identifier.toLowerCase();
    return id == 'youtube' || id == 'tiktok';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Post to social channels',
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          integrations.isEmpty
              ? 'Link Instagram, YouTube, or TikTok in Marketing to post this product when you create it.'
              : 'Optional. Select any linked channel to publish this product after you create it.',
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        if (integrations.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in integrations)
                _ChannelChip(
                  integration: p,
                  outlet: _outletFor(p),
                  selected: selectedIds.contains(p.id),
                  disabled: busy || (_needsVideo(p) && !hasVideo),
                  needsVideo: _needsVideo(p) && !hasVideo,
                  onTap: () => onToggle(p.id),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final PostizIntegration integration;
  final OutletOption? outlet;
  final bool selected;
  final bool disabled;
  final bool needsVideo;
  final VoidCallback onTap;

  const _ChannelChip({
    required this.integration,
    required this.outlet,
    required this.selected,
    required this.disabled,
    required this.needsVideo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = integration.name.trim().isNotEmpty
        ? integration.name.trim()
        : (outlet?.label ?? integration.identifier);
    final color = outlet?.iconColor ?? const Color(0xFFA855F7);

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? color
                    : const Color(0xFF3F1163).withValues(alpha: 0.85),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (outlet != null)
                  FaIcon(outlet!.icon, color: color, size: 14)
                else
                  Icon(Icons.public, color: color, size: 14),
                const SizedBox(width: 6),
                Text(
                  needsVideo ? '$label (needs video)' : label,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle, color: color, size: 14),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
