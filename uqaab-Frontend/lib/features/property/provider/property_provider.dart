// lib/features/property/provider/property_provider.dart
import '../../../core/errors/api_exception.dart';
import '../../../core/providers/base_provider.dart';
import '../../../models/property_model.dart';
import '../../../repositories/property_repository.dart';

class PropertyProvider extends BaseProvider {
  final PropertyRepository propertyRepository;

  List<PropertyModel> _properties = [];
  List<PropertyModel> get properties => _properties;

  // ✅ FIXED: removed apiService param — PropertyRepository is the only dependency
  PropertyProvider({required this.propertyRepository});

  Future<void> loadProperties() async {
    try {
      setLoading();
      _properties = await propertyRepository.getProperties();
      setSuccess();
    } on ApiException catch (e) {
      setError(e.message);
    } catch (e) {
      setError('Failed to load properties');
    }
  }

  Future<bool> createProperty({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required Map<String, dynamic> laserGrid,
  }) async {
    try {
      setLoading();
      await propertyRepository.createProperty(
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        laserGrid: laserGrid,
      );
      await loadProperties();
      return true;
    } on ApiException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Failed to create property');
      return false;
    }
  }

  Future<bool> updateProperty({
    required String id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? laserGrid,
  }) async {
    try {
      setLoading();
      await propertyRepository.updateProperty(
        id: id,
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        laserGrid: laserGrid,
      );
      await loadProperties();
      return true;
    } on ApiException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Failed to update property');
      return false;
    }
  }

  Future<bool> deleteProperty(String id) async {
    try {
      setLoading();
      await propertyRepository.deleteProperty(id);
      await loadProperties();
      return true;
    } on ApiException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Failed to delete property');
      return false;
    }
  }

  Future<bool> deleteProperties(List<String> ids) async {
    if (ids.isEmpty) return true;

    try {
      setLoading();
      for (final id in ids.toSet()) {
        await propertyRepository.deleteProperty(id);
      }
      await loadProperties();
      return true;
    } on ApiException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Failed to delete properties');
      return false;
    }
  }
}
