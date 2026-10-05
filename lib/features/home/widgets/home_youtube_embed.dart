import 'package:autobus/barrel.dart';
import 'package:autobus/icons/figma_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Home banner — Figma `3404:6116` (361×179, radius 20).
class HomeYoutubeEmbed extends StatelessWidget {
  final double scale;

  const HomeYoutubeEmbed({super.key, required this.scale});

  static String? videoIdFrom(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (RegExp(r'^[\w-]{11}$').hasMatch(value)) return value;

    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    if (uri.host.contains('youtu.be')) {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      return id.length == 11 ? id : null;
    }

    final queryId = uri.queryParameters['v'];
    if (queryId != null && queryId.length == 11) return queryId;

    for (final marker in ['embed', 'shorts', 'live']) {
      final index = uri.pathSegments.indexOf(marker);
      if (index >= 0 && index + 1 < uri.pathSegments.length) {
        final id = uri.pathSegments[index + 1];
        if (id.length == 11) return id;
      }
    }
    return null;
  }

  Future<void> _openExternal() async {
    final raw = AppConfig.homeYoutubeUrl.trim();
    final id = videoIdFrom(raw);
    final uri = Uri.tryParse(
      raw.startsWith('http')
          ? raw
          : 'https://www.youtube.com/watch?v=$id',
    );
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final height = 179 * scale;
    final radius = BorderRadius.circular(20 * scale);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Material(
          color: const Color(0xFFF8FAFC),
          child: InkWell(
            onTap: _openExternal,
            child: Image.asset(
              FigmaImages.homeBanner,
              fit: BoxFit.cover,
              width: double.infinity,
              height: height,
            ),
          ),
        ),
      ),
    );
  }
}
