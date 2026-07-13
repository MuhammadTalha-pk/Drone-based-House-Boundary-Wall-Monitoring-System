enum AlertStatus {
  active('active'),
  resolved('resolved'),
  falsePositive('false_positive');

  final String value;
  const AlertStatus(this.value);

  static AlertStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'resolved':
        return AlertStatus.resolved;
      case 'false_positive':
        return AlertStatus.falsePositive;
      default:
        return AlertStatus.active;
    }
  }
}