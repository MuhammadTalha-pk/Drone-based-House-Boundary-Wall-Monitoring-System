import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String? streamUrl;
  final String? thumbnailUrl;
  final String placeholder;
  final double? height;
  final bool autoPlay;

  const VideoPlayerWidget({
    super.key,
    this.streamUrl,
    this.thumbnailUrl,
    this.placeholder = 'Event Clip',
    this.height,
    this.autoPlay = false,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay && widget.streamUrl != null) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _disposeControllers();
      if (widget.autoPlay && widget.streamUrl != null) {
        _initializeVideo();
      } else {
        setState(() {
          _isInitialized = false;
          _hasError = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeVideo() async {
    if (widget.streamUrl == null || widget.streamUrl!.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // URL is already fully built by the caller (AppConfig.mediaUrl applied upstream)
      final url = widget.streamUrl!;
      debugPrint('🎬 Loading video: $url');

      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(url),
      );

      await _videoController!.initialize();

      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
        showOptions: false,
        aspectRatio: _videoController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return _buildErrorState('Playback error');
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          backgroundColor: AppColors.surfaceLight,
          bufferedColor: AppColors.primary.withValues(alpha: 0.3),
        ),
      );

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Video init error: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = 'Failed to load video';
      });
    }
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height ?? 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isInitialized && _chewieController != null) {
      return Stack(
        children: [
          Chewie(controller: _chewieController!),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    widget.placeholder,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_isLoading) return _buildLoadingState();
    if (_hasError)
      return _buildErrorState(_errorMessage ?? 'Video unavailable');

    if (widget.streamUrl == null || widget.streamUrl!.isEmpty) {
      return _buildNoVideoState();
    }

    // Has URL but not started — show thumbnail with play button
    return _buildPlayButton();
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _initializeVideo,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Thumbnail (snapshot as video poster) ──────────────────
          if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: widget.thumbnailUrl!, // already full URL from caller
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppColors.surfaceLight,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) {
                debugPrint('❌ Thumbnail load error: $error for $url');
                return Container(
                  color: AppColors.surfaceLight,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: AppColors.textSecondary,
                      size: 40,
                    ),
                  ),
                );
              },
            )
          else
            Container(
              color: AppColors.surfaceLight,
              child: const Center(
                child: Icon(
                  Icons.videocam,
                  color: AppColors.textSecondary,
                  size: 40,
                ),
              ),
            ),

          // ── Dark overlay ──────────────────────────────────────────
          Container(
            color: Colors.black.withValues(alpha: 0.35),
          ),

          // ── Play button ───────────────────────────────────────────
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.9),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),

          // ── Bottom label ──────────────────────────────────────────
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to play · ${widget.placeholder}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: AppColors.surfaceLight,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              'Loading video...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      color: AppColors.surfaceLight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.danger,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _initializeVideo,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoVideoState() {
    return Container(
      color: AppColors.surfaceLight,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off,
              size: 48,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 8),
            Text(
              'No video available',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Video is being processed...',
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
}
