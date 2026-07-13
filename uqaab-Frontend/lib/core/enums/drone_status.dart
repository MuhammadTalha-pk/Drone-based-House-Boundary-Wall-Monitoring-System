enum DroneStatus {
  docked('Docked'),
  flying('Flying'),
  offline('Offline'),
  rth('RTH');

  final String label;
  const DroneStatus(this.label);

  static DroneStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'docked':
      case 'ready':
        return DroneStatus.docked;
      case 'flying':
        return DroneStatus.flying;
      case 'rth':
        return DroneStatus.rth;
      default:
        return DroneStatus.offline;
    }
  }
}