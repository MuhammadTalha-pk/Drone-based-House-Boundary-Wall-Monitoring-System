// lib/features/cameras/screens/camera_live_screen.dart
import 'package:flutter/material.dart';
import 'package:uqaab/core/constants/app_colors.dart';
import 'package:uqaab/shared/widgets/custom_app_bar.dart';
import 'package:uqaab/shared/widgets/status_badge.dart';
import 'package:uqaab/shared/widgets/mjpeg_stream.dart';

/// Full-screen MJPEG live view for a camera.
/// Launched when user taps a camera feed card on the dashboard.
class CameraLiveScreen extends StatelessWidget {
  final String cameraName;
  final String streamUrl;

  const CameraLiveScreen({
    super.key,
    required this.cameraName,
    required this.streamUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CustomAppBar(
        title: cameraName,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: LiveBadge(color: AppColors.liveRed),
          ),
        ],
      ),
      body: Center(
        child: MjpegStream(
          stream: streamUrl,
          fit: BoxFit.contain,
          error: (context, error, stack) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white54, size: 60),
              const SizedBox(height: 12),
              Text(
                'Cannot connect to camera\n$cameraName',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}