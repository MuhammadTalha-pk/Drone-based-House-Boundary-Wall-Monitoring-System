import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart'; // <--- ADDED MJPEG
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/status_badge.dart';
import '../provider/dashboard_provider.dart';

class DroneFeedCard extends StatelessWidget {
  final DroneFeedData drone;

  const DroneFeedCard({super.key, required this.drone});

  @override
  Widget build(BuildContext context) {
    // Check if the backend actually gave us a stream URL
    final hasStream =
        drone.streamUrl != null && drone.streamUrl!.trim().isNotEmpty;

    return GestureDetector(
      // NOTE: You can change this later to navigate to AppRoutes.droneControl!
      onTap: () => _showComingSoon(context),
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 12),
        clipBehavior: Clip.hardEdge, // <--- Keeps video inside rounded corners
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            /// 1. THE ACTUAL VIDEO STREAM (If Available)
            if (hasStream)
              Mjpeg(
                isLive: true,
                stream: drone.streamUrl!,
                fit: BoxFit.cover,
                error: (context, error, stack) => const Center(
                  child:
                      Icon(Icons.broken_image, color: Colors.white54, size: 40),
                ),
                loading: (context) => const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2),
                ),
              )
            else

              /// 2. PLACEHOLDER (If no stream URL)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.flight,
                      size: 40,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      drone.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'FPV Feed Offline',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            /// 3. NAME OVERLAY (So you can read the drone name over the video)
            if (hasStream)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent
                      ],
                    ),
                  ),
                  child: Text(
                    drone.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            /// 4. LIVE Badge
            if (drone.isOnline)
              const Positioned(
                top: 8,
                right: 8,
                child: LiveBadge(
                  color: AppColors.liveGreen,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet message
  void _showComingSoon(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flight, size: 40, color: AppColors.primary),
              SizedBox(height: 12),
              Text(
                "Drone FPV Stream",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Navigating to drone controls coming soon.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
