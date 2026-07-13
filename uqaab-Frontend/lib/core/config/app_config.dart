class AppConfig {
// Base URL without /api/v1 for serving static files (snapshots, videos)
  static const String serverBaseUrl = 'http://10.171.188.254:8000';

  // For physical device, use your actual server IP
  static const String baseUrl = '$serverBaseUrl/api/v1';

  static const String appName = 'Uqaab';
  static const String appVersion = '1.0.0';
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration pollInterval = Duration(seconds: 30);

  /// Build full URL for media files (snapshots/videos)
  /// Backend returns paths like "/static/snapshots/alert_21.jpg"
  /// We prepend the server base URL
  static String mediaUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return '';
    if (relativePath.startsWith('http') || relativePath.startsWith('rtsp')) {
      return relativePath;
    }
    return '$serverBaseUrl$relativePath';
  }

  /// Build stream URL for MJPEG camera frames
  /// If cameraId is provided and not 'pending', use the existing /{camera_id}/live endpoint
  /// Otherwise, fall back to streaming via raw RTSP URL (requires stream_router endpoint on backend)
  static String streamUrl(String rtspUrl, {String? cameraId}) {
    if (rtspUrl.isEmpty) return '';

    // If we have a valid camera ID (not 'pending'), use the existing live endpoint
    if (cameraId != null && cameraId.isNotEmpty && cameraId != 'pending') {
      return '$baseUrl/$cameraId/live';
    }

    // Fallback: use raw RTSP URL via stream_router endpoint
    final encodedRtsp = Uri.encodeComponent(rtspUrl);
    return '$baseUrl/stream_router?url=$encodedRtsp';
  }
}
