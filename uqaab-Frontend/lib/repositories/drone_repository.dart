// lib/repositories/drone_repository.dart
import '../core/services/api_service.dart';
import '../core/constants/api_constants.dart';
import '../models/drone_model.dart';

class DroneRepository {
  final ApiService apiService;

  // ✅ FIXED: Constructor now requires apiService (matches AppProviders instantiation)
  DroneRepository({required this.apiService});

  Future<List<DroneModel>> getDrones(String propertyId) async {
    final response = await apiService.get(ApiConstants.drones(propertyId));
    final List<dynamic> data = response['drones'] ?? [];
    return data.map((json) => DroneModel.fromJson(json)).toList();
  }

  Future<void> createDrone(
    String propertyId, {
    required String name,
    required String connectionString,
    required Map<String, dynamic> homeCell,
  }) async {
    await apiService.post(
      ApiConstants.drones(propertyId),
      data: {
        'name': name,
        'connection_string': connectionString,
        'home_cell': homeCell,
      },
    );
  }

  Future<void> updateDrone(
    String droneId, {
    String? name,
    String? connectionString,
    Map<String, dynamic>? homeCell,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (connectionString != null) data['connection_string'] = connectionString;
    if (homeCell != null) data['home_cell'] = homeCell;
    await apiService.put(ApiConstants.drone(droneId), data: data);
  }

  Future<void> deleteDrone(String droneId) async {
    await apiService.delete(ApiConstants.drone(droneId));
  }
}