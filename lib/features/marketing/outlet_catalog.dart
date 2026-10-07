import 'package:autobus/features/marketing/models/postiz_integration.dart';
import 'package:autobus/icons/figma_icons.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Prefix for Autobus Instagram Business Login accounts (not Postiz).
const kAutobusIgPrefix = 'autobus-ig-';

/// Marketing outlet shown on Link Social Media; matched to Postiz `identifier` values.
class OutletOption {
  final String label;
  final FaIconData icon;
  final String? iconAsset;
  final Color iconColor;
  final Color tileColor;
  final String linkSubtitle;
  final Set<String> postizIdentifiers;

  /// Postiz connect path slug (`facebook`, `instagram`, `tiktok`, …).
  final String? connectSlug;

  /// True when posting happens via the phone share sheet, not a linked account.
  final bool shareOnDevice;

  final String? helperText;

  const OutletOption({
    required this.label,
    required this.icon,
    this.iconAsset,
    required this.iconColor,
    required this.tileColor,
    required this.linkSubtitle,
    this.postizIdentifiers = const {},
    this.connectSlug,
    this.shareOnDevice = false,
    this.helperText,
  });

  bool matchesIntegration(PostizIntegration integration) {
    if (shareOnDevice) return false;
    if (!integration.isActive) return false;
    if (postizIdentifiers.isEmpty) return false;
    return postizIdentifiers.contains(integration.identifier.toLowerCase());
  }
}

class LinkedOutlet {
  final OutletOption outlet;
  final List<PostizIntegration> integrations;

  const LinkedOutlet({required this.outlet, required this.integrations});

  PostizIntegration get primary => integrations.first;

  String get subtitle {
    if (integrations.length == 1) {
      final name = primary.name.trim();
      if (name.isNotEmpty) return name;
      final profile = primary.profile?.trim();
      if (profile != null && profile.isNotEmpty) return profile;
    }
    return '${integrations.length} accounts';
  }
}

class OutletCatalog {
  OutletCatalog._();

  static const List<OutletOption> all = [
    OutletOption(
      label: 'Instagram',
      icon: FontAwesomeIcons.instagram,
      iconAsset: FigmaIcons.instagram,
      iconColor: Color(0xFFE60B51),
      tileColor: Color(0xFFE60B51),
      linkSubtitle: 'Link instagram',
      postizIdentifiers: {'instagram', 'instagram-standalone'},
      connectSlug: 'instagram', // Autobus Business Login (inbox + posting)
    ),
    OutletOption(
      label: 'YouTube',
      icon: FontAwesomeIcons.youtube,
      iconAsset: FigmaIcons.youtube,
      iconColor: Color(0xFFED1F1F),
      tileColor: Color(0xFFED1F1F),
      linkSubtitle: 'Link youtube',
      postizIdentifiers: {'youtube'},
      connectSlug: 'youtube',
    ),
    OutletOption(
      label: 'Tiktok',
      icon: FontAwesomeIcons.tiktok,
      iconAsset: FigmaIcons.tiktok,
      iconColor: Colors.black,
      tileColor: Colors.black,
      linkSubtitle: 'Link tiktok',
      postizIdentifiers: {'tiktok'},
      connectSlug: 'tiktok',
    ),
    OutletOption(
      label: 'Facebook Page',
      icon: FontAwesomeIcons.facebookF,
      iconColor: Color(0xFF3D5A98),
      tileColor: Color(0xFF3D5A98),
      linkSubtitle: 'Link a Facebook Page',
      postizIdentifiers: {'facebook'},
      connectSlug: 'facebook',
      helperText: 'Connect a Facebook Page for Digital Marketing posts.',
    ),
  ];

  static ({List<LinkedOutlet> linked, List<OutletOption> unlinked}) partition(
    List<PostizIntegration> integrations,
  ) {
    final linked = <LinkedOutlet>[];
    final unlinked = <OutletOption>[];

    for (final outlet in all) {
      if (outlet.shareOnDevice) continue;
      final matches =
          integrations.where((i) => outlet.matchesIntegration(i)).toList();
      if (matches.isNotEmpty) {
        linked.add(LinkedOutlet(outlet: outlet, integrations: matches));
      } else {
        unlinked.add(outlet);
      }
    }

    return (linked: linked, unlinked: unlinked);
  }

  static String? iconAssetFor(FaIconData icon) {
    for (final outlet in all) {
      if (outlet.icon == icon) return outlet.iconAsset;
    }
    return null;
  }
}
