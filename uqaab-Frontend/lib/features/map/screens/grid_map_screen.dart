import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/property_context_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../cameras/provider/camera_provider.dart';
import '../../drones/provider/drone_provider.dart';
import '../widgets/grid_cell.dart';
import '../widgets/grid_legend.dart';

class GridMapScreen extends StatefulWidget {
  const GridMapScreen({super.key});

  @override
  State<GridMapScreen> createState() => _GridMapScreenState();
}

class _GridMapScreenState extends State<GridMapScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final propertyId =
        context.read<PropertyContextProvider>().selectedPropertyId;
    if (propertyId != null) {
      context.read<CameraProvider>().loadCameras(propertyId);
      context.read<DroneProvider>().loadDrones(propertyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final property =
        context.watch<PropertyContextProvider>().selectedProperty;
    if (property == null) return const SizedBox.shrink();

    final grid = property.laserGrid;
    final cols = grid.xLasers;
    final rows = grid.yLasers;
    final waypoints = Formatters.waypointCount(cols, rows);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Grid Map',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text(
              '$cols × $rows cells • $waypoints waypoints',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
      body: Consumer2<CameraProvider, DroneProvider>(
        builder: (context, camProvider, droneProvider, _) {
          if (camProvider.isLoading || droneProvider.isLoading) {
            return const LoadingWidget();
          }

          final cameras = camProvider.cameras;
          final drones = droneProvider.drones;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grid
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Column headers
                      Row(
                        children: [
                          const SizedBox(width: 32),
                          for (int c = 0; c < cols; c++)
                            SizedBox(
                              width: 60,
                              child: Center(
                                child: Text('$c',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Grid rows
                      for (int r = 0; r < rows; r++)
                        Row(
                          children: [
                            SizedBox(
                              width: 32,
                              child: Center(
                                child: Text('$r',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                              ),
                            ),
                            for (int c = 0; c < cols; c++)
                              GridCellWidget(
                                row: r,
                                col: c,
                                cameras: cameras,
                                drones: drones,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Legend
                const GridLegend(),
                const SizedBox(height: 16),

                // Drones section
                if (drones.isNotEmpty) ...[
                  const Text('Drones',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...drones.map((d) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.gridDroneBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${d.name} — Home: Cell ${d.homeCell.col},${d.homeCell.row}',
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      )),
                ],
                const SizedBox(height: 8),

                // Cameras section
                if (cameras.isNotEmpty) ...[
                  const Text('Cameras',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...cameras.map((c) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.gridCameraGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${c.name} — Cell ${c.gridCell.col},${c.gridCell.row}',
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}