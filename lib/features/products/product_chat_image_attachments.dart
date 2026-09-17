import 'dart:io';
import 'dart:typed_data';

import 'package:autobus/common_design/device_media_picker.dart';
import 'package:autobus/features/home/services/api_service.dart';
import 'package:autobus/features/products/product_media.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Staged image or video for products chat / add-product forms.
class ProductStagingSlot {
  String? localPath;
  Uint8List? previewBytes;
  String? pickedName;
  bool isVideo;

  ProductStagingSlot({this.isVideo = false});

  bool get isEmpty =>
      (previewBytes == null || previewBytes!.isEmpty) &&
      (localPath == null || localPath!.trim().isEmpty);

  bool get looksLikeVideo =>
      isVideo ||
      productFileLooksLikeVideo(pickedName) ||
      productFileLooksLikeVideo(localPath);

  void clear() {
    localPath = null;
    previewBytes = null;
    pickedName = null;
    isVideo = false;
  }
}

/// Uploads non-empty [slots] to `product-images` storage; preserves order.
Future<List<String>> uploadStagedProductImageUrls(
  ApiService api,
  List<ProductStagingSlot> slots,
) async {
  final uploaded = await uploadStagedProductMedia(api, slots);
  return [...uploaded.photos, ...uploaded.videos];
}

class StagedProductMediaUrls {
  final List<String> photos;
  final List<String> videos;

  const StagedProductMediaUrls({
    required this.photos,
    required this.videos,
  });

  List<String> get all => [...photos, ...videos];
  bool get isEmpty => photos.isEmpty && videos.isEmpty;
}

/// Uploads staged images and videos, keeping them in separate lists.
Future<StagedProductMediaUrls> uploadStagedProductMedia(
  ApiService api,
  List<ProductStagingSlot> slots,
) async {
  final photos = <String>[];
  final videos = <String>[];
  for (final slot in slots) {
    if (slot.isEmpty) continue;
    String? url;
    if (kIsWeb) {
      final bytes = slot.previewBytes;
      if (bytes == null || bytes.isEmpty) continue;
      url = await api.uploadFileBytes(
        fileBytes: bytes,
        filename: slot.pickedName ??
            (slot.looksLikeVideo ? 'product.mp4' : 'product.jpg'),
        storageFolder: ApiService.productImageStorageFolder,
      );
    } else {
      final path = slot.localPath;
      if (path == null || path.isEmpty) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      url = await api.uploadFile(
        file: file,
        filename: slot.pickedName,
        storageFolder: ApiService.productImageStorageFolder,
      );
    }
    if (url.isEmpty) continue;
    if (slot.looksLikeVideo || productMediaLooksLikeVideo(url)) {
      videos.add(url);
    } else {
      photos.add(url);
    }
  }
  return StagedProductMediaUrls(photos: photos, videos: videos);
}

/// Horizontal image slots for the products AutoBus chat (light background).
class ProductChatImageStrip extends StatelessWidget {
  static const double thumbW = 88;
  static const double thumbH = 102;

  final List<ProductStagingSlot> slots;
  final ValueChanged<int> onSlotTap;
  final VoidCallback onAddSlot;
  final bool busy;
  final int maxSlots;

  const ProductChatImageStrip({
    super.key,
    required this.slots,
    required this.onSlotTap,
    required this.onAddSlot,
    this.busy = false,
    this.maxSlots = 8,
  });

  bool get _hasEmptySlot => slots.any((s) => s.isEmpty);

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF2A1447);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product photos',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: purple.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap to add one or more images. They upload when you send your message.',
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: purple.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: thumbH + 4,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < slots.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _Thumb(
                  slot: slots[i],
                  width: thumbW,
                  height: thumbH,
                  onTap: busy ? null : () => onSlotTap(i),
                ),
              ],
              if (!_hasEmptySlot && slots.length < maxSlots) ...[
                const SizedBox(width: 8),
                _AddThumb(
                  width: thumbW,
                  height: thumbH,
                  onTap: busy ? null : onAddSlot,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  final ProductStagingSlot slot;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const _Thumb({
    required this.slot,
    required this.width,
    required this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF2A1447);
    final empty = slot.isEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: purple.withValues(alpha: 0.22)),
        ),
        clipBehavior: Clip.antiAlias,
        child: empty
            ? Icon(
                Icons.add_photo_alternate_outlined,
                color: purple.withValues(alpha: 0.45),
                size: 30,
              )
            : _preview(),
      ),
    );
  }

  Widget _preview() {
    final bytes = slot.previewBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    }
    final path = slot.localPath;
    if (!kIsWeb && path != null && path.isNotEmpty && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover, gaplessPlayback: true);
    }
    return Icon(Icons.broken_image_outlined, color: Colors.black26, size: 28);
  }
}

class _AddThumb extends StatelessWidget {
  final double width;
  final double height;
  final VoidCallback? onTap;

  const _AddThumb({
    required this.width,
    required this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF2A1447);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: purple.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: purple.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 28, color: purple.withValues(alpha: 0.75)),
            const SizedBox(height: 4),
            Text(
              'Add',
              style: GoogleFonts.montserrat(fontSize: 9, color: purple.withValues(alpha: 0.65)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pick an image into [slots[index]]; shows snackbars on failure.
Future<void> pickProductImageForSlot(
  BuildContext context,
  List<ProductStagingSlot> slots,
  int index,
  StateSetter setState,
) async {
  final picked = await pickDeviceImages(context, maxCount: 1);
  if (!context.mounted || picked.isEmpty) return;

  final file = picked.first;
  final path = file.path?.trim();
  final name = file.name.trim().isNotEmpty ? file.name : 'image.jpg';

  if (kIsWeb) {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load selected image.')),
      );
      return;
    }
    setState(() {
      slots[index]
        ..previewBytes = bytes
        ..localPath = null
        ..pickedName = name
        ..isVideo = false;
    });
    return;
  }

  if (path == null || path.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open selected image.')),
    );
    return;
  }

  Uint8List? bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    try {
      bytes = await File(path).readAsBytes();
    } catch (_) {
      bytes = null;
    }
  }

  setState(() {
    slots[index]
      ..localPath = path
      ..previewBytes = (bytes != null && bytes.isNotEmpty) ? bytes : null
      ..pickedName = name
      ..isVideo = false;
  });
}

/// Replace [slots[index]] with a picked video.
Future<void> pickProductVideoForSlot(
  BuildContext context,
  List<ProductStagingSlot> slots,
  int index,
  StateSetter setState,
) async {
  final picked = await pickDeviceVideos(context, maxCount: 1);
  if (!context.mounted || picked.isEmpty) return;

  final file = picked.first;
  final path = file.path?.trim();
  final name = file.name.trim().isNotEmpty ? file.name : 'product.mp4';

  if (kIsWeb) {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load selected video.')),
      );
      return;
    }
    setState(() {
      slots[index]
        ..previewBytes = bytes
        ..localPath = null
        ..pickedName = name
        ..isVideo = true;
    });
    return;
  }

  if (path == null || path.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open selected video.')),
    );
    return;
  }

  setState(() {
    slots[index]
      ..localPath = path
      ..previewBytes = null
      ..pickedName = name
      ..isVideo = true;
  });
}

Future<void> showProductSlotActionsSheet(
  BuildContext context,
  VoidCallback onReplace,
  VoidCallback onRemove,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF1E0A32),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.white70),
            title: Text('Replace', style: GoogleFonts.montserrat(color: Colors.white)),
            onTap: () => Navigator.pop(ctx, 'replace'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: Text('Remove', style: GoogleFonts.montserrat(color: Colors.redAccent)),
            onTap: () => Navigator.pop(ctx, 'remove'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (action == 'replace') onReplace();
  if (action == 'remove') onRemove();
}
