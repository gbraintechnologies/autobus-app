import 'dart:io';

import 'package:autobus/features/home/services/api_service.dart';
import 'package:autobus/features/products/product_form_images.dart';
import 'package:autobus/features/products/product_media.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductGalleryPhoto {
  final String imageId;
  final String url;
  final bool isPrimary;
  final bool isVideo;

  const ProductGalleryPhoto({
    required this.imageId,
    required this.url,
    required this.isPrimary,
    this.isVideo = false,
  });

  factory ProductGalleryPhoto.fromJson(Map<String, dynamic> json) {
    final url = (json['url'] ?? json['image_url'] ?? json['file_url'] ?? '')
        .toString();
    final mediaType = (json['media_type'] ?? '').toString().toLowerCase();
    return ProductGalleryPhoto(
      imageId: (json['image_id'] ?? '').toString(),
      url: url,
      isPrimary: json['is_primary'] == true,
      isVideo: mediaType == 'video' || productMediaLooksLikeVideo(url),
    );
  }
}

Widget _remoteProductImage(
  String url, {
  required BoxFit fit,
  double? width,
  double? height,
}) {
  return Image.network(
    url,
    fit: fit,
    width: width,
    height: height,
    gaplessPlayback: true,
    filterQuality: FilterQuality.medium,
    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
      return Container(
        color: const Color(0xFF1E0A32),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFA855F7),
          ),
        ),
      );
    },
    errorBuilder: (_, __, ___) => Container(
      color: const Color(0xFF1E0A32),
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: Colors.white.withValues(alpha: 0.35),
      ),
    ),
  );
}

/// Manage uploaded product photos on the edit screen.
class ProductExistingGallery extends StatelessWidget {
  static const double thumbSize = 96;

  final List<ProductGalleryPhoto> photos;
  final bool busy;
  final VoidCallback onAddPhotos;
  final VoidCallback? onAddVideos;
  final ValueChanged<ProductGalleryPhoto> onPhotoTap;

