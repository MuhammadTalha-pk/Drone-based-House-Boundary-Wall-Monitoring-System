// lib/app/app_providers.dart
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:uqaab/core/network/dio_client.dart';
import 'package:uqaab/core/services/api_service.dart';
import 'package:uqaab/core/services/secure_storage_service.dart';
import 'package:uqaab/core/providers/property_context_provider.dart';

import 'package:uqaab/repositories/auth_repository.dart';
import 'package:uqaab/repositories/property_repository.dart';
import 'package:uqaab/repositories/alert_repository.dart';
import 'package:uqaab/repositories/camera_repository.dart';
import 'package:uqaab/repositories/drone_repository.dart';
import 'package:uqaab/repositories/person_repository.dart';
import 'package:uqaab/repositories/flight_log_repository.dart';
import 'package:uqaab/repositories/face_detection_repository.dart';

import 'package:uqaab/features/auth/provider/auth_provider.dart';
import 'package:uqaab/features/property/provider/property_provider.dart';
import 'package:uqaab/features/dashboard/provider/dashboard_provider.dart';
import 'package:uqaab/features/alerts/provider/alert_provider.dart';
import 'package:uqaab/features/cameras/provider/camera_provider.dart';
import 'package:uqaab/features/drones/provider/drone_provider.dart';
import 'package:uqaab/features/authorized_people/provider/person_provider.dart';
import 'package:uqaab/features/flight_logs/provider/flight_log_provider.dart';
import 'package:uqaab/features/drone_control/provider/drone_control_provider.dart';

class AppProviders {
  static List<SingleChildWidget> get providers {
    final dioClient = DioClient();
    final apiService = ApiService(dioClient: dioClient);
    final secureStorage = SecureStorageService();

    final authRepo = AuthRepository(apiService: apiService);
    final propertyRepo = PropertyRepository(apiService: apiService);
    final alertRepo = AlertRepository(apiService: apiService);
    final cameraRepo = CameraRepository(apiService: apiService);
    final droneRepo = DroneRepository(apiService: apiService);
    final personRepo = PersonRepository(apiService: apiService);
    final flightLogRepo = FlightLogRepository(apiService: apiService);
    final faceDetectionRepo = FaceDetectionRepository(apiService: apiService);

    return [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(
          authRepository: authRepo,
          secureStorage: secureStorage,
        ),
      ),
      ChangeNotifierProvider<PropertyContextProvider>(
        create: (_) => PropertyContextProvider(),
      ),
      ChangeNotifierProvider<PropertyProvider>(
        create: (_) => PropertyProvider(
          propertyRepository: propertyRepo,
        ),
      ),
      ChangeNotifierProvider<DashboardProvider>(
        create: (_) => DashboardProvider(apiService: apiService),
      ),
      ChangeNotifierProvider<AlertProvider>(
        create: (_) => AlertProvider(alertRepository: alertRepo),
      ),
      ChangeNotifierProvider<CameraProvider>(
        create: (_) => CameraProvider(cameraRepository: cameraRepo),
      ),
      ChangeNotifierProvider<DroneProvider>(
        create: (_) => DroneProvider(droneRepository: droneRepo),
      ),
      ChangeNotifierProvider<DroneControlProvider>(
        create: (_) => DroneControlProvider(apiService: apiService),
      ),
      ChangeNotifierProvider<PersonProvider>(
        create: (_) => PersonProvider(personRepository: personRepo),
      ),
      ChangeNotifierProvider<FlightLogProvider>(
        create: (_) => FlightLogProvider(flightLogRepository: flightLogRepo),
      ),
      Provider<FaceDetectionRepository>.value(value: faceDetectionRepo),
    ];
  }
}
