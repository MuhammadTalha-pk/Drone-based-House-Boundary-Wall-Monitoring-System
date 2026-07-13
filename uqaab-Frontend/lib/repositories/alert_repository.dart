import '../core/constants/api_constants.dart';
import '../core/services/api_service.dart';
import '../models/alert_model.dart';

class AlertRepository {
  final ApiService apiService;

  AlertRepository({required this.apiService});

  Future<List<AlertModel>> getAlerts(String propertyId,
      {String filter = 'all'}) async {
    final response = await apiService.get(
      ApiConstants.alerts(propertyId),
      queryParameters: {'filter': filter},
    );
    final List<dynamic> data = response['alerts'] ?? [];
    return data.map((json) => AlertModel.fromJson(json)).toList();
  }

  Future<AlertModel> getAlert(String alertId) async {
    final response = await apiService.get(ApiConstants.alertDetail(alertId));
    return AlertModel.fromJson(response['alert']);
  }

  Future<void> markAsRead(String alertId) async {
    await apiService.put(ApiConstants.alertRead(alertId));
  }

  Future<void> markAsFalsePositive(String alertId) async {
    await apiService.put(ApiConstants.alertFalsePositive(alertId));
  }

  Future<void> resolveAlert(String alertId) async {
    await apiService.put(ApiConstants.alertResolve(alertId));
  }

  Future<void> deleteAlert(String alertId) async {
    await apiService.delete(ApiConstants.alertDelete(alertId));
  }

  Future<void> toggleDroneStatus(String propertyId) async {
    await apiService.put(ApiConstants.droneStatus(propertyId));
  }
}