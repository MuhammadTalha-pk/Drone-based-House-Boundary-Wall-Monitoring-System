import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class RtspVlcPlayer extends StatefulWidget {
  final String url;
  final BoxFit fit;
  // --- ADDED THESE TWO LINES ---
  final double? width;
  final double? height;

  const RtspVlcPlayer({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    // --- ADDED THESE TWO LINES ---
    this.width,
    this.height,
  });

  @override
  State<RtspVlcPlayer> createState() => _RtspVlcPlayerState();
}

class _RtspVlcPlayerState extends State<RtspVlcPlayer> {
  // ... (keep all your variables and initState/dispose methods exactly the same) ...
  VlcPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant RtspVlcPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _initController();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _disposeController();
    super.dispose();
  }

  void _initController() {
    if (widget.url.trim().isEmpty) {
      setState(() {
        _hasError = true;
        _isInitialized = false;
      });
      return;
    }

    final controller = VlcPlayerController.network(
      widget.url,
      hwAcc: HwAcc.disabled,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(2000),
          VlcAdvancedOptions.fileCaching(150),
          VlcAdvancedOptions.liveCaching(150),
          VlcAdvancedOptions.clockJitter(0),
          VlcAdvancedOptions.clockSynchronization(0),
        ]),
        http: VlcHttpOptions([
          VlcHttpOptions.httpReconnect(true),
        ]),
      ),
    );

    controller.addListener(() {
      if (_disposed || !mounted || _controller != controller) return;
      final value = controller.value;
      if (value.hasError && !_hasError) {
        setState(() => _hasError = true);
      }
      if (value.isInitialized != _isInitialized) {
        setState(() => _isInitialized = value.isInitialized);
      }
    });

    if (mounted) {
      setState(() {
        _controller = controller;
        _hasError = false;
        _isInitialized = false;
      });
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the returned widget in a SizedBox if dimensions are provided
    Widget content;

    if (_hasError) {
      content =
          _buildPlaceholder('Stream unavailable', icon: Icons.videocam_off);
    } else if (_controller == null || !_isInitialized) {
      content = _buildPlaceholder('Loading stream...');
    } else {
      final aspect = _controller!.value.aspectRatio;
      final viewAspect = aspect.isFinite && aspect > 0 ? aspect : 16 / 9;

      content = ClipRect(
        child: ColoredBox(
          color: Colors.black,
          child: SizedBox.expand(
            child: VlcPlayer(
              controller: _controller!,
              aspectRatio: viewAspect,
              placeholder: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
    }

    // --- APPLY THE WRAPPER HERE ---
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: content,
    );
  }

  Widget _buildPlaceholder(String label, {IconData? icon}) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, color: Colors.white54, size: 42)
          else
            const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
