class FlightLogModel {
  final String id;
  final String droneName;
  final String type;
  final String takeoffTime;
  final String landTime;

  FlightLogModel({
    required this.id,
    required this.droneName,
    required this.type,
    required this.takeoffTime,
    required this.landTime,
  });

  factory FlightLogModel.fromJson(Map<String, dynamic> json) {
    return FlightLogModel(
      id: json['id'].toString(),
      droneName: json['drone_name'] ?? '',
      type: json['type'] ?? '',
      takeoffTime: json['takeoff_time'] ?? '',
      landTime: json['land_time'] ?? '',
    );
  }
}