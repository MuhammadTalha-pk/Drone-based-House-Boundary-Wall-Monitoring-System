import '../../../core/errors/api_exception.dart';
import '../../../core/providers/base_provider.dart';
import '../../../models/flight_log_model.dart';
import '../../../repositories/flight_log_repository.dart';

class FlightLogProvider extends BaseProvider {
  final FlightLogRepository flightLogRepository;

  List<FlightLogModel> _logs = [];
  List<FlightLogModel> get logs => _logs;

  FlightLogProvider({required this.flightLogRepository});

  Future<void> loadFlightLogs(String propertyId) async {
    try {
      setLoading();
      _logs = await flightLogRepository.getFlightLogs(propertyId);
      setSuccess();
    } on ApiException catch (e) {
      setError(e.message);
    } catch (e) {
      setError('Failed to load flight logs');
    }
  }

  Future<bool> createFlightLog({
    required String propertyId,
    required String droneName,
    required String flightType,
    required String takeoffTime,
    required String landTime,
    int? droneId,
  }) async {
    try {
      await flightLogRepository.createFlightLog(
        propertyId: propertyId,
        droneName: droneName,
        flightType: flightType,
        takeoffTime: takeoffTime,
        landTime: landTime,
        droneId: droneId,
      );
      await loadFlightLogs(propertyId);
      return true;
    } catch (e) {
      return false;
    }
  }
}