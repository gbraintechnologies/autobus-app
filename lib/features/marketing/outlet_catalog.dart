import 'package:autobus/features/marketing/models/postiz_integration.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Marketing outlet shown on Link Social Media; matched to Postiz `identifier` values.
class OutletOption {
  final String label;
  final FaIconData icon;
  final Color iconColor;
  final Set<String> postizIdentifiers;

  const OutletOption({
    required this.label,
    required this.icon,
    required this.iconColor,
    this.postizIdentifiers = const {},
  });

  bool matchesIntegration(PostizIntegration integration) {
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
      label: 'LinkedIn',
      icon: FontAwesomeIcons.linkedinIn,
      iconColor: Color(0xFF0A66C2),
      postizIdentifiers: {'linkedin', 'linkedin-page'},
    ),
    OutletOption(
      label: 'Facebook',
      icon: FontAwesomeIcons.facebookF,
      iconColor: Color(0xFF1877F2),
      postizIdentifiers: {'facebook'},
    ),
    OutletOption(
      label: 'WhatsApp Status',
      icon: FontAwesomeIcons.whatsapp,
      iconColor: Color(0xFF25D366),
      postizIdentifiers: {'whatsapp'},
    ),
    OutletOption(
      label: 'Instagram',
      icon: FontAwesomeIcons.instagram,
      iconColor: Color(0xFFDD2A7B),
      postizIdentifiers: {'instagram', 'instagram-standalone'},
    ),
    OutletOption(
      label: 'X',
      icon: FontAwesomeIcons.xTwitter,
      iconColor: Colors.white,
      postizIdentifiers: {'x'},
    ),
    OutletOption(
      label: 'YouTube',
      icon: FontAwesomeIcons.youtube,
      iconColor: Color(0xFFFF0000),
      postizIdentifiers: {'youtube'},
    ),
  ];

  static ({List<LinkedOutlet> linked, List<OutletOption> unlinked}) partition(
    List<PostizIntegration> integrations,
  ) {
    final linked = <LinkedOutlet>[];
    final unlinked = <OutletOption>[];

    for (final outlet in all) {
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
}
