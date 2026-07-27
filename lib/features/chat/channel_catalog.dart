import 'package:autobus/features/chat/models/chatwoot_inbox.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Messaging channel on Manage Channels; matched to Chatwoot inbox `kind`.
class ChannelOption {
  final String label;
  final String apiSlug;
  final FaIconData icon;
  final Color iconColor;
  final Set<String> chatwootKinds;

  const ChannelOption({
    required this.label,
    required this.apiSlug,
    required this.icon,
    required this.iconColor,
    required this.chatwootKinds,
  });

  bool matchesInbox(ChatwootInbox inbox) {
    if (!inbox.isActive) return false;
    if (inbox.kind.isEmpty || inbox.kind == 'api') return false;
    return chatwootKinds.contains(inbox.kind);
  }
}

class LinkedChannel {
  final ChannelOption channel;
  final List<ChatwootInbox> inboxes;

  const LinkedChannel({required this.channel, required this.inboxes});

  String get subtitle {
    if (inboxes.length == 1) {
      final name = inboxes.first.name.trim();
      if (name.isNotEmpty) return name;
    }
    return '${inboxes.length} inboxes';
  }
}

class ChannelCatalog {
  ChannelCatalog._();

  static const List<ChannelOption> all = [
    ChannelOption(
      label: 'LinkedIn',
      apiSlug: 'linkedin',
      icon: FontAwesomeIcons.linkedinIn,
      iconColor: Color(0xFF0A66C2),
      chatwootKinds: {'linkedin'},
    ),
    ChannelOption(
      label: 'Facebook',
      apiSlug: 'facebook',
      icon: FontAwesomeIcons.facebookF,
      iconColor: Color(0xFF1877F2),
      chatwootKinds: {'facebook'},
    ),
    ChannelOption(
      label: 'WhatsApp Status',
      apiSlug: 'whatsapp',
      icon: FontAwesomeIcons.whatsapp,
      iconColor: Color(0xFF25D366),
      chatwootKinds: {'whatsapp'},
    ),
    ChannelOption(
      label: 'X',
      apiSlug: 'twitter',
      icon: FontAwesomeIcons.xTwitter,
      iconColor: Colors.white,
      chatwootKinds: {'twitter'},
    ),
  ];

  static ({List<LinkedChannel> linked, List<ChannelOption> unlinked}) partition(
    List<ChatwootInbox> inboxes,
  ) {
    final linked = <LinkedChannel>[];
    final unlinked = <ChannelOption>[];

    for (final channel in all) {
      final matches =
          inboxes.where((i) => channel.matchesInbox(i)).toList();
      if (matches.isNotEmpty) {
        linked.add(LinkedChannel(channel: channel, inboxes: matches));
      } else {
        unlinked.add(channel);
      }
    }

    return (linked: linked, unlinked: unlinked);
  }
}
