import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../enums/drone_status.dart';

class Helpers {
  static Color droneStatusColor(String status) {
    switch (DroneStatus.fromString(status)) {
      case DroneStatus.docked:
        return AppColors.success;
      case DroneStatus.flying:
        return AppColors.droneFlying;
      case DroneStatus.rth:
        return AppColors.warning;
      case DroneStatus.offline:
        return AppColors.danger;
    }
  }

  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return AppColors.danger;
      case 'high':
        return AppColors.dispatch;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  static Color confidenceColor(int confidence) {
    if (confidence >= 80) return AppColors.warning;
    if (confidence >= 50) return AppColors.warning;
    return AppColors.textSecondary;
  }

  static void showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.surface,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor:
            Colors.red.shade700, // Or AppColors.danger if you have it!
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
