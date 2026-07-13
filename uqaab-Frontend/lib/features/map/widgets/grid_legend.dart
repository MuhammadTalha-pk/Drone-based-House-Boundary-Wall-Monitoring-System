import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class GridLegend extends StatelessWidget {
  const GridLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _item(Icons.videocam, 'Camera', AppColors.gridCameraGreen),
        const SizedBox(width: 24),
        _item(Icons.flight, 'Drone', AppColors.gridDroneBlue),
        const SizedBox(width: 24),
        _item(Icons.circle, 'Empty', AppColors.textTertiary),
      ],
    );
  }

  Widget _item(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}