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
import '../provider/camera_provider.dart';

class CameraManageScreen extends StatefulWidget {
  const CameraManageScreen({super.key});

  @override
  State<CameraManageScreen> createState() => _CameraManageScreenState();
}

class _CameraManageScreenState extends State<CameraManageScreen> {
  String _filter = 'all'; // all | entrance | insider | fence

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final pid = context.read<PropertyContextProvider>().selectedPropertyId;
    if (pid != null) context.read<CameraProvider>().loadCameras(pid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: AppStrings.manageCameras),
      body: Consumer<CameraProvider>(builder: (context, provider, _) {
        if (provider.isLoading) return const LoadingWidget();
        if (provider.cameras.isEmpty) {
          return const EmptyState(
            icon: Icons.videocam_off,
            title: 'No cameras added yet',
          );
        }

        final cameras = _filteredCameras(provider.cameras);

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: cameras.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    _buildFilterButton('all', 'ALL'),
                    const SizedBox(width: 8),
                    _buildFilterButton('entrance', 'ENTRANCE'),
                    const SizedBox(width: 8),
                    _buildFilterButton('insider', 'INSIDER'),
                    const SizedBox(width: 8),
                    _buildFilterButton('fence', 'FENCE'),
                  ],
                ),
              );
            }

            final cam = cameras[index - 1];
            return _buildCameraCard(cam);
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addCamera),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterButton(String key, String label) {
    final active = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.textOnDark : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<dynamic> _filteredCameras(List<dynamic> cameras) {
    return cameras.where((cam) {
      if (_filter == 'all') return true;
      return (cam.cameraType ?? '').toString().toLowerCase() == _filter;
    }).toList();
  }

  Widget _buildCameraCard(dynamic cam) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cam.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cam.isOnline == true
                            ? AppColors.success
                            : AppColors.danger,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        cam.isOnline == true ? 'ONLINE' : 'OFFLINE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert,
                          color: AppColors.textSecondary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) {
                        if (value == 'edit') {
                          context.push('/settings/cameras/edit/${cam.id}');
                        } else if (value == 'delete') {
                          _deleteCamera(cam);
                        } else if (value == 'polygon') {
                          context.push(
                              '/cameras/calibrate/${cam.id}?name=${Uri.encodeComponent(cam.name)}&mode=update');
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  (cam.cameraType ?? '').toString().toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cam.rtspUrl ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCamera(dynamic cam) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Camera',
      message: 'Are you sure you want to delete "${cam.name}"?',
    );
    if (confirmed == true && mounted) {
      final pid = context.read<PropertyContextProvider>().selectedPropertyId;
      if (pid != null) {
        final success = await context
            .read<CameraProvider>()
            .deleteCamera(cameraId: cam.id, propertyId: pid);
        if (mounted && success) {
          Helpers.showSuccessSnackBar(context, 'Camera deleted');
        }
      }
    }
  }
}