  const ProductExistingGallery({
    super.key,
    required this.photos,
    required this.busy,
    required this.onAddPhotos,
    this.onAddVideos,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Product media',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (photos.isNotEmpty)
              Text(
                '${photos.length} item${photos.length == 1 ? '' : 's'}',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Tap media to view it. Set a cover or remove it from the viewer.',
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: thumbSize + 8,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final photo in photos) ...[
                if (photo != photos.first) const SizedBox(width: 10),
                _ExistingThumb(
                  photo: photo,
                  busy: busy,
                  onTap: () => onPhotoTap(photo),
                ),
              ],
              const SizedBox(width: 10),
              _AddPhotosButton(busy: busy, onTap: onAddPhotos),
              if (onAddVideos != null) ...[
                const SizedBox(width: 10),
                _AddVideosButton(busy: busy, onTap: onAddVideos!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ExistingThumb extends StatelessWidget {
  final ProductGalleryPhoto photo;
  final bool busy;
  final VoidCallback onTap;

  const _ExistingThumb({
    required this.photo,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: ProductExistingGallery.thumbSize,
            height: ProductExistingGallery.thumbSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: photo.isPrimary
                    ? const Color(0xFFA855F7)
                    : const Color(0xFF3F1163).withValues(alpha: 0.85),
                width: photo.isPrimary ? 1.6 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: photo.isVideo
                ? const ColoredBox(
                    color: Color(0xFF1E0A32),
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  )
                : _remoteProductImage(photo.url, fit: BoxFit.cover),
          ),
          if (photo.isPrimary)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFA855F7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Cover',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddPhotosButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;

  const _AddPhotosButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: ProductExistingGallery.thumbSize,
        height: ProductExistingGallery.thumbSize,
        decoration: BoxDecoration(
          color: const Color(0xFFA855F7).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFA855F7).withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              color: const Color(0xFFA855F7).withValues(alpha: 0.9),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              'Add photos',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFFA855F7).withValues(alpha: 0.85),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddVideosButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;

  const _AddVideosButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: ProductExistingGallery.thumbSize,
        height: ProductExistingGallery.thumbSize,
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF22C55E).withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_outlined,
              color: const Color(0xFF22C55E).withValues(alpha: 0.95),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              'Add video',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF22C55E).withValues(alpha: 0.9),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> showProductPhotoActionsSheet(
  BuildContext context,
  ProductGalleryPhoto photo, {
  required bool canDelete,
}) {
  return showProductPhotoViewer(context, photo, canDelete: canDelete);
}

Future<String?> showProductPhotoViewer(
  BuildContext context,
  ProductGalleryPhoto photo, {
  required bool canDelete,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close media',
    barrierColor: Colors.black.withValues(alpha: 0.94),
    pageBuilder: (ctx, _, __) {
      final size = MediaQuery.sizeOf(ctx);
      return Material(
        color: Colors.transparent,
        child: SafeArea(
          child: SizedBox.expand(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      const Spacer(),
                      if (!photo.isPrimary)
                        TextButton.icon(
                          onPressed: () => Navigator.pop(ctx, 'primary'),
                          icon: const Icon(
                            Icons.star_outline,
                            color: Colors.white70,
                            size: 18,
                          ),
                          label: Text(
                            'Set as cover',
                            style: GoogleFonts.outfit(color: Colors.white),
                          ),
                        ),
                      if (canDelete)
                        TextButton.icon(
                          onPressed: () => Navigator.pop(ctx, 'delete'),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          label: Text(
                            'Remove',
                            style: GoogleFonts.outfit(color: Colors.redAccent),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: photo.isVideo
                      ? _NetworkVideoPreview(url: photo.url)
                      : InteractiveViewer(
                          minScale: 0.6,
                          maxScale: 4,
                          child: Center(
                            child: _remoteProductImage(
                              photo.url,
                              fit: BoxFit.contain,
                              width: size.width,
                              height: size.height * 0.78,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Pick and upload multiple photos for an existing product.
Future<void> pickAndUploadProductPhotos({
  required BuildContext context,
  required ApiService api,
  required String productId,
  int maxImages = ProductFormImageSection.maxImages,
  required int currentCount,
}) async {
  final remaining = maxImages - currentCount;
  if (remaining <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You can add up to $maxImages images.')),
    );
    return;
  }

  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],
    allowMultiple: true,
    withData: kIsWeb,
  );
  if (!context.mounted || result == null || result.files.isEmpty) return;

  final picked = result.files.take(remaining).toList();
  if (kIsWeb) {
    final bytesList = <({List<int> bytes, String filename})>[];
    for (final file in picked) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final name = file.name.trim().isNotEmpty ? file.name : 'image.jpg';
      bytesList.add((bytes: bytes, filename: name));
    }
    if (bytesList.isEmpty) {
      throw Exception('Unable to load selected images');
    }
    await api.uploadProductPhotos(productId, fileBytes: bytesList);
    return;
  }

  final files = <File>[];
  for (final file in picked) {
    final path = file.path?.trim();
    if (path == null || path.isEmpty) continue;
    final f = File(path);
    if (await f.exists()) files.add(f);
  }
  if (files.isEmpty) {
    throw Exception('Unable to open selected images');
  }
  await api.uploadProductPhotos(productId, files: files);
}

/// Pick and upload videos for an existing product.
Future<void> pickAndUploadProductVideos({
  required BuildContext context,
  required ApiService api,
  required String productId,
  int maxVideos = ProductFormImageSection.maxVideos,
  required int currentVideoCount,
}) async {
  final remaining = maxVideos - currentVideoCount;
  if (remaining <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You can add up to $maxVideos videos.')),
    );
    return;
  }

  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: kProductVideoExtensions,
    allowMultiple: true,
    withData: kIsWeb,
  );
  if (!context.mounted || result == null || result.files.isEmpty) return;

  final picked = result.files.take(remaining).toList();
  if (kIsWeb) {
    final bytesList = <({List<int> bytes, String filename})>[];
    for (final file in picked) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final name = file.name.trim().isNotEmpty ? file.name : 'product.mp4';
      bytesList.add((bytes: bytes, filename: name));
    }
    if (bytesList.isEmpty) {
      throw Exception('Unable to load selected videos');
    }
    await api.uploadProductPhotos(productId, fileBytes: bytesList);
    return;
  }

  final files = <File>[];
  for (final file in picked) {
    final path = file.path?.trim();
    if (path == null || path.isEmpty) continue;
    final f = File(path);
    if (await f.exists()) files.add(f);
  }
  if (files.isEmpty) {
    throw Exception('Unable to open selected videos');
  }
  await api.uploadProductPhotos(productId, files: files);
}

class _NetworkVideoPreview extends StatefulWidget {
  final String url;

  const _NetworkVideoPreview({required this.url});

  @override
  State<_NetworkVideoPreview> createState() => _NetworkVideoPreviewState();
}

class _NetworkVideoPreviewState extends State<_NetworkVideoPreview> {
  late final VideoPlayerController _controller;
  var _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.setLooping(true);
        _controller.play();
      }).catchError((Object e) {
        if (!mounted) return;
        setState(() => _error = e.toString());
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Icon(
          Icons.videocam_off_outlined,
          color: Colors.white.withValues(alpha: 0.5),
          size: 48,
        ),
      );
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFA855F7)));
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_controller.value.isPlaying) {
            _controller.pause();
          } else {
            _controller.play();
          }
        });
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio == 0
              ? 16 / 9
              : _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}
