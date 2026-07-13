class Formatters {
  static String gridCellLabel(int row, int col) {
    return 'Cell $col,$row';
  }

  static String gridCellWithPosition(
    int row,
    int col,
    double boxWidth,
    double boxLength,
  ) {
    final posX = (col * boxWidth).toStringAsFixed(1);
    final posY = (row * boxLength).toStringAsFixed(1);
    return 'Cell $col,$row — Position: (${posX}m, ${posY}m)';
  }

  static String camerasOnlineText(int online, int total) {
    return '$online / $total Online';
  }

  static String droneStatusText(String status) {
    return 'Drone: $status';
  }

  static String alertCountText(int count) {
    if (count == 0) return '0 New Alert';
    if (count == 1) return '1 New Alert';
    return '$count New Alerts';
  }

  static String gridSizeText(int xLasers, int yLasers) {
    return '$xLasers × $yLasers cells';
  }

  static String spacingText(double boxWidth, double boxLength) {
    return '${boxWidth.toStringAsFixed(1)} × ${boxLength.toStringAsFixed(1)} m';
  }

  static int waypointCount(int xLasers, int yLasers) {
    return (xLasers - 1) * (yLasers - 1);
  }
}