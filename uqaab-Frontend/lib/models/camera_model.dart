// lib/models/camera_model.dart
//
// NOTE: Fence polygon points and cell definitions are stored in the backend DB
// (fence_configs and fence_cells tables). They are NOT stored in this model.
// Fetch them via CameraProvider.getCells() / saveFenceConfig() when needed.

import 'grid_cell_model.dart';

class CameraModel {
  final String id;
  final String name;
  final String rtspUrl;
  final String cameraType; // 'entrance' | 'fence' | 'insider'
  final bool isOnline;
  final GridCellModel gridCell;

  CameraModel({
    required this.id,
    required this.name,
    required this.rtspUrl,
    this.cameraType = 'entrance',
    required this.gridCell,
    this.isOnline = false,
  });

  factory CameraModel.fromJson(Map<String, dynamic> json) {
    return CameraModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      rtspUrl: json['rtsp_url'] ?? '',
      cameraType: json['camera_type'] ?? 'entrance',
      isOnline: json['is_online'] ?? json['online'] ?? false,
      gridCell:
          GridCellModel.fromJson(json['grid_cell'] ?? {'row': 0, 'col': 0}),
    );
  }

  CameraModel copyWith({
    String? id,
    String? name,
    String? rtspUrl,
    String? cameraType,
    bool? isOnline,
    GridCellModel? gridCell,
  }) {
    return CameraModel(
      id: id ?? this.id,
      name: name ?? this.name,
      rtspUrl: rtspUrl ?? this.rtspUrl,
      cameraType: cameraType ?? this.cameraType,
      isOnline: isOnline ?? this.isOnline,
      gridCell: gridCell ?? this.gridCell,
    );
  }
}