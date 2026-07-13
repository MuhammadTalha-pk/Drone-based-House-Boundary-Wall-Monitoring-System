import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/providers/property_context_provider.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../provider/drone_provider.dart';

class DroneManageScreen extends StatefulWidget {
  const DroneManageScreen({super.key});

  @override
  State<DroneManageScreen> createState() => _DroneManageScreenState();
}

class _DroneManageScreenState extends State<DroneManageScreen> {
  @override
  void initState() {
    super.initState();
    final pid = context.read<PropertyContextProvider>().selectedPropertyId;
    if (pid != null) context.read<DroneProvider>().loadDrones(pid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: AppStrings.manageDrones),
      body: Consumer<DroneProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const LoadingWidget();
          if (provider.drones.isEmpty) {
            return const EmptyState(
                icon: Icons.flight_outlined, title: 'No drones added yet');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.drones.length,
            itemBuilder: (context, index) {
              final drone = provider.drones[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(drone.name,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(drone.connectionString,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('Status: ${drone.status}',
                                style: TextStyle(
                                    color:
                                        Helpers.droneStatusColor(drone.status),
                                    fontSize: 12)),
                          ]),
                    ),
                    IconButton(
                        icon: const Icon(Icons.edit,
                            color: AppColors.textSecondary, size: 20),
                        onPressed: () =>
                            context.push('/settings/drones/edit/${drone.id}')),
                    IconButton(
                      icon: const Icon(Icons.delete,
                          color: AppColors.danger, size: 20),
                      onPressed: () async {
                        final confirmed = await ConfirmationDialog.show(context,
                            title: 'Delete Drone',
                            message: 'Delete "${drone.name}"?');
                        if (confirmed == true && mounted) {
                          final pid = context
                              .read<PropertyContextProvider>()
                              .selectedPropertyId;
                          if (pid != null) {
                            await provider.deleteDrone(
                                droneId: drone.id, propertyId: pid);
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => context.push(AppRoutes.addDrone),
          child: const Icon(Icons.add)),
    );
  }
}
