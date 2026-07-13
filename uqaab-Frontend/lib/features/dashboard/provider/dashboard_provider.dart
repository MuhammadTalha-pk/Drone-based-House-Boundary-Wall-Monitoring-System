import 'package:flutter/material.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/providers/base_provider.dart';
import '../../../core/services/api_service.dart';

class DashboardData {
  final String propertyName;
  final String droneStatus;
  final int camerasOnline;
  final int camerasTotal;
  final int newAlertsCount;
  final ActiveAlertData? activeAlert;
  final List<CameraFeedData> cameras;
  final List<DroneFeedData> drones;
  final double latitude;
  final double longitude;

  DashboardData({
    required this.propertyName,
    required this.droneStatus,
    required this.camerasOnline,
    required this.camerasTotal,
    required this.newAlertsCount,
    this.activeAlert,
    required this.cameras,
    required this.drones,
    required this.latitude,
    required this.longitude,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    // 1. Parse the cameras first
    final parsedCameras = (json['cameras'] as List? ?? [])
        .map((e) => CameraFeedData.fromJson(e))
        .toList();

    // 2. Count ONLY the cameras that are actually online (have a stream URL)
    final actualOnlineCount = parsedCameras.where((c) => c.isOnline).length;

    return DashboardData(
      propertyName: json['property_name'] ?? '',
      droneStatus: json['drone_status'] ?? 'Offline',

      // 3. Ignore the backend's fake number and use our real count!
      camerasOnline: actualOnlineCount,
      camerasTotal:
          parsedCameras.length, // Total is just the length of the list

      newAlertsCount: json['new_alerts_count'] ?? 0,
      activeAlert: json['active_alert'] != null
          ? ActiveAlertData.fromJson(json['active_alert'])
          : null,
      cameras: parsedCameras,
      drones: (json['drones'] as List? ?? [])
          .map((e) => DroneFeedData.fromJson(e))
          .toList(),
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }
}

class ActiveAlertData {
  final String id;
  final String message;
  final String severity;
  final String timestamp;

  ActiveAlertData({
    required this.id,
    required this.message,
    required this.severity,
    required this.timestamp,
  });

  factory ActiveAlertData.fromJson(Map<String, dynamic> json) {
    return ActiveAlertData(
      id: json['id'].toString(),
      message: json['message'] ?? '',
      severity: json['severity'] ?? 'medium',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class CameraFeedData {
  final String id;
  final String name;
  final bool isOnline;
  final String? streamUrl;
  final String? thumbnailUrl;

  CameraFeedData({
    required this.id,
    required this.name,
    required this.isOnline,
    this.streamUrl,
    this.thumbnailUrl,
  });

  factory CameraFeedData.fromJson(Map<String, dynamic> json) {
    final stream = json['stream_url'] as String?;

    // 4. Force the camera to be "Offline" if the stream URL is null or empty
    final hasValidStream = stream != null && stream.trim().isNotEmpty;

    return CameraFeedData(
      id: json['id'].toString(),
      name: json['name'] ?? '',

      // Ignore the backend's 'is_online' if it has no stream!
      isOnline: hasValidStream,
      streamUrl: stream,
      thumbnailUrl: json['thumbnail_url'],
    );
  }
}

class DroneFeedData {
  final String id;
  final String name;
  final bool isOnline;
  final String? streamUrl;

  DroneFeedData({
    required this.id,
    required this.name,
    required this.isOnline,
    this.streamUrl,
  });

  factory DroneFeedData.fromJson(Map<String, dynamic> json) {
    debugPrint('👀 RAW DRONE JSON FROM BACKEND: $json');

    return DroneFeedData(
        id: json['id'].toString(),
        name: json['name'] ?? '',
        isOnline: json['is_online'] ?? false,
        streamUrl: json['stream_url'] ?? json['connection_string']);
  }
}

class DashboardProvider extends BaseProvider {
  final ApiService apiService;

  DashboardData? _dashboardData;
  DashboardData? get dashboardData => _dashboardData;

  DashboardProvider({required this.apiService});

  Future<void> loadDashboard(String propertyId) async {
    try {
      setLoading();
      final response = await apiService.get(ApiConstants.dashboard(propertyId));
      _dashboardData = DashboardData.fromJson(response);
      setSuccess();
    } on ApiException catch (e) {
      setError(e.message);
    } catch (e) {
      setError('Failed to load dashboard');
    }
  }

  Future<bool> toggleDroneStatus(String propertyId) async {
    try {
      await apiService.put(ApiConstants.droneStatus(propertyId));
      await loadDashboard(propertyId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
