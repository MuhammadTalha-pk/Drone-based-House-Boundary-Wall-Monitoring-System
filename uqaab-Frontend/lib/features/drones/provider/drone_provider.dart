// lib/features/drones/provider/drone_provider.dart
import '../../../core/errors/api_exception.dart';
import '../../../core/providers/base_provider.dart';
import '../../../models/drone_model.dart';
import '../../../repositories/drone_repository.dart';

class DroneProvider extends BaseProvider {
  final DroneRepository droneRepository;

  List<DroneModel> _drones = [];
  List<DroneModel> get drones => _drones;

  DroneProvider({required this.droneRepository});

  Future<void> loadDrones(String propertyId) async {
    try {
      setLoading();
      _drones = await droneRepository.getDrones(propertyId);
      setSuccess();
    } on ApiException catch (e) {
      setError(e.message);
    } catch (e) {
      setError('Failed to load drones');
    }
  }

  DroneModel? getDroneById(String id) {
    try {
      return _drones.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<bool> createDrone({
    required String propertyId,
    required String name,
    required String connectionString,
    required int row,
    required int col,
  }) async {
    try {
      setLoading();
      await droneRepository.createDrone(
        propertyId,
        name: name,
        connectionString: connectionString,
        homeCell: {'row': row, 'col': col},
      );
      await loadDrones(propertyId);
      return true;
    } on ApiException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Failed to create drone');
      return false;
    }
  }

  Future<bool> updateDrone({
    required String droneId,
    required String propertyId,
    String? name,
    String? connectionString,
    int? row,
    int? col,
  }) async {
    try {
      setLoading();
      await droneRepository.updateDrone(
        droneId,
        name: name,
        connectionString: connectionString,
        homeCell:
            (row != null && col != null) ? {'row': row, 'col': col} : null,
      );
      await loadDrones(propertyId);
      return true;
    } on ApiException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Failed to update drone');
      return false;
    }
  }

  Future<bool> deleteDrone({
    required String droneId,
    required String propertyId,
  }) async {
    try {
      setLoading();
      await droneRepository.deleteDrone(droneId);
      await loadDrones(propertyId);
      return true;
    } on ApiException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Failed to delete drone');
      return false;
    }
  }
}