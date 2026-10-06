import 'package:autobus/common_design/light_screen_theme.dart';
import 'package:autobus/common_design/widgets/app_bottom_nav.dart';
import 'package:autobus/common_design/widgets/light_screen_scaffold.dart';
import 'package:autobus/features/home/models/owner_resource.dart';
import 'package:autobus/features/home/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class ResourcesPage extends StatefulWidget {
  const ResourcesPage({super.key});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> {
  Future<OwnerFeed>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= context.read<ApiService>().getOwnerResourceFeed();
  }

  Future<void> _reload() async {
    final next = context.read<ApiService>().getOwnerResourceFeed();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;

    return LightScreenScaffold(
      title: 'Resources',
      body: FutureBuilder<OwnerFeed>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return _Message(
              scale: scale,
              text: 'Resources could not be loaded.',
              action: 'Try again',
              onTap: _reload,
            );
          }
          final feed = snap.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20 * scale, 16 * scale, 20 * scale, 32 * scale),
              children: [
                if (feed.industry.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16 * scale),
                    child: Text(
                      'Picked for ${feed.industry}',
                      style: GoogleFonts.poppins(
                        color: LightScreenTheme.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (feed.videos.isNotEmpty) ...[
                  _SectionTitle(title: 'Videos for your business'),
                  SizedBox(height: 10 * scale),
                  ...feed.videos.map(
                    (item) => _ResourceCard(
                      item: item,
                      scale: scale,
                      onTap: () => _openExternal(item.watchUrl),
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                ],
                _SectionTitle(title: 'Trending news'),
                SizedBox(height: 10 * scale),
                if (feed.news.isEmpty)
                  _EmptyLine(text: 'No headlines for this niche yet.')
                else
                  ...feed.news.map(
                    (item) => _ResourceCard(
                      item: item,
                      scale: scale,
                      onTap: () => _openExternal(item.url),
                    ),
                  ),
                SizedBox(height: 8 * scale),
                _SectionTitle(title: 'App resources'),
                SizedBox(height: 4 * scale),
                Text(
                  'Guides and checklists for running Autobus.',
                  style: GoogleFonts.poppins(color: LightScreenTheme.muted, fontSize: 12),
                ),
                SizedBox(height: 10 * scale),
                if (feed.guides.isEmpty && feed.others.isEmpty)
                  _EmptyLine(text: 'Guides will show up here once they are published.')
                else ...[
                  ...feed.guides.map((item) => _guideCard(context, item, scale)),
                  ...feed.others.map((item) => _guideCard(context, item, scale)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _guideCard(BuildContext context, OwnerResource item, double scale) {
    return _ResourceCard(
      item: item,
      scale: scale,
      onTap: () {
        if (item.body.trim().isEmpty && item.url.startsWith('http')) {
          _openExternal(item.url);
          return;
        }
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(builder: (_) => ResourceGuidePage(item: item)),
        );
      },
    );
  }

  Future<void> _openExternal(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class ResourceGuidePage extends StatelessWidget {
  final OwnerResource item;

  const ResourceGuidePage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / appShellDesignWidth;
    return LightScreenScaffold(
      title: 'Guide',
      body: ListView(
        padding: EdgeInsets.fromLTRB(20 * scale, 16 * scale, 20 * scale, 32 * scale),
        children: [
          Text(
            item.title,
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          if (item.sourceName.isNotEmpty) ...[
            SizedBox(height: 6 * scale),
            Text(
              item.sourceName,
              style: GoogleFonts.poppins(color: LightScreenTheme.muted, fontSize: 12),
            ),
          ],
          SizedBox(height: 16 * scale),
          Text(
            item.body.trim().isEmpty ? item.summary : item.body,
            style: GoogleFonts.poppins(
              color: const Color(0xFF1E293B),
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final OwnerResource item;
  final double scale;
  final VoidCallback onTap;

  const _ResourceCard({
    required this.item,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showThumb = item.thumbnailUrl.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: 12 * scale),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showThumb)
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16 * scale)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          item.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFE2E8F0)),
                        ),
                        if (item.isVideo)
                          const Center(
                            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 42),
                          ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(14 * scale, 12 * scale, 14 * scale, 14 * scale),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    if (item.summary.isNotEmpty) ...[
                      SizedBox(height: 4 * scale),
                      Text(
                        item.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: LightScreenTheme.body,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (item.sourceName.isNotEmpty) ...[
                      SizedBox(height: 6 * scale),
                      Text(
                        item.sourceName,
                        style: GoogleFonts.poppins(
                          color: LightScreenTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;

  const _EmptyLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.poppins(color: LightScreenTheme.muted, fontSize: 13),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final double scale;
  final String text;
  final String action;
  final VoidCallback onTap;

  const _Message({
    required this.scale,
    required this.text,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14)),
            TextButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
