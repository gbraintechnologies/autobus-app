import 'package:autobus/barrel.dart';
import 'package:autobus/features/home/models/owner_resource.dart';
import 'package:autobus/features/home/resources_page.dart';
import 'package:url_launcher/url_launcher.dart';

/// Home strip under “Here’s what’s happening”.
/// Two niche videos, swipe left for the next, then View more opens Resources.
class HomeNeedsFeed extends StatefulWidget {
  final double scale;

  const HomeNeedsFeed({super.key, required this.scale});

  @override
  State<HomeNeedsFeed> createState() => _HomeNeedsFeedState();
}

class _HomeNeedsFeedState extends State<HomeNeedsFeed> {
  static const _surface = Color(0xFFF8FAFC);
  static const _accent = Color(0xFF7F03B9);

  Future<OwnerFeed>? _future;
  PageController? _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= context.read<ApiService>().getOwnerResourceFeed();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _openResources() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const ResourcesPage()),
    );
  }

  Future<void> _openVideo(OwnerResource item) async {
    final uri = Uri.tryParse(item.watchUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _openResources,
            style: TextButton.styleFrom(
              foregroundColor: _accent,
              padding: EdgeInsets.symmetric(horizontal: 4 * scale),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'View more',
              style: GoogleFonts.poppins(
                color: _accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SizedBox(height: 4 * scale),
        FutureBuilder<OwnerFeed>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return _placeholder(scale);
            }
            final videos = (snap.data?.videos ?? const <OwnerResource>[]).take(2).toList();
            if (videos.isEmpty) {
              return _empty(scale);
            }
            final imageHeight = 168 * scale;
            final card = (OwnerResource item) => _VideoCard(
              item: item,
              scale: scale,
              imageHeight: imageHeight,
              onTap: () => _openVideo(item),
            );
            return Column(
              children: [
                SizedBox(
                  height: imageHeight + 72 * scale,
                  child: videos.length == 1
                      ? card(videos.first)
                      : PageView.builder(
                          controller: _pageController,
                          padEnds: false,
                          itemCount: videos.length,
                          onPageChanged: (index) => setState(() => _page = index),
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: EdgeInsets.only(right: 12 * scale),
                              child: card(videos[index]),
                            );
                          },
                        ),
                ),
                if (videos.length > 1) ...[
                  SizedBox(height: 8 * scale),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(videos.length, (index) {
                      final active = index == _page;
                      return Container(
                        width: active ? 16 * scale : 6 * scale,
                        height: 6 * scale,
                        margin: EdgeInsets.symmetric(horizontal: 3 * scale),
                        decoration: BoxDecoration(
                          color: active ? _accent : const Color(0xFFD6D3D1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _placeholder(double scale) {
    return Container(
      height: 179 * scale,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20 * scale),
      ),
    );
  }

  Widget _empty(double scale) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(20 * scale),
      child: InkWell(
        onTap: _openResources,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        borderRadius: BorderRadius.circular(20 * scale),
        child: SizedBox(
          height: 120 * scale,
          child: Center(
            child: Text(
              'Videos for your business will show up here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final OwnerResource item;
  final double scale;
  final double imageHeight;
  final VoidCallback onTap;

  const _VideoCard({
    required this.item,
    required this.scale,
    required this.imageHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(20 * scale),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: imageHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.thumbnailUrl.isNotEmpty)
                    Image.network(
                      item.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFE2E8F0)),
                    )
                  else
                    const ColoredBox(color: Color(0xFFE2E8F0)),
                  const Center(
                    child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12 * scale, 8 * scale, 12 * scale, 8 * scale),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.sourceName.isNotEmpty)
                      Text(
                        item.sourceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
