import '../core/constants/api_constants.dart';
import '../core/services/api_service.dart';
import '../models/camera_model.dart';

class CameraRepository {
  final ApiService apiService;
  String? errorMessage;

  CameraRepository({required this.apiService});

  // ── Cameras ────────────────────────────────────────────────────────────────

  Future<List<CameraModel>> getCameras(String propertyId) async {
    try {
      errorMessage = null;
      final response = await apiService.get(ApiConstants.cameras(propertyId));
      final List<dynamic> data = response['cameras'] ?? [];
      return data.map((json) => CameraModel.fromJson(json)).toList();
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    }
  }

  /// Creates a camera and returns the real [camera_id] from the server.
  /// Backend returns: {"success": true, "message": "...", "camera_id": 5}
  Future<int> createCamera({
    required String propertyId,
    required String name,
    required String rtspUrl,
    required Map<String, dynamic> gridCell,
    String camera_type = 'entrance',
  }) async {
    try {
      errorMessage = null;
      final response = await apiService.post(
        ApiConstants.cameras(propertyId),
        data: {
          'name': name,
          'rtsp_url': rtspUrl,
          'grid_cell': gridCell,
          'camera_type': camera_type,
        },
      );
      // Backend returns CameraCreatedResponse: {success, message, camera_id}
      return response['camera_id'] as int;
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> updateCamera({
    required String cameraId,
    String? name,
    String? rtspUrl,
    Map<String, dynamic>? gridCell,
    String? camera_type,
  }) async {
    try {
      errorMessage = null;
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (rtspUrl != null) data['rtsp_url'] = rtspUrl;
      if (gridCell != null) data['grid_cell'] = gridCell;
      if (camera_type != null) data['camera_type'] = camera_type;
      await apiService.put(ApiConstants.camera(cameraId), data: data);
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> deleteCamera(String cameraId) async {
    try {
      errorMessage = null;
      await apiService.delete(ApiConstants.camera(cameraId));
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    }
  }

  // ── Fence polygon (fence cameras only) ─────────────────────────────────────
  // POST /api/v1/cameras/{camera_id}/fence-config
  // Body: {"points": [{x: float, y: float}, ...]}  (normalised 0-1)
  //
  // NOTE: apiService.post expects Map<String, dynamic>? for `data`.
  // We wrap the list in a map: {"points": [...]}
  // Make sure your backend reads body["points"] instead of the bare list.
  // If your backend truly expects a bare JSON array, change ApiService.post
  // to accept `dynamic` for data.

  Future<bool> saveFenceConfig(
    int cameraId,
    List<Map<String, double>> points,
  ) async {
    try {
      errorMessage = null;
      await apiService.post(
        ApiConstants.fenceConfig(cameraId.toString()),
        data: {'points': points}, // ← wrapped so type is Map<String, dynamic>
      );
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    }
  }

  // ── Cell definitions (ALL camera types) ────────────────────────────────────
  // POST /api/v1/cameras/{camera_id}/cells
  // Body: { "cells": [ {cell_name, row, col, polygon_points: [{x,y}×4]} ] }

  Future<void> saveCells(
    int cameraId,
    List<Map<String, dynamic>> cells,
  ) async {
    try {
      errorMessage = null;
      await apiService.post(
        ApiConstants.cameraCells(cameraId.toString()),
        data: {'cells': cells},
      );
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    }
  }

  /// Fetch existing cells for a camera (any type).
  Future<List<Map<String, dynamic>>> getCells(int cameraId) async {
    try {
      errorMessage = null;
      final response = await apiService.get(
        ApiConstants.cameraCells(cameraId.toString()),
      );
      return List<Map<String, dynamic>>.from(response['cells'] ?? []);
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    }
  }
}