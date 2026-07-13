import '../core/constants/api_constants.dart';
import '../core/services/api_service.dart';
import '../models/flight_log_model.dart';

class FlightLogRepository {
  final ApiService apiService;

  FlightLogRepository({required this.apiService});

  Future<List<FlightLogModel>> getFlightLogs(String propertyId) async {
    final response = await apiService.get(ApiConstants.flightLogs(propertyId));
    final List<dynamic> data = response['flight_logs'] ?? [];
    return data.map((json) => FlightLogModel.fromJson(json)).toList();
  }

  Future<void> createFlightLog({
    required String propertyId,
    required String droneName,
    required String flightType,
    required String takeoffTime,
    required String landTime,
    int? droneId,
  }) async {
    await apiService.post(
      ApiConstants.flightLogs(propertyId),
      data: {
        'drone_name': droneName,
        'flight_type': flightType,
        'takeoff_time': takeoffTime,
        'land_time': landTime,
        'drone_id': droneId,
      },
    );
  }
}