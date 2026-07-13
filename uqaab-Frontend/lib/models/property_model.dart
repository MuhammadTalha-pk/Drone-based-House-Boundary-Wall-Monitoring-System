class LaserGrid {
  final int xLasers;
  final int yLasers;
  final double boxWidth;
  final double boxLength;
  final double gridHeight;

  LaserGrid({
    required this.xLasers,
    required this.yLasers,
    required this.boxWidth,
    required this.boxLength,
    required this.gridHeight,
  });

  factory LaserGrid.fromJson(Map<String, dynamic> json) {
    return LaserGrid(
      xLasers: json['x_lasers'] ?? 3,
      yLasers: json['y_lasers'] ?? 8,
      boxWidth: (json['box_width'] ?? 2.0).toDouble(),
      boxLength: (json['box_length'] ?? 0.6).toDouble(),
      gridHeight: (json['grid_height'] ?? 2.4).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x_lasers': xLasers,
      'y_lasers': yLasers,
      'box_width': boxWidth,
      'box_length': boxLength,
      'grid_height': gridHeight,
    };
  }
}

class PropertyModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final LaserGrid laserGrid;
  final int camerasOnline;
  final int camerasTotal;
  final String droneStatus;
  final int activeAlerts;
  final String createdAt;

  PropertyModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.laserGrid,
    required this.camerasOnline,
    required this.camerasTotal,
    required this.droneStatus,
    required this.activeAlerts,
    required this.createdAt,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    return PropertyModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      laserGrid: LaserGrid.fromJson(json['laser_grid'] ?? {}),
      camerasOnline: json['cameras_online'] ?? 0,
      camerasTotal: json['cameras_total'] ?? 0,
      droneStatus: json['drone_status'] ?? 'Offline',
      activeAlerts: json['active_alerts'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}