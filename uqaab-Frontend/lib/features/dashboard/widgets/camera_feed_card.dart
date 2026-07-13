import 'package:flutter/material.dart';
import 'package:uqaab/shared/widgets/mjpeg_stream.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/status_badge.dart';
import '../provider/dashboard_provider.dart';

class CameraFeedCard extends StatelessWidget {
  final CameraFeedData camera;
  final VoidCallback? onTap;

  const CameraFeedCard({
    super.key,
    required this.camera,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final streamUrl = camera.streamUrl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        height: 130,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [

              /// STREAM OR PLACEHOLDER
              Positioned.fill(
                child: (streamUrl != null && streamUrl.isNotEmpty)
                    ? MjpegStream(
                        stream: streamUrl,
                        fit: BoxFit.cover,
                        error: (context, error, stack) =>
                            _buildOfflinePlaceholder(),
                      )
                    : _buildNoStreamPlaceholder(),
              ),

              /// TOP OVERLAY (NAME + LIVE BADGE)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [

                    /// CAMERA NAME
                    Expanded(
                      child: Text(
                        camera.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black54,
                            )
                          ],
                        ),
                      ),
                    ),

                    const LiveBadge(color: AppColors.liveRed),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// NO STREAM STATE
  Widget _buildNoStreamPlaceholder() {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off,
                size: 36, color: AppColors.textSecondary),
            SizedBox(height: 6),
            Text(
              "No Stream",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// CAMERA OFFLINE STATE
  Widget _buildOfflinePlaceholder() {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Text(
          "Camera Offline",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}