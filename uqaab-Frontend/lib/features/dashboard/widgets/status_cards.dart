import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // <--- ADDED GOROUTER
import '../../../core/routes/app_routes.dart'; // <--- ADDED ROUTES
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/info_card.dart';

class StatusCards extends StatelessWidget {
  final String droneStatus;
  final int camerasOnline;
  final int camerasTotal;
  final int newAlerts;
  final VoidCallback? onDroneTap;

  const StatusCards({
    super.key,
    required this.droneStatus,
    required this.camerasOnline,
    required this.camerasTotal,
    required this.newAlerts,
    this.onDroneTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // DRONE CARD
        Expanded(
          child: SizedBox(
            height: 92,
            child: InfoCard(
              title: 'Drone',
              value: droneStatus,
              valueColor: Helpers.droneStatusColor(droneStatus),
              icon: Icons.flight,
              onTap: onDroneTap,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // CAMERAS CARD
        Expanded(
          child: SizedBox(
            height: 92,
            child: InfoCard(
              title: 'Cameras',
              value: Formatters.camerasOnlineText(camerasOnline, camerasTotal),
              valueColor: AppColors.success,
              icon: Icons.videocam,
              onTap: () => context
                  .push(AppRoutes.manageCameras), // <--- ADDED NAVIGATION
            ),
          ),
        ),
        const SizedBox(width: 8),

        // ALERTS CARD
        Expanded(
          child: SizedBox(
            height: 92,
            child: InfoCard(
              title: 'Alerts',
              value: Formatters.alertCountText(newAlerts),
              valueColor: newAlerts > 0 ? AppColors.danger : AppColors.success,
              icon: Icons.notifications,
              onTap: () =>
                  context.push(AppRoutes.alerts), // <--- ADDED NAVIGATION
            ),
          ),
        ),
      ],
    );
  }
}
