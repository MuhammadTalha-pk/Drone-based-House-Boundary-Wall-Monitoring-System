import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/camera_model.dart';
import '../../../models/drone_model.dart';

class GridCellWidget extends StatelessWidget {
  final int row;
  final int col;
  final List<CameraModel> cameras;
  final List<DroneModel> drones;

  const GridCellWidget({
    super.key,
    required this.row,
    required this.col,
    required this.cameras,
    required this.drones,
  });

  @override
  Widget build(BuildContext context) {
    final hasDrone = drones.any(
        (d) => d.homeCell.row == row && d.homeCell.col == col);
    final hasCamera = cameras.any(
        (c) => c.gridCell.row == row && c.gridCell.col == col);

    Color cellColor = AppColors.gridEmpty;
    IconData? icon;
    Color iconColor = AppColors.textSecondary;

    if (hasDrone) {
      cellColor = AppColors.gridDroneBlue.withOpacity(0.3);
      icon = Icons.flight;
      iconColor = AppColors.gridDroneBlue;
    } else if (hasCamera) {
      cellColor = AppColors.gridCameraGreen.withOpacity(0.3);
      icon = Icons.videocam;
      iconColor = AppColors.gridCameraGreen;
    }

    return GestureDetector(
      onTap: () {
        if (hasDrone) {
          final drone = drones.firstWhere(
              (d) => d.homeCell.row == row && d.homeCell.col == col);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🚁 Drone — ${drone.name} — Cell $col,$row'),
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (hasCamera) {
          final cam = cameras.firstWhere(
              (c) => c.gridCell.row == row && c.gridCell.col == col);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📷 Camera — ${cam.name} — Cell $col,$row'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: icon != null
            ? Center(child: Icon(icon, color: iconColor, size: 24))
            : Center(
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.textTertiary.withOpacity(0.5),
                  ),
                ),
              ),
      ),
    );
  }
}