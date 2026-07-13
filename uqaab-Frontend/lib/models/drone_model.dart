import 'grid_cell_model.dart';

class DroneModel {
  final String id;
  final String name;
  final String connectionString;
  final String status;
  final GridCellModel homeCell;

  DroneModel({
    required this.id,
    required this.name,
    required this.connectionString,
    required this.status,
    required this.homeCell,
  });

  factory DroneModel.fromJson(Map<String, dynamic> json) {
    return DroneModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      connectionString: json['connection_string'] ?? '',
      status: json['status'] ?? 'Offline',
      homeCell: GridCellModel.fromJson(json['home_cell'] ?? {'row': 0, 'col': 0}),
    );
  }
}