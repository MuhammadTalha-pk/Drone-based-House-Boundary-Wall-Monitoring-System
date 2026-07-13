// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:provider/provider.dart';

// import '../../../core/constants/app_colors.dart';
// import '../../../core/constants/app_strings.dart';
// import '../../../core/routes/app_routes.dart';
// import '../../../core/providers/property_context_provider.dart';

// import '../../../shared/widgets/loading_widget.dart';
// import '../../../shared/widgets/error_state.dart';

// import '../../cameras/screens/camera_live_screen.dart';

// import '../provider/dashboard_provider.dart';
// import '../widgets/status_cards.dart';
// import '../widgets/camera_feed_card.dart';
// import '../widgets/drone_feed_card.dart';

// class DashboardScreen extends StatefulWidget {
//   const DashboardScreen({super.key});

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   @override
//   void initState() {
//     super.initState();
//     // ✅ FIX: Delay until after build completes
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _loadDashboard();
//     });
//   }

//   void _loadDashboard() {
//     if (!mounted) return;

//     final propertyId =
//         context.read<PropertyContextProvider>().selectedPropertyId;

//     if (propertyId != null) {
//       context.read<DashboardProvider>().loadDashboard(propertyId);
//     }
//   }

//   void _showDroneStatusDialog() {
//     final propertyId =
//         context.read<PropertyContextProvider>().selectedPropertyId;
//     final dashboard = context.read<DashboardProvider>().dashboardData;

//     if (propertyId == null || dashboard == null) return;

//     showModalBottomSheet(
//       context: context,
//       backgroundColor: AppColors.surface,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (ctx) {
//         final isDocked = dashboard.droneStatus == 'Docked' ||
//             dashboard.droneStatus == 'Ready';

//         return Padding(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Text(
//                 'Drone Status',
//                 style: TextStyle(
//                   color: AppColors.textPrimary,
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 'Current status: ${dashboard.droneStatus}',
//                 style: const TextStyle(
//                   color: AppColors.textSecondary,
//                   fontSize: 16,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     'Set to Docked',
//                     style: TextStyle(color: AppColors.textPrimary),
//                   ),
//                   Switch(
//                     value: isDocked,
//                     activeThumbColor: AppColors.danger,
//                     onChanged: (val) async {
//                       final provider = context.read<DashboardProvider>();
//                       await provider.toggleDroneStatus(propertyId);
//                       Navigator.of(ctx).pop();
//                       _loadDashboard();
//                     },
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 8),
//               Row(
//                 children: [
//                   Container(
//                     width: 8,
//                     height: 8,
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: isDocked ? AppColors.success : AppColors.danger,
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   Text(
//                     isDocked ? 'Drone is docked' : 'Drone is offline',
//                     style: TextStyle(
//                       color: isDocked ? AppColors.success : AppColors.danger,
//                       fontSize: 14,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 20),
//               TextButton(
//                 onPressed: () => Navigator.of(ctx).pop(),
//                 child: const Text(
//                   'Close',
//                   style: TextStyle(color: AppColors.primary),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       body: Consumer<DashboardProvider>(
//         builder: (context, provider, _) {
//           if (provider.isLoading && provider.dashboardData == null) {
//             return const LoadingWidget(message: 'Loading dashboard...');
//           }

//           if (provider.hasError && provider.dashboardData == null) {
//             return ErrorState(
//               message: provider.errorMessage,
//               onRetry: _loadDashboard,
//             );
//           }

//           final data = provider.dashboardData;

//           if (data == null) return const SizedBox.shrink();

//           return RefreshIndicator(
//             onRefresh: () async => _loadDashboard(),
//             child: SingleChildScrollView(
//               physics: const AlwaysScrollableScrollPhysics(),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   /// HEADER
//                   SafeArea(
//                     child: Padding(
//                       padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             data.propertyName,
//                             style: const TextStyle(
//                               color: AppColors.textPrimary,
//                               fontSize: 24,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           IconButton(
//                             icon: const Icon(
//                               Icons.settings,
//                               color: AppColors.textSecondary,
//                             ),
//                             onPressed: () => context.push(AppRoutes.settings),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),

//                   /// STATUS CARDS
//                   Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: StatusCards(
//                       droneStatus: data.droneStatus,
//                       camerasOnline: data.camerasOnline,
//                       camerasTotal: data.camerasTotal,
//                       newAlerts: data.newAlertsCount,
//                       onDroneTap: _showDroneStatusDialog,
//                     ),
//                   ),

//                   /// DRONE FEEDS
//                   if (data.drones.isNotEmpty) ...[
//                     const Padding(
//                       padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
//                       child: Text(
//                         AppStrings.droneLiveFeeds,
//                         style: TextStyle(
//                           color: AppColors.textPrimary,
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                     SizedBox(
//                       height: 160,
//                       child: ListView.builder(
//                         scrollDirection: Axis.horizontal,
//                         padding: const EdgeInsets.symmetric(horizontal: 16),
//                         itemCount: data.drones.length,
//                         itemBuilder: (context, index) {
//                           return DroneFeedCard(
//                             drone: data.drones[index],
//                           );
//                         },
//                       ),
//                     ),
//                   ],

//                   /// CAMERA FEEDS
//                   if (data.cameras.isNotEmpty) ...[
//                     const Padding(
//                       padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
//                       child: Text(
//                         AppStrings.liveCameraFeeds,
//                         style: TextStyle(
//                           color: AppColors.textPrimary,
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                     SizedBox(
//                       height: 160,
//                       child: ListView.builder(
//                         scrollDirection: Axis.horizontal,
//                         padding: const EdgeInsets.symmetric(horizontal: 16),
//                         itemCount: data.cameras.length,
//                         itemBuilder: (context, index) {
//                           final camera = data.cameras[index];
//                           return GestureDetector(
//                             onTap: () {
//                               if (camera.streamUrl != null &&
//                                   camera.streamUrl!.isNotEmpty) {
//                                 Navigator.push(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (_) => CameraLiveScreen(
//                                       cameraName: camera.name,
//                                       streamUrl: camera.streamUrl!,
//                                     ),
//                                   ),
//                                 );
//                               }
//                             },
//                             child: CameraFeedCard(camera: camera),
//                           );
//                         },
//                       ),
//                     ),
//                   ],

//                   const SizedBox(height: 24),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/providers/property_context_provider.dart';

import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/error_state.dart';

import '../../cameras/screens/camera_live_screen.dart';
import '../../alerts/provider/alert_provider.dart';

import '../provider/dashboard_provider.dart';
import '../widgets/status_cards.dart';
import '../widgets/camera_feed_card.dart';
import '../widgets/drone_feed_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboard();
    });
  }

  void _loadDashboard() {
    if (!mounted) return;

    final propertyId =
        context.read<PropertyContextProvider>().selectedPropertyId;

    if (propertyId != null) {
      context.read<DashboardProvider>().loadDashboard(propertyId);
    }
  }

  void _showDroneStatusDialog() {
    final propertyId =
        context.read<PropertyContextProvider>().selectedPropertyId;
    final dashboard = context.read<DashboardProvider>().dashboardData;

    if (propertyId == null || dashboard == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDocked = dashboard.droneStatus == 'Docked' ||
            dashboard.droneStatus == 'Ready';

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Drone Status',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Current status: ${dashboard.droneStatus}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Set to Docked',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  Switch(
                    value: isDocked,
                    activeThumbColor: AppColors.danger,
                    onChanged: (val) async {
                      final provider = context.read<DashboardProvider>();
                      await provider.toggleDroneStatus(propertyId);
                      Navigator.of(ctx).pop();
                      _loadDashboard();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDocked ? AppColors.success : AppColors.danger,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isDocked ? 'Drone is docked' : 'Drone is offline',
                    style: TextStyle(
                      color: isDocked ? AppColors.success : AppColors.danger,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLatestAlertBanner() {
    return Consumer<AlertProvider>(
      builder: (context, alertProvider, _) {
        final latest = alertProvider.latestAlert;
        if (latest == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            context.read<AlertProvider>().clearLatestAlert(); // ← clear banner
            context.push('/alerts/${latest.id}');
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest.type,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${latest.cameraName} · ${latest.formattedTimestamp}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<DashboardProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.dashboardData == null) {
            return const LoadingWidget(message: 'Loading dashboard...');
          }

          if (provider.hasError && provider.dashboardData == null) {
            return ErrorState(
              message: provider.errorMessage,
              onRetry: _loadDashboard,
            );
          }

          final data = provider.dashboardData;
          if (data == null) return const SizedBox.shrink();

          return RefreshIndicator(
            onRefresh: () async => _loadDashboard(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// HEADER
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            data.propertyName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.settings,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () => context.push(AppRoutes.settings),
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// LATEST ALERT BANNER
                  _buildLatestAlertBanner(),

                  /// STATUS CARDS
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: StatusCards(
                      droneStatus: data.droneStatus,
                      camerasOnline: data.camerasOnline,
                      camerasTotal: data.camerasTotal,
                      newAlerts: data.newAlertsCount,
                      onDroneTap: _showDroneStatusDialog,
                    ),
                  ),

                  /// DRONE FEEDS
                  if (data.drones.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        AppStrings.droneLiveFeeds,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: data.drones.length,
                        itemBuilder: (context, index) {
                          return DroneFeedCard(drone: data.drones[index]);
                        },
                      ),
                    ),
                  ],

                  /// CAMERA FEEDS
                  if (data.cameras.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        AppStrings.liveCameraFeeds,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: data.cameras.length,
                        itemBuilder: (context, index) {
                          final camera = data.cameras[index];
                          return GestureDetector(
                            onTap: () {
                              if (camera.streamUrl != null &&
                                  camera.streamUrl!.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CameraLiveScreen(
                                      cameraName: camera.name,
                                      streamUrl: camera.streamUrl!,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: CameraFeedCard(camera: camera),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
