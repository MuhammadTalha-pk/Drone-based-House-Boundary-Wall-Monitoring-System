// lib/models/alert_model.dart
import 'package:uqaab/models/grid_cell_model.dart';

class AlertModel {
  final String id;
  final String type;
  final String cameraName;
  final String timestamp;
  final bool isRead;
  final int confidence;
  final String severity;
  final String? imageUrl;
  final String? clipUrl;
  final GridCellModel cameraCell;
  final String status;

  // NEW: Detected cell
  final String? detectedCell;

  // Face detection fields
  final String? trackingId;
  final String? faceImageUrl;

  AlertModel({
    required this.id,
    required this.type,
    required this.cameraName,
    required this.timestamp,
    required this.isRead,
    required this.confidence,
    required this.severity,
    this.imageUrl,
    this.clipUrl,
    required this.cameraCell,
    required this.status,
    this.detectedCell, // <--- ADDED
    this.trackingId,
    this.faceImageUrl,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'].toString(),
      type: json['type'] ?? '',
      cameraName: json['camera_name'] ?? '',
      timestamp: json['timestamp'] ?? '',
      isRead: json['is_read'] ?? false,
      confidence: json['confidence'] ?? 0,
      severity: json['severity'] ?? 'medium',
      imageUrl: json['image_url'],
      clipUrl: json['clip_url'],
      cameraCell:
          GridCellModel.fromJson(json['camera_cell'] ?? {'row': 0, 'col': 0}),
      status: json['status'] ?? 'active',
      detectedCell: json['detected_cell'], // <--- ADDED
      trackingId: json['tracking_id'],
      faceImageUrl: json['face_image_url'],
    );
  }

  AlertModel copyWith({bool? isRead}) {
    return AlertModel(
      id: id,
      type: type,
      cameraName: cameraName,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      confidence: confidence,
      severity: severity,
      imageUrl: imageUrl,
      clipUrl: clipUrl,
      cameraCell: cameraCell,
      status: status,
      detectedCell: detectedCell, // <--- ADDED
      trackingId: trackingId,
      faceImageUrl: faceImageUrl,
    );
  }

  bool get hasSnapshot => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasVideo => clipUrl != null && clipUrl!.isNotEmpty;
  bool get hasFaceImage => faceImageUrl != null && faceImageUrl!.isNotEmpty;
  bool get isMultiCamera => cameraName.contains('→');

  bool get isFaceAlert =>
      type.toLowerCase().contains('unauthorized') ||
      type.toLowerCase().contains('entrance') ||
      type.toLowerCase().contains('face');

  List<String> get cameraPath {
    if (isMultiCamera) {
      return cameraName.split('→').map((s) => s.trim()).toList();
    }
    return [cameraName];
  }

  String get formattedTimestamp {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }
}
