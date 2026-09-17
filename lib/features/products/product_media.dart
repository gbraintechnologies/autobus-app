/// Detects product video URLs the same way Postiz / Instagram publishing does.
bool productMediaLooksLikeVideo(String url) {
  final path = url.split('?').first.toLowerCase();
  return path.endsWith('.mp4') ||
      path.endsWith('.mov') ||
      path.endsWith('.m4v') ||
      path.endsWith('.webm') ||
      path.endsWith('.avi') ||
      path.contains('.mp4');
}

bool productFileLooksLikeVideo(String? nameOrPath) {
  final value = (nameOrPath ?? '').split('?').first.toLowerCase();
  return value.endsWith('.mp4') ||
      value.endsWith('.mov') ||
      value.endsWith('.m4v') ||
      value.endsWith('.webm') ||
      value.endsWith('.avi');
}

const kProductVideoExtensions = ['mp4', 'mov', 'm4v', 'webm'];
const kProductImageExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'];
const kMaxProductVideos = 3;
