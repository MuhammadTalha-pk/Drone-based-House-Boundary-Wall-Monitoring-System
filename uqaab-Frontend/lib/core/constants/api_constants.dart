// lib/core/constants/api_constants.dart
class ApiConstants {
  // Auth
  static const String login  = '/auth/login';
  static const String signup = '/auth/signup';
  static const String me     = '/auth/me';

  // Properties
  static const String properties = '/properties/';
  static String property(String id) => '/properties/$id';

  // Dashboard
  static String dashboard(String propertyId)   => '/dashboard/$propertyId';
  static String droneStatus(String propertyId) => '/dashboard/$propertyId/drone-status';

  // Alerts
  static String alerts(String propertyId)             => '/dashboard/$propertyId/alerts';
  static String alertDetail(String alertId)            => '/dashboard/alerts/$alertId';
  static String alertRead(String alertId)              => '/dashboard/alerts/$alertId/read';
  static String alertFalsePositive(String alertId)     => '/dashboard/alerts/$alertId/false-positive';
  static String alertResolve(String alertId)           => '/dashboard/alerts/$alertId/resolve';
  static String alertDelete(String alertId)            => '/dashboard/alerts/$alertId';

  // Cameras
  static String cameras(String propertyId) => '/settings/$propertyId/cameras';
  static String camera(String cameraId)    => '/settings/cameras/$cameraId';

  // Drones
  static String drones(String propertyId) => '/settings/$propertyId/drones';
  static String drone(String droneId)     => '/settings/drones/$droneId';

  // People
  static String people(String propertyId) => '/settings/$propertyId/people';
  static String person(String personId)   => '/settings/people/$personId';
  static const String uploadPersonImage   = '/settings/upload-person-image';
  static const String relationships       = '/settings/relationships';

  // Flight Logs
  static String flightLogs(String propertyId) => '/settings/$propertyId/flight-logs';

  // Face Detection
  static String faceEvents(String propertyId)          => '/face-detection/$propertyId/events';
  static String faceEventsByCamera(String cameraId)    => '/face-detection/cameras/$cameraId/events';
  static String faceEvent(String eventId)              => '/face-detection/events/$eventId';
  static const  String encodePerson                    = '/face-detection/encode-person';
  static const  String faceDetectionStatus             = '/face-detection/status';
  static String startFaceDetection(String cameraId)    => '/face-detection/cameras/$cameraId/start';
  static String stopFaceDetection(String cameraId)     => '/face-detection/cameras/$cameraId/stop';
  static String restartFaceDetection(String cameraId)  => '/face-detection/cameras/$cameraId/restart';

  // Fence Calibration (fence cameras only)
  // POST / GET → save or fetch the 4-point boundary polygon
  static String fenceConfig(String cameraId) => '/cameras/$cameraId/fence-config';

  // Cell Calibration (ALL camera types: fence, entrance, insider)
  // POST / GET / DELETE → save, list, or clear cell definitions
  static String cameraCells(String cameraId) => '/cameras/$cameraId/cells';
}