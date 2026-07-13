import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/alert_model.dart';

class AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback? onTap;

  const AlertCard({super.key, required this.alert, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: alert.isRead
                ? AppColors.surfaceBorder
                : Helpers.severityColor(alert.severity).withOpacity(0.4),
          ),
        ),
        child: Row(
          children: [
            // Thumbnail - show snapshot if available
            _buildThumbnail(),
            const SizedBox(width: 12),

            // Alert details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Alert type with severity indicator
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Helpers.severityColor(alert.severity),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          alert.type,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Camera name (shows path for multi-camera)
                  _buildCameraInfo(),
                  const SizedBox(height: 2),

                  // Timestamp and confidence
                  Row(
                    children: [
                      Text(
                        alert.formattedTimestamp,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Helpers.confidenceColor(alert.confidence)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${alert.confidence}%',
                          style: TextStyle(
                            color: Helpers.confidenceColor(alert.confidence),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Unread dot + chevron
            Column(
              children: [
                if (!alert.isRead)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success,
                    ),
                  ),
                // Video icon if clip available
                if (alert.hasVideo)
                  const Icon(
                    Icons.play_circle_filled,
                    color: AppColors.primary,
                    size: 20,
                  )
                else
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build thumbnail widget - snapshot image or fallback icon
  Widget _buildThumbnail() {
    if (alert.hasSnapshot) {
      final imageUrl = AppConfig.mediaUrl(alert.imageUrl);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.surfaceLight,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildFallbackIcon(),
              ),
              // Play button overlay if video available
              if (alert.hasVideo)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return _buildFallbackIcon();
  }

  /// Fallback icon when no snapshot is available
  Widget _buildFallbackIcon() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Helpers.severityColor(alert.severity).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _alertTypeIcon,
        color: Helpers.severityColor(alert.severity),
        size: 28,
      ),
    );
  }

  /// Build camera info - shows path for multi-camera alerts
  Widget _buildCameraInfo() {
    if (alert.isMultiCamera) {
      return Row(
        children: [
          const Icon(
            Icons.route,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              alert.cameraName,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${alert.cameraPath.length} cams',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      'Camera: ${alert.cameraName}',
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
      ),
    );
  }

  /// Get icon based on alert type
  IconData get _alertTypeIcon {
    switch (alert.type.toLowerCase()) {
      case 'weapon detected':
        return Icons.warning_amber_rounded;
      case 'unauthorized person':
        return Icons.person_off;
      default:
        return Icons.shield;
    }
  }
}