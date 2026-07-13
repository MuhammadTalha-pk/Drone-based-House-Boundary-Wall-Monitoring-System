class GridCellModel {
  final int row;
  final int col;

  GridCellModel({required this.row, required this.col});

  factory GridCellModel.fromJson(Map<String, dynamic> json) {
    return GridCellModel(
      row: json['row'] ?? 0,
      col: json['col'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'row': row, 'col': col};
  }

  @override
  String toString() => 'Cell($col, $row)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridCellModel && row == other.row && col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}