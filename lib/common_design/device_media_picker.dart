import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// One photo or video chosen from the camera, photo library, or (web/desktop) files.
class DevicePickedMedia {
  final String name;
  final String? path;
  final Uint8List? bytes;
  final bool isVideo;

  const DevicePickedMedia({
    required this.name,
    this.path,
    this.bytes,
    this.isVideo = false,
  });
}

bool get _useNativePhotoPicker {
  if (kIsWeb) return false;
  return Platform.isIOS || Platform.isAndroid;
}

String _mediaExtension(String nameOrPath, {required String fallback}) {
  final dot = nameOrPath.lastIndexOf('.');
  if (dot <= 0 || dot == nameOrPath.length - 1) return fallback;
  final ext = nameOrPath.substring(dot).toLowerCase();
  if (ext.length > 5) return fallback;
  return ext;
}

Future<String?> _stabilizeLocalPath(
  XFile file, {
  required String fallbackExt,
}) async {
  final path = file.path.trim();
  if (path.isNotEmpty) {
    final local = File(path);
    for (var i = 0; i < 32; i++) {
      try {
        if (await local.exists() && await local.length() > 0) return path;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }
  try {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return path.isEmpty ? null : path;
    final ext = _mediaExtension(file.name, fallback: fallbackExt);
    final dest = File(
      '${Directory.systemTemp.path}/autobus_media_'
      '${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await dest.writeAsBytes(bytes, flush: true);
    if (await dest.exists() && await dest.length() > 0) return dest.path;
  } catch (_) {}
  return path.isEmpty ? null : path;
}

Future<DevicePickedMedia?> _fromXFile(
  XFile file, {
  required bool isVideo,
  required String fallbackExt,
}) async {
  Uint8List? bytes;
  if (!isVideo || kIsWeb) {
    try {
      bytes = await file.readAsBytes();
      if (bytes.isEmpty) bytes = null;
    } catch (_) {
      bytes = null;
    }
  }
  final path = kIsWeb
      ? null
      : await _stabilizeLocalPath(file, fallbackExt: fallbackExt);
  final name = file.name.trim().isNotEmpty
      ? file.name
      : (isVideo ? 'video$fallbackExt' : 'image$fallbackExt');
  if ((bytes == null || bytes.isEmpty) && (path == null || path.isEmpty)) {
    return null;
  }
  return DevicePickedMedia(
    name: name,
    path: path,
    bytes: bytes,
    isVideo: isVideo,
  );
}

Future<ImageSource?> _chooseCaptureOrLibrary(
  BuildContext context, {
  required bool isVideo,
}) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              isVideo ? Icons.videocam_outlined : Icons.photo_camera_outlined,
            ),
            title: Text(isVideo ? 'Record video' : 'Take photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Icon(
              isVideo
                  ? Icons.video_library_outlined
                  : Icons.photo_library_outlined,
            ),
            title: Text(
              isVideo
                  ? 'Choose video from gallery'
                  : 'Choose photo from gallery',
            ),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

Future<({bool isPicture, ImageSource source})?> choosePhotoOrVideoSource(
  BuildContext context,
) {
  return showModalBottomSheet<({bool isPicture, ImageSource source})>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(context, (
              isPicture: true,
              source: ImageSource.camera,
            )),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose photo from gallery'),
            onTap: () => Navigator.pop(context, (
              isPicture: true,
              source: ImageSource.gallery,
            )),
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: const Text('Record video'),
            onTap: () => Navigator.pop(context, (
              isPicture: false,
              source: ImageSource.camera,
            )),
          ),
          ListTile(
            leading: const Icon(Icons.video_library_outlined),
            title: const Text('Choose video from gallery'),
            onTap: () => Navigator.pop(context, (
              isPicture: false,
              source: ImageSource.gallery,
            )),
          ),
        ],
      ),
    ),
  );
}

Future<List<DevicePickedMedia>> _pickWithFilePicker({
  required bool isVideo,
  required bool allowMultiple,
  required List<String> allowedExtensions,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    allowMultiple: allowMultiple,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return const [];
  final out = <DevicePickedMedia>[];
  for (final file in result.files) {
    final name = file.name.trim().isNotEmpty
        ? file.name
        : (isVideo ? 'video.mp4' : 'image.jpg');
    final path = file.path?.trim();
    final bytes = file.bytes;
    if ((bytes == null || bytes.isEmpty) &&
        (path == null || path.isEmpty)) {
      continue;
    }
    out.add(
      DevicePickedMedia(
        name: name,
        path: path,
        bytes: bytes,
        isVideo: isVideo,
      ),
    );
  }
  return out;
}

/// Pick photos. On iOS/Android this asks camera vs gallery first, then uses
/// the system Photos picker (not the empty Files “Recents” sheet).
Future<List<DevicePickedMedia>> pickDeviceImages(
  BuildContext context, {
  int maxCount = 12,
  ImageSource? source,
}) async {
  final remaining = maxCount < 1 ? 1 : maxCount;
  if (!_useNativePhotoPicker) {
    return _pickWithFilePicker(
      isVideo: false,
      allowMultiple: remaining > 1,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],
    );
  }

  final chosen =
      source ??
      await _chooseCaptureOrLibrary(context, isVideo: false);
  if (chosen == null) return const [];
  if (!context.mounted) return const [];

  final picker = ImagePicker();
  try {
    if (chosen == ImageSource.gallery && remaining > 1) {
      final files = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 2000,
        requestFullMetadata: false,
        limit: remaining,
      );
      final out = <DevicePickedMedia>[];
      for (final file in files.take(remaining)) {
        final media = await _fromXFile(
          file,
          isVideo: false,
          fallbackExt: '.jpg',
        );
        if (media != null) out.add(media);
      }
      return out;
    }

    final file = await picker.pickImage(
      source: chosen,
      imageQuality: 85,
      maxWidth: 2000,
      requestFullMetadata: false,
    );
    if (file == null) return const [];
    final media = await _fromXFile(file, isVideo: false, fallbackExt: '.jpg');
    return media == null ? const [] : [media];
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load selected image. Please try again.'),
        ),
      );
    }
    return const [];
  }
}

/// Pick videos. On iOS/Android this asks record vs gallery first.
Future<List<DevicePickedMedia>> pickDeviceVideos(
  BuildContext context, {
  int maxCount = 1,
  ImageSource? source,
}) async {
  final remaining = maxCount < 1 ? 1 : maxCount;
  if (!_useNativePhotoPicker) {
    return _pickWithFilePicker(
      isVideo: true,
      allowMultiple: remaining > 1,
      allowedExtensions: const ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'],
    );
  }

  final chosen =
      source ??
      await _chooseCaptureOrLibrary(context, isVideo: true);
  if (chosen == null) return const [];
  if (!context.mounted) return const [];

  final picker = ImagePicker();
  try {
    final file = await picker.pickVideo(source: chosen);
    if (file == null) return const [];
    final media = await _fromXFile(file, isVideo: true, fallbackExt: '.mp4');
    return media == null ? const [] : [media];
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open selected video. Please try again.'),
        ),
      );
    }
    return const [];
  }
}
