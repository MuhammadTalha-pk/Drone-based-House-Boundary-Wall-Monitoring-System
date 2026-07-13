// lib/repositories/face_detection_repository.dart
import 'package:uqaab/core/constants/api_constants.dart';
import 'package:uqaab/core/services/api_service.dart';
import 'package:uqaab/models/face_detection_event_model.dart';

class FaceDetectionRepository {
  final ApiService apiService;

  FaceDetectionRepository({required this.apiService});

  // ─── Events ────────────────────────────────────────────────────────────────

  Future<List<FaceDetectionEventModel>> getEvents(
    String propertyId, {
    int limit = 100,
    bool onlyUnauthorized = false,
  }) async {
    final response = await apiService.get(
      ApiConstants.faceEvents(propertyId),
      queryParameters: {
        'limit': limit,
        'only_unauthorized': onlyUnauthorized,
      },
    );
    final List<dynamic> data = response['events'] ?? [];
    return data.map((j) => FaceDetectionEventModel.fromJson(j)).toList();
  }

  Future<List<FaceDetectionEventModel>> getCameraEvents(
    String cameraId, {
    int limit = 50,
  }) async {
    final response = await apiService.get(
      ApiConstants.faceEventsByCamera(cameraId),
      queryParameters: {'limit': limit},
    );
    final List<dynamic> data = response['events'] ?? [];
    return data.map((j) => FaceDetectionEventModel.fromJson(j)).toList();
  }

  Future<FaceDetectionEventModel> getEvent(String eventId) async {
    final response = await apiService.get(ApiConstants.faceEvent(eventId));
    return FaceDetectionEventModel.fromJson(response);
  }

  Future<void> deleteEvent(String eventId) async {
    await apiService.delete(ApiConstants.faceEvent(eventId));
  }

  // ─── Encoding ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> encodePerson(String personId) async {
    return await apiService.post(
      ApiConstants.encodePerson,
      data: {'person_id': int.parse(personId)},
    );
  }

  // ─── Manager Control ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStatus() async {
    return await apiService.get(ApiConstants.faceDetectionStatus);
  }

  Future<void> startCamera(String cameraId) async {
    await apiService.post(ApiConstants.startFaceDetection(cameraId));
  }

  Future<void> stopCamera(String cameraId) async {
    await apiService.post(ApiConstants.stopFaceDetection(cameraId));
  }

  Future<void> restartCamera(String cameraId) async {
    await apiService.post(ApiConstants.restartFaceDetection(cameraId));
  }
}