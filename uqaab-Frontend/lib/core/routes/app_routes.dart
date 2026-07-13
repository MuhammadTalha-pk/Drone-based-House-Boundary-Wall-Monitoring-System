class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String welcome = '/welcome';
  static const String propertyList = '/properties';
  static const String addProperty = '/properties/add';
  static const String editProperty = '/properties/edit/:id';
  static const String dashboard = '/dashboard';
  static const String alerts = '/alerts';
  static const String alertDetail = '/alerts/:id';
  static const String gridMap = '/map';
  static const String droneControl = '/drone';
  static const String settings = '/settings';
  static const String manageCameras = '/settings/cameras';
  static const String addCamera = '/settings/cameras/add';
  static const String editCamera = '/settings/cameras/edit/:id';
  static const String cameraCells = '/property/:propertyId/camera/:id/cells';
  static const String manageDrones = '/settings/drones';
  static const String addDrone = '/settings/drones/add';
  static const String editDrone = '/settings/drones/edit/:id';
  static const String authorizedPeople = '/settings/people';
  static const String addPerson = '/settings/people/add';
  static const String editPerson = '/settings/people/edit/:id';
  static const String flightLogs = '/settings/flight-logs';
}
