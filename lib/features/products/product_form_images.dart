import 'dart:io';
import 'dart:typed_data';

import 'package:autobus/common_design/device_media_picker.dart';
import 'package:autobus/features/products/product_chat_image_attachments.dart';
import 'package:autobus/features/products/product_media.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Image / video gallery section for product create/edit forms (dark theme).
class ProductFormImageSection extends StatelessWidget {
  static const double thumbSize = 96;
  static const int maxImages = 12;
  static const int maxVideos = kMaxProductVideos;

  final List<ProductStagingSlot> slots;
  final ValueChanged<int> onSlotTap;
  final VoidCallback onAddImages;
  final VoidCallback? onAddVideos;
  final VoidCallback? onRemoveSlot;
  final bool busy;

  const ProductFormImageSection({
    super.key,
    required this.slots,
    required this.onSlotTap,
    required this.onAddImages,
    this.onAddVideos,
    this.onRemoveSlot,
    this.busy = false,
  });

  int get _filledCount => slots.where((s) => !s.isEmpty).length;
  int get _imageCount =>
      slots.where((s) => !s.isEmpty && !s.looksLikeVideo).length;
  int get _videoCount =>
      slots.where((s) => !s.isEmpty && s.looksLikeVideo).length;

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
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (_filledCount > 0)
              Text(
                [
                  if (_imageCount > 0) '$_imageCount photo${_imageCount == 1 ? '' : 's'}',
                  if (_videoCount > 0) '$_videoCount video${_videoCount == 1 ? '' : 's'}',
                ].join(' · '),
                style: GoogleFonts.poppins(
                  color: const Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Add photos, video, or both. You can post with video only. The first photo is the cover when present.',
          style: GoogleFonts.poppins(
            color: const Color(0xFF4D4D4D),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: thumbSize + 8,
          child: Builder(
            builder: (context) {
              final filledIndexes = [
                for (var i = 0; i < slots.length; i++)
                  if (!slots[i].isEmpty) i,
              ];
              return ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var j = 0; j < filledIndexes.length; j++) ...[
                    if (j > 0) const SizedBox(width: 10),
                    _FormThumb(
                      slot: slots[filledIndexes[j]],
                      index: filledIndexes[j],
                      isCover: j == 0,
                      busy: busy,
                      onTap: () => onSlotTap(filledIndexes[j]),
                    ),
                  ],
                  if (_imageCount < maxImages) ...[
                    if (filledIndexes.isNotEmpty) const SizedBox(width: 10),
                    _AddPhotosButton(
                      busy: busy,
                      onTap: onAddImages,
                      showPlusOnly: filledIndexes.isNotEmpty && onAddVideos == null,
                    ),
                  ],
                  if (onAddVideos != null && _videoCount < maxVideos) ...[
                    const SizedBox(width: 10),
                    _AddVideosButton(busy: busy, onTap: onAddVideos!),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FormThumb extends StatelessWidget {
  final ProductStagingSlot slot;
  final int index;
  final bool isCover;
  final bool busy;
  final VoidCallback onTap;

  const _FormThumb({
    required this.slot,
    required this.index,
    required this.isCover,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final empty = slot.isEmpty;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: ProductFormImageSection.thumbSize,
            height: ProductFormImageSection.thumbSize,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCover
                    ? const Color(0xFFA855F7)
                    : const Color(0xFFE2E8F0),
                width: isCover ? 1.6 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: empty
                ? const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: Color(0xFF94A3B8),
                    size: 28,
                  )
                : _preview(),
          ),
          if (slot.looksLikeVideo)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          if (isCover)
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

  Widget _preview() {
    if (slot.looksLikeVideo) {
      return const ColoredBox(
        color: Color(0xFFF1F5F9),
        child: Center(
          child: Icon(
            Icons.videocam_outlined,
            color: Color(0xFF64748B),
            size: 32,
          ),
        ),
      );
    }
    final bytes = slot.previewBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    }
    final path = slot.localPath;
    if (!kIsWeb && path != null && path.isNotEmpty && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover, gaplessPlayback: true);
    }
    return const Icon(
      Icons.broken_image_outlined,
      color: Color(0xFF94A3B8),
      size: 28,
    );
  }
}

class _AddPhotosButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;
  final bool showPlusOnly;

  const _AddPhotosButton({
    required this.busy,
    required this.onTap,
    this.showPlusOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: ProductFormImageSection.thumbSize,
        height: ProductFormImageSection.thumbSize,
        decoration: BoxDecoration(
          color: const Color(0xFFA855F7).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFA855F7).withValues(alpha: 0.55),
          ),
        ),
        child: showPlusOnly
            ? Icon(
                Icons.add,
                color: const Color(0xFFA855F7).withValues(alpha: 0.9),
                size: 32,
              )
            : Column(
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
        width: ProductFormImageSection.thumbSize,
        height: ProductFormImageSection.thumbSize,
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

/// Pick multiple images and append them to [slots] (up to [maxSlots]).
Future<void> pickMultipleProductImages(
  BuildContext context,
  List<ProductStagingSlot> slots,
  StateSetter setState, {
  int maxSlots = ProductFormImageSection.maxImages,
}) async {
  final remaining =
      maxSlots - slots.where((s) => !s.isEmpty && !s.looksLikeVideo).length;
  if (remaining <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You can add up to $maxSlots images.')),
    );
    return;
  }

  final picked = await pickDeviceImages(context, maxCount: remaining);
  if (!context.mounted || picked.isEmpty) return;

  final newSlots = <ProductStagingSlot>[];

  for (final file in picked) {
    final name = file.name.trim().isNotEmpty ? file.name : 'image.jpg';
    final slot = ProductStagingSlot(isVideo: false)..pickedName = name;

    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      slot.previewBytes = bytes;
    } else {
      final path = file.path?.trim();
      if (path == null || path.isEmpty) continue;
      slot.localPath = path;
      Uint8List? bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        try {
          bytes = await File(path).readAsBytes();
        } catch (_) {
          bytes = null;
        }
      }
      if (bytes != null && bytes.isNotEmpty) {
        slot.previewBytes = bytes;
      }
    }
    newSlots.add(slot);
  }

  if (newSlots.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to load selected images.')),
    );
    return;
  }

  setState(() {
    slots.removeWhere((s) => s.isEmpty);
    slots.addAll(newSlots);
  });
}

/// Pick videos and append them to [slots] (up to [maxSlots]).
Future<void> pickMultipleProductVideos(
  BuildContext context,
  List<ProductStagingSlot> slots,
  StateSetter setState, {
  int maxSlots = ProductFormImageSection.maxVideos,
}) async {
  final remaining =
      maxSlots - slots.where((s) => !s.isEmpty && s.looksLikeVideo).length;
  if (remaining <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You can add up to $maxSlots videos.')),
    );
    return;
  }

  final picked = await pickDeviceVideos(context, maxCount: remaining);
  if (!context.mounted || picked.isEmpty) return;

  final newSlots = <ProductStagingSlot>[];

  for (final file in picked) {
    final name = file.name.trim().isNotEmpty ? file.name : 'product.mp4';
    final slot = ProductStagingSlot(isVideo: true)..pickedName = name;

    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      slot.previewBytes = bytes;
    } else {
      final path = file.path?.trim();
      if (path == null || path.isEmpty) continue;
      slot.localPath = path;
    }
    newSlots.add(slot);
  }

  if (newSlots.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to load selected videos.')),
    );
    return;
  }

  setState(() {
    slots.removeWhere((s) => s.isEmpty);
    slots.addAll(newSlots);
  });
}

void removeProductStagingSlot(
  List<ProductStagingSlot> slots,
  int index,
  StateSetter setState,
) {
  setState(() {
    if (index < 0 || index >= slots.length) return;
    slots.removeAt(index);
    slots.removeWhere((s) => s.isEmpty);
  });
}
