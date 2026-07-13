// lib/features/alerts/screens/alert_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/property_context_provider.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/video_player_widget.dart';
import '../provider/alert_provider.dart';
import '../../flight_logs/provider/flight_log_provider.dart';
import '../../drones/provider/drone_provider.dart';
import '../../dashboard/provider/dashboard_provider.dart';
import '../../cameras/screens/camera_live_screen.dart';
import '../../../models/alert_model.dart';

class AlertDetailScreen extends StatefulWidget {
  final String alertId;

  const AlertDetailScreen({super.key, required this.alertId});

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAlert();
    });
  }

  void _loadAlert() {
    context.read<AlertProvider>().loadAlertDetail(widget.alertId);
  }

  void _viewLiveCamera(AlertModel alert) {
    final dashboard = context.read<DashboardProvider>().dashboardData;
    final camera =
        dashboard?.cameras.where((c) => c.name == alert.cameraName).firstOrNull;

    if (camera != null &&
        camera.streamUrl != null &&
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
    } else {
      Helpers.showErrorSnackBar(
          context, 'Live stream is currently offline for this camera.');
    }
  }

  Future<void> _dispatchDrone() async {
    final propertyId =
        context.read<PropertyContextProvider>().selectedPropertyId;
    if (propertyId == null) return;

    final drones = context.read<DroneProvider>().drones;
    final droneName = drones.isNotEmpty ? drones.first.name : 'Eagle 1';

    final success = await context.read<FlightLogProvider>().createFlightLog(
          propertyId: propertyId,
          droneName: droneName,
          flightType: 'DISPATCH',
          takeoffTime: DateTime.now().toIso8601String(),
          landTime:
              DateTime.now().add(const Duration(minutes: 2)).toIso8601String(),
        );

    if (!mounted) return;
    if (success) {
      Helpers.showSuccessSnackBar(
          context, 'Drone dispatched to alert location!');
    }
  }

  Future<void> _markFalsePositive() async {
    final success =
        await context.read<AlertProvider>().markAsFalsePositive(widget.alertId);
    if (!mounted) return;
    if (success) {
      Helpers.showSuccessSnackBar(context, 'Marked as false positive');
      Navigator.of(context).pop();
    }
  }

  Future<void> _resolveAlert() async {
    final success =
        await context.read<AlertProvider>().resolveAlert(widget.alertId);
    if (!mounted) return;
    if (success) {
      Helpers.showSuccessSnackBar(context, 'Alert resolved');
      Navigator.of(context).pop();
    }
  }

  // ─── URL Fix Helper ────────────────────────────────────────────────────────
  // This forces "video" to "videos" and "snapshot" to "snapshots"
  String? _fixMediaUrl(String? originalPath) {
    if (originalPath == null || originalPath.isEmpty) return null;

    // First, fix the typos in the path
    String fixedPath = originalPath
        .replaceFirst('/static/video/', '/static/videos/')
        .replaceFirst('/static/snapshot/', '/static/snapshots/');

    // Then apply the base URL
    return AppConfig.mediaUrl(fixedPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Alert Detail'),
      body: Consumer<AlertProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const LoadingWidget();

          if (provider.hasError) {
            return ErrorState(
              message: provider.errorMessage,
              onRetry: _loadAlert,
            );
          }

          final alert = provider.selectedAlert;
          if (alert == null) return const SizedBox.shrink();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Severity Banner ───────────────────────────────────
                _buildSeverityBanner(alert),
                const SizedBox(height: 16),

                // ── Face Image ────────────────────────────────────────
                if (alert.isFaceAlert && alert.hasFaceImage) ...[
                  const Text(
                    'Detected Face',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildFaceImage(alert.faceImageUrl!),
                  const SizedBox(height: 16),
                ],

                // ── Video / Snapshot ──────────────────────────────────
                if (alert.hasVideo) ...[
                  const Text(
                    'Event Recording (5s)',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  VideoPlayerWidget(
                    // Use the helper to fix the URLs before passing them
                    streamUrl: _fixMediaUrl(alert.clipUrl),
                    thumbnailUrl: _fixMediaUrl(alert.imageUrl),
                    placeholder: 'Alert #${alert.id}',
                    height: 240,
                  ),
                ] else if (alert.hasSnapshot) ...[
                  const Text(
                    'Event Snapshot',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildSnapshotView(alert),
                ] else ...[
                  const VideoPlayerWidget(
                    streamUrl: null,
                    placeholder: 'Event Clip',
                    height: 200,
                  ),
                ],

                const SizedBox(height: 16),

                // ── Multi-camera path ─────────────────────────────────
                if (alert.isMultiCamera) ...[
                  _buildCameraPathCard(alert),
                  const SizedBox(height: 16),
                ],

                // ── Tracking ID ───────────────────────────────────────
                if (alert.trackingId != null) ...[
                  _buildTrackingCard(alert.trackingId!),
                  const SizedBox(height: 16),
                ],

                // ── Details Card ──────────────────────────────────────
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
                      Row(
                        children: [
                          Icon(
                            _alertTypeIcon(alert.type),
                            color: Helpers.severityColor(alert.severity),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alert.type,
                              style: TextStyle(
                                color: Helpers.severityColor(alert.severity),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _detailRow('Camera', alert.cameraName),
                      const SizedBox(height: 6),
                      _detailRow('Grid Pos',
                          'Row ${alert.cameraCell.row}, Col ${alert.cameraCell.col}'),
                      const SizedBox(height: 6),
                      if (alert.detectedCell != null &&
                          alert.detectedCell!.isNotEmpty) ...[
                        _detailRow('Detected In', alert.detectedCell!),
                        const SizedBox(height: 6),
                      ],
                      _detailRow('Time', alert.formattedTimestamp),
                      const SizedBox(height: 6),
                      _detailRow('Confidence', '${alert.confidence}%'),
                      const SizedBox(height: 6),
                      _detailRow('Severity', alert.severity.toUpperCase()),
                      const SizedBox(height: 6),
                      _detailRow('Status', alert.isRead ? 'Read' : 'Unread'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Action Buttons ────────────────────────────────────
                _buildActionButtons(alert),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Face image ──────────────────────────────────────────────────────────
  Widget _buildFaceImage(String url) {
    final fullUrl = AppConfig.mediaUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: fullUrl,
        width: 130,
        height: 130,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
          width: 130,
          height: 130,
          color: AppColors.surface,
          child: const Icon(Icons.broken_image,
              color: AppColors.textSecondary, size: 40),
        ),
      ),
    );
  }

  // ─── Snapshot ────────────────────────────────────────────────────────────
  Widget _buildSnapshotView(AlertModel alert) {
    // Use the helper to fix the snapshot URL
    final fullUrl = _fixMediaUrl(alert.imageUrl) ?? '';

    debugPrint('📸 Snapshot URL: $fullUrl');

    if (fullUrl.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Icon(Icons.broken_image,
              color: AppColors.textSecondary, size: 40),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: fullUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 180,
          color: AppColors.surface,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, __, error) {
          debugPrint('❌ Snapshot load error: $error for URL: $fullUrl');
          return Container(
            height: 180,
            color: AppColors.surface,
            child: const Center(
              child: Icon(Icons.broken_image,
                  color: AppColors.textSecondary, size: 40),
            ),
          );
        },
      ),
    );
  }

  // ─── Tracking ID card ─────────────────────────────────────────────────────
  Widget _buildTrackingCard(String trackingId) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.track_changes,
              color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tracking ID',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 2),
              SelectableText(
                trackingId,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Camera path card ────────────────────────────────────────────────────
  Widget _buildCameraPathCard(AlertModel alert) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Camera Path',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: alert.cameraPath
                .map((cam) => Chip(
                      label: Text(cam,
                          style: const TextStyle(color: AppColors.textPrimary)),
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.surfaceBorder),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ─── Severity banner ─────────────────────────────────────────────────────
  Widget _buildSeverityBanner(AlertModel alert) {
    final color = Helpers.severityColor(alert.severity);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            alert.severity.toUpperCase(),
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const Spacer(),
          if (!alert.isRead)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('UNREAD',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  // ─── Action buttons ──────────────────────────────────────────────────────
  Widget _buildActionButtons(AlertModel alert) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: 'VIEW LIVE CAMERA',
                onPressed: () => _viewLiveCamera(alert),
                icon: Icons.videocam,
                backgroundColor: AppColors.primary,
                textColor: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: 'DISPATCH DRONE',
                onPressed: _dispatchDrone,
                icon: Icons.flight,
                backgroundColor: AppColors.dispatch,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.warning),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: _markFalsePositive,
                icon: const Icon(Icons.thumb_down_outlined,
                    color: AppColors.warning, size: 18),
                label: const Text('False Positive',
                    style: TextStyle(color: AppColors.warning, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.success),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: _resolveAlert,
                icon: const Icon(Icons.check_circle_outline,
                    color: AppColors.success, size: 18),
                label: const Text('Resolve',
                    style: TextStyle(color: AppColors.success, fontSize: 13)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text('$label:',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  IconData _alertTypeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('face') ||
        t.contains('unauthorized') ||
        t.contains('entrance')) {
      return Icons.face_retouching_natural;
    }
    if (t.contains('weapon')) return Icons.gpp_bad;
    if (t.contains('vehicle')) return Icons.directions_car;
    if (t.contains('climbing') || t.contains('fence')) return Icons.fence;
    return Icons.security;
  }
}
