import '../core/constants/api_constants.dart';
import '../core/services/api_service.dart';
import '../models/property_model.dart';

class PropertyRepository {
  final ApiService apiService;

  PropertyRepository({required this.apiService});

  Future<List<PropertyModel>> getProperties() async {
    final response = await apiService.get(ApiConstants.properties);
    final List<dynamic> data = response['properties'] ?? [];
    return data.map((json) => PropertyModel.fromJson(json)).toList();
  }

  Future<PropertyModel> getProperty(String id) async {
    final response = await apiService.get(ApiConstants.property(id));
    return PropertyModel.fromJson(response['property']);
  }

  Future<PropertyModel> createProperty({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required Map<String, dynamic> laserGrid,
  }) async {
    final response = await apiService.post(
      ApiConstants.properties,
      data: {
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'laser_grid': laserGrid,
      },
    );
    return PropertyModel.fromJson(response['property']);
  }

  Future<PropertyModel> updateProperty({
    required String id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? laserGrid,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (address != null) data['address'] = address;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    if (laserGrid != null) data['laser_grid'] = laserGrid;

    final response = await apiService.put(
      ApiConstants.property(id),
      data: data,
    );
    return PropertyModel.fromJson(response['property']);
  }

  Future<void> deleteProperty(String id) async {
    await apiService.delete(ApiConstants.property(id));
  }
}