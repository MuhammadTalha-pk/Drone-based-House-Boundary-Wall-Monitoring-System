import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/providers/property_context_provider.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../auth/provider/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final propertyId =
        context.read<PropertyContextProvider>().selectedPropertyId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: AppStrings.settingsProperty),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _settingsItem(
            icon: Icons.videocam_outlined,
            title: AppStrings.manageCameras,
            onTap: () => context.push(AppRoutes.manageCameras),
          ),
          _settingsItem(
            icon: Icons.flight_outlined,
            title: AppStrings.manageDrones,
            onTap: () => context.push(AppRoutes.manageDrones),
          ),
          _settingsItem(
            icon: Icons.people_outlined,
            title: AppStrings.authorizedPeople,
            onTap: () => context.push(AppRoutes.authorizedPeople),
          ),
          _settingsItem(
            icon: Icons.list_alt,
            title: AppStrings.flightLogs,
            onTap: () => context.push(AppRoutes.flightLogs),
          ),
          _settingsItem(
            icon: Icons.grid_view,
            title: AppStrings.laserGridView,
            onTap: () {
              _showLaserGridView(context);
            },
          ),
          _settingsItem(
            icon: Icons.home_outlined,
            title: AppStrings.managePropertyDetails,
            onTap: () {
              if (propertyId != null) {
                context.push('/properties/edit/$propertyId');
              }
            },
          ),
          const Divider(color: AppColors.surfaceBorder, height: 32),
          _settingsItem(
            icon: Icons.logout,
            title: AppStrings.logout,
            titleColor: AppColors.textDanger,
            onTap: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _settingsItem({
    required IconData icon,
    required String title,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? AppColors.primary),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: title != AppStrings.logout
          ? const Icon(Icons.chevron_right, color: AppColors.textSecondary)
          : null,
      onTap: onTap,
    );
  }

  void _showLaserGridView(BuildContext context) {
    final property =
        context.read<PropertyContextProvider>().selectedProperty;

    if (property == null) return;

    final grid = property.laserGrid;
    final waypoints = (grid.xLasers - 1) * (grid.yLasers - 1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  const Text(
                    'Laser Grid View',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      _statCard('Grid Size',
                          '${grid.xLasers} × ${grid.yLasers} lasers'),
                      const SizedBox(width: 8),
                      _statCard(
                          'Spacing', '${grid.boxWidth}×${grid.boxLength} m'),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      _statCard('Waypoints', '$waypoints points'),
                      const SizedBox(width: 8),
                      _statCard('Height', '${grid.gridHeight} m'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  /// GRID LAYOUT
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Grid Layout",
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        const SizedBox(height: 16),

                        AspectRatio(
                          aspectRatio: 1,
                          child: CustomPaint(
                            painter: GridPainter(
                              rows: grid.yLasers,
                              cols: grid.xLasers,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _LegendDot(color: Colors.red, label: 'X'),
                            SizedBox(width: 16),
                            _LegendDot(color: Colors.green, label: 'Y'),
                            SizedBox(width: 16),
                            _LegendDot(color: Colors.blue, label: 'WP'),
                          ],
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// FLIGHT PATH
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.flight,
                                color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Drone Flight Path',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Drone flies at ${grid.gridHeight}m height through $waypoints waypoints. '
                          'Grid spacing is ${grid.boxWidth}m × ${grid.boxLength}m.',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

/// GRID PAINTER

class GridPainter extends CustomPainter {
  final int rows;
  final int cols;

  GridPainter({required this.rows, required this.cols});

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    final xPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1;

    final yPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 1;

    final waypointPaint = Paint()..color = Colors.blue;

    for (int c = 0; c <= cols; c++) {
      final x = c * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), xPaint);
    }

    for (int r = 0; r <= rows; r++) {
      final y = r * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), yPaint);
    }

    for (int r = 0; r <= rows; r++) {
      for (int c = 0; c <= cols; c++) {
        canvas.drawCircle(
            Offset(c * cellWidth, r * cellHeight), 3, waypointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}