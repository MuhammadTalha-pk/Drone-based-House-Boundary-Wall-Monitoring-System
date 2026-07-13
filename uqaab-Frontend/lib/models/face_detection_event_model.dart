// lib/models/face_detection_event_model.dart

class FaceDetectionEventModel {
  final String id;
  final String propertyId;
  final String? cameraId;
  final bool isAuthorized;
  final String? matchedPersonName;
  final String? matchedRole;
  final double recognitionConfidence;
  final String? trackingId;
  final String? faceImageUrl;
  final String? snapshotUrl;
  final String? videoClipUrl;
  final String? alertId;
  final String detectedAt;

  FaceDetectionEventModel({
    required this.id,
    required this.propertyId,
    this.cameraId,
    required this.isAuthorized,
    this.matchedPersonName,
    this.matchedRole,
    required this.recognitionConfidence,
    this.trackingId,
    this.faceImageUrl,
    this.snapshotUrl,
    this.videoClipUrl,
    this.alertId,
    required this.detectedAt,
  });

  factory FaceDetectionEventModel.fromJson(Map<String, dynamic> json) {
    return FaceDetectionEventModel(
      id: json['id'].toString(),
      propertyId: json['property_id'].toString(),
      cameraId: json['camera_id']?.toString(),
      isAuthorized: json['is_authorized'] ?? false,
      matchedPersonName: json['matched_person_name'],
      matchedRole: json['matched_role'],
      recognitionConfidence:
          (json['recognition_confidence'] as num?)?.toDouble() ?? 0.0,
      trackingId: json['tracking_id'],
      faceImageUrl: json['face_image_url'],
      snapshotUrl: json['snapshot_url'],
      videoClipUrl: json['video_clip_url'],
      alertId: json['alert_id']?.toString(),
      detectedAt: json['detected_at'] ?? '',
    );
  }

  bool get hasFaceImage => faceImageUrl != null && faceImageUrl!.isNotEmpty;
  bool get hasSnapshot  => snapshotUrl  != null && snapshotUrl!.isNotEmpty;
  bool get hasVideo     => videoClipUrl != null && videoClipUrl!.isNotEmpty;
  int  get confidencePercent => (recognitionConfidence * 100).round();

  String get formattedTime {
    try {
      final dt  = DateTime.parse(detectedAt);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1)  return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return detectedAt;
    }
  }
}