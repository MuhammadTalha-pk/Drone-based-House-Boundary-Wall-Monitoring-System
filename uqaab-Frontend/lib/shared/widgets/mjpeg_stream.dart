// // lib/shared/widgets/mjpeg_stream.dart
// // Custom MJPEG stream widget — replaces abandoned flutter_mjpeg package.
// import 'dart:async';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// class MjpegStream extends StatefulWidget {
//   final String stream;
//   final BoxFit fit;
//   final Widget Function(BuildContext, dynamic, StackTrace?)? error;

//   const MjpegStream({
//     super.key,
//     required this.stream,
//     this.fit = BoxFit.contain,
//     this.error,
//   });

//   @override
//   State<MjpegStream> createState() => _MjpegStreamState();
// }

// class _MjpegStreamState extends State<MjpegStream> {
//   Uint8List? _currentFrame;
//   dynamic _error;
//   StackTrace? _stackTrace;
//   StreamSubscription? _subscription;
//   http.Client? _client;
//   bool _disposed = false;

//   @override
//   void initState() {
//     super.initState();
//     _startStream();
//   }

//   @override
//   void didUpdateWidget(MjpegStream oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.stream != widget.stream) {
//       _stopStream();
//       _startStream();
//     }
//   }

//   @override
//   void dispose() {
//     _disposed = true;
//     _stopStream();
//     super.dispose();
//   }

//   void _stopStream() {
//     _subscription?.cancel();
//     _subscription = null;
//     _client?.close();
//     _client = null;
//   }

//   Future<void> _startStream() async {
//     _error = null;
//     _stackTrace = null;

//     try {
//       _client = http.Client();
//       final request = http.Request('GET', Uri.parse(widget.stream));
//       final response = await _client!.send(request);

//       if (response.statusCode != 200) {
//         if (!_disposed) {
//           setState(() {
//             _error = 'HTTP ${response.statusCode}';
//           });
//         }
//         return;
//       }

//       // MJPEG streams send multipart JPEG frames separated by boundary markers.
//       // We accumulate bytes and extract frames between JPEG SOI (0xFFD8) and
//       // EOI (0xFFD9) markers.
//       final buffer = BytesBuilder(copy: false);

//       _subscription = response.stream.listen(
//         (chunk) {
//           buffer.add(chunk);
//           final bytes = buffer.toBytes();

//           // Search for JPEG end marker (0xFF 0xD9)
//           int endIndex = -1;
//           for (int i = bytes.length - 1; i > 0; i--) {
//             if (bytes[i] == 0xD9 && bytes[i - 1] == 0xFF) {
//               endIndex = i + 1;
//               break;
//             }
//           }

//           if (endIndex == -1) return;

//           // Search for JPEG start marker (0xFF 0xD8)
//           int startIndex = -1;
//           for (int i = 0; i < endIndex - 1; i++) {
//             if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8) {
//               startIndex = i;
//             }
//           }

//           if (startIndex == -1) return;

//           // Extract JPEG frame
//           final frame = Uint8List.fromList(
//             bytes.sublist(startIndex, endIndex),
//           );

//           if (!_disposed && mounted) {
//             setState(() {
//               _currentFrame = frame;
//               _error = null;
//             });
//           }

//           // Clear buffer and keep any remaining bytes after the frame
//           buffer.clear();
//           if (endIndex < bytes.length) {
//             buffer.add(bytes.sublist(endIndex));
//           }
//         },
//         onError: (e, st) {
//           if (!_disposed && mounted) {
//             setState(() {
//               _error = e;
//               _stackTrace = st;
//             });
//           }
//         },
//         cancelOnError: false,
//       );
//     } catch (e, st) {
//       if (!_disposed && mounted) {
//         setState(() {
//           _error = e;
//           _stackTrace = st;
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_error != null && widget.error != null) {
//       return widget.error!(context, _error, _stackTrace);
//     }

//     if (_currentFrame != null) {
//       return Image.memory(
//         _currentFrame!,
//         fit: widget.fit,
//         gaplessPlayback: true, // prevents flicker between frames
//       );
//     }

//     return const Center(
//       child: CircularProgressIndicator(strokeWidth: 2),
//     );
//   }
// }

// lib/shared/widgets/mjpeg_stream.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uqaab/core/services/secure_storage_service.dart';

class MjpegStream extends StatefulWidget {
  final String stream;
  final BoxFit fit;
  final int targetFps; // control frame rate
  final Widget Function(BuildContext, dynamic, StackTrace?)? error;

  const MjpegStream({
    super.key,
    required this.stream,
    this.fit = BoxFit.contain,
    this.targetFps = 15, // sweet spot for MJPEG over HTTP
    this.error,
  });

  @override
  State<MjpegStream> createState() => _MjpegStreamState();
}

class _MjpegStreamState extends State<MjpegStream> {
  // Use ValueNotifier to avoid full widget rebuilds
  final ValueNotifier<Uint8List?> _frameNotifier = ValueNotifier(null);
  dynamic _error;
  StackTrace? _stackTrace;
  StreamSubscription? _subscription;
  http.Client? _client;
  bool _disposed = false;
  final List<int> _buffer = [];

  // Frame rate limiting
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);
  Duration get _minFrameInterval =>
      Duration(milliseconds: (1000 / widget.targetFps).round());

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void didUpdateWidget(MjpegStream oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _stopStream();
      _startStream();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopStream();
    _frameNotifier.dispose();
    super.dispose();
  }

  void _stopStream() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    _buffer.clear();
  }

  Future<void> _startStream() async {
    _buffer.clear();
    if (!_disposed && mounted) {
      setState(() {
        _error = null;
        _stackTrace = null;
      });
    }

    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.stream));
      // Important headers for smooth streaming
      request.headers['Connection'] = 'keep-alive';
      request.headers['Cache-Control'] = 'no-cache';

      // Attach Authorization header if token is available in secure storage
      try {
        final storage = SecureStorageService();
        final token = await storage.getToken();
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      } catch (_) {
        // ignore secure storage errors and continue without auth
      }

      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        if (!_disposed && mounted) {
          setState(() => _error = 'HTTP ${response.statusCode}');
        }
        return;
      }

      _subscription = response.stream.listen(
        (chunk) {
          _buffer.addAll(chunk);
          _extractAndThrottleFrames();
        },
        onError: (e, st) {
          if (!_disposed && mounted) {
            setState(() {
              _error = e;
              _stackTrace = st;
            });
          }
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e, st) {
      if (!_disposed && mounted) {
        setState(() {
          _error = e;
          _stackTrace = st;
        });
      }
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!_disposed) {
        _stopStream();
        _startStream();
      }
    });
  }

  void _extractAndThrottleFrames() {
    while (true) {
      // Find first JPEG start (0xFF 0xD8)
      int startIndex = -1;
      for (int i = 0; i < _buffer.length - 1; i++) {
        if (_buffer[i] == 0xFF && _buffer[i + 1] == 0xD8) {
          startIndex = i;
          break;
        }
      }

      if (startIndex == -1) {
        _buffer.clear();
        break;
      }

      // Discard bytes before start marker
      if (startIndex > 0) {
        _buffer.removeRange(0, startIndex);
      }

      // Find first JPEG end (0xFF 0xD9) after start
      int endIndex = -1;
      for (int i = 2; i < _buffer.length - 1; i++) {
        if (_buffer[i] == 0xFF && _buffer[i + 1] == 0xD9) {
          endIndex = i + 2;
          break;
        }
      }

      if (endIndex == -1) break; // wait for more data

      // Frame rate throttle — drop frame if too soon
      final now = DateTime.now();
      final elapsed = now.difference(_lastFrameTime);

      if (elapsed >= _minFrameInterval) {
        // Render this frame
        final frame = Uint8List.fromList(_buffer.sublist(0, endIndex));
        _frameNotifier.value = frame; // no setState = no rebuild overhead
        _lastFrameTime = now;
      }

      // Always consume the frame from buffer
      _buffer.removeRange(0, endIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && widget.error != null) {
      return widget.error!(context, _error, _stackTrace);
    }

    return ValueListenableBuilder<Uint8List?>(
      valueListenable: _frameNotifier,
      builder: (context, frame, _) {
        if (frame == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
                SizedBox(height: 12),
                Text(
                  'Loading camera stream...',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          );
        }
        return Image.memory(
          frame,
          fit: widget.fit,
          gaplessPlayback: true,
          // These two remove decode overhead
          filterQuality: FilterQuality.low,
          isAntiAlias: false,
        );
      },
    );
  }
}
