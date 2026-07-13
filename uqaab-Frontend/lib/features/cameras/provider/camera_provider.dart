// lib/features/cameras/provider/camera_provider.dart

import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers/base_provider.dart';
import '../../../models/camera_model.dart';
import '../../../repositories/camera_repository.dart';

class CameraProvider extends BaseProvider {
  final CameraRepository cameraRepository;

  List<CameraModel> _cameras = [];
  List<CameraModel> get cameras => _cameras;

  /// Holds the integer camera_id returned right after createCamera().
  /// Use this to pass into FenceCalibrationScreen / CameraCellCalibrationScreen.
  int? _lastCreatedCameraId;
  int? get lastCreatedCameraId => _lastCreatedCameraId;

  CameraProvider({required this.cameraRepository});

  // ── Cameras ─────────────────────────────────────────────────────────────────

  Future<void> loadCameras(String propertyId) async {
    try {
      setLoading();
      _cameras = await cameraRepository.getCameras(propertyId);
      setSuccess();
    } on ApiException catch (e) {
      setError(e.message);
    } catch (e) {
      setError('Failed to load cameras');
    }
  }

  CameraModel? getCameraById(String id) {
    try {
      return _cameras.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Creates the camera on the backend and returns the new [camera_id] (int).
  /// Returns null on failure — check [errorMessage] for details.
  /// Navigation to calibration screens should happen AFTER this succeeds.
  Future<int?> createCamera({
    required String propertyId,
    required String name,
    required String rtspUrl,
    required int row,
    required int col,
    String camera_type = 'entrance',
  }) async {
    try {
      setLoading();
      _lastCreatedCameraId = null;

      final cameraId = await cameraRepository.createCamera(
        propertyId: propertyId,
        name: name,
        rtspUrl: rtspUrl,
        gridCell: {'row': row, 'col': col},
        camera_type: camera_type,
      );

      _lastCreatedCameraId = cameraId;

      // Reload list so cameras screen reflects the new entry
      await loadCameras(propertyId);

      setSuccess();
      return cameraId;
    } on ApiException catch (e) {
      setError(e.message);
      return null;
    } catch (e) {
      setError('Failed to create camera');
      return null;
    }
  }

  Future<bool> updateCamera({
    required String cameraId,
    required String propertyId,
    String? name,
    String? rtspUrl,
    int? row,
    int? col,
    String? camera_type,
  }) async {
    try {
      setLoading();
      await cameraRepository.updateCamera(
        cameraId: cameraId,
        name: name,
        rtspUrl: rtspUrl,
        gridCell:
            (row != null && col != null) ? {'row': row, 'col': col} : null,
        camera_type: camera_type,
      );
      await loadCameras(propertyId);
      return true;
    } on ApiException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Failed to update camera');
      return false;
    }
  }

  Future<bool> deleteCamera({
    required String cameraId,
    required String propertyId,
  }) async {
    try {
      setLoading();
      await cameraRepository.deleteCamera(cameraId);
      await loadCameras(propertyId);
      return true;
    } on ApiException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Failed to delete camera');
      return false;
    }
  }

  // ── Fence polygon ──────────────────────────────────────────────────────────
  Future<bool> saveFenceConfig(
    int cameraId,
    List<Map<String, double>> points,
  ) async {
    try {
      setLoading();

      // 1. The exact URL to match the React Native / Backend setup
      final url = '/fence-config/cameras/$cameraId/fence-config';

      // 2. We use dioClient DIRECTLY to bypass the Map<String, dynamic> restriction!
      // This sends the raw JSON array [ {x,y}, {x,y}, ... ] exactly how FastAPI wants it.
      await cameraRepository.apiService.dioClient.post(url, data: points);

      setSuccess();
      return true;
    } catch (e) {
      // 3. Print the real error if it fails!
      debugPrint('FENCE SAVE ERROR: $e');
      setError('Failed to save fence config: $e');
      return false;
    }
  }

  // ── Cell definitions (ALL camera types) ────────────────────────────────────
  // Called from CameraCellCalibrationScreen after user draws all cells.
  // Each cell: { cell_name, row, col, polygon_points: [{x,y}×4] }

  Future<bool> saveCells(
      int cameraId, List<Map<String, dynamic>> cellsPayload) async {
    try {
      setLoading();

      // 1. ADD /fence-config TO THE URL
      final url = '/fence-config/cameras/$cameraId/cells';

      // 2. WRAP THE LIST IN A "cells" MAP
      final body = {'cells': cellsPayload};

      await cameraRepository.apiService.post(url, data: body);

      setSuccess();
      return true;
    } catch (e) {
      setError('Failed to save cells: $e');
      return false;
    }
  }

  //// Fetch saved cells for a camera (used to pre-populate edit screen).
  Future<List<Map<String, dynamic>>> getCells(int cameraId) async {
    try {
      // 1. Fetch directly using apiService to avoid repository casting crashes
      final url = '/fence-config/cameras/$cameraId/cells';
      final response = await cameraRepository.apiService.get(url);

      // 2. Extract the 'cells' array safely from the JSON object
      if (response['cells'] != null) {
        final cellsList = response['cells'] as List;
        return cellsList.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      // 3. Print the error so we aren't flying blind!
      debugPrint('GET CELLS ERROR: $e');
      return [];
    }
  }

  /// Fetch the saved 4-point polygon fence config.
  Future<List<Map<String, double>>?> getFenceConfig(int cameraId) async {
    try {
      final url = '/fence-config/cameras/$cameraId/fence-config';
      final response = await cameraRepository.apiService.get(url);

      if (response['polygon_points'] != null) {
        final pts = response['polygon_points'] as List;
        return pts
            .map((p) => {
                  'x': (p['x'] as num).toDouble(),
                  'y': (p['y'] as num).toDouble()
                })
            .toList();
      }
      return null;
    } catch (e) {
      debugPrint('GET FENCE CONFIG ERROR: $e');
      return null;
    }
  }
}
