// lib/features/cameras/screens/fence_calibration_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart'; // <--- ADDED MJPEG
import '../../../core/providers/property_context_provider.dart';
import '../provider/camera_provider.dart';
import 'camera_cell_calibration_screen.dart';

// ─── Data model ───────────────────────────────────────────────────────────────
class PolygonPoint {
  final double x; // normalised 0–1
  final double y;
  const PolygonPoint(this.x, this.y);
  Map<String, double> toMap() => {'x': x, 'y': y};
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class FenceCalibrationScreen extends StatefulWidget {
  /// String camera id — comes from GoRouter path param or int.toString()
  final String cameraId;
  final String cameraName;

  /// true  → editing an existing camera (came from EditCameraScreen)
  /// false → adding a brand-new camera
  final bool isUpdate;

  // Draft fields forwarded from AddCameraScreen query params
  final String? draftStreamUrl;
  final String? draftCameraType;
  final int? draftRow;
  final int? draftCol;

  const FenceCalibrationScreen({
    super.key,
    required this.cameraId,
    required this.cameraName,
    this.isUpdate = false,
    this.draftStreamUrl,
    this.draftCameraType,
    this.draftRow,
    this.draftCol,
  });

  @override
  State<FenceCalibrationScreen> createState() => _FenceCalibrationScreenState();
}

class _FenceCalibrationScreenState extends State<FenceCalibrationScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  final List<PolygonPoint> _points = [];
  bool _showCompleteDialog = false;
  bool _isSaving = false;

  static const _labels = [
    'Top-Left',
    'Top-Right',
    'Bottom-Right',
    'Bottom-Left',
  ];

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // ---> ADDED THIS CHECK <---
    if (widget.cameraId.trim().isNotEmpty && widget.cameraId != '0') {
      _fetchExistingPolygon();
    }
  }

  // ---> ADDED THIS NEW METHOD <---
  Future<void> _fetchExistingPolygon() async {
    try {
      final camId = int.parse(widget.cameraId);
      final polyData =
          await context.read<CameraProvider>().getFenceConfig(camId);

      if (polyData != null && polyData.length == 4 && mounted) {
        setState(() {
          _points.clear();
          _points.addAll(polyData.map((p) => PolygonPoint(p['x']!, p['y']!)));
          _showCompleteDialog =
              true; // Instantly show the "Complete" dialog so they can proceed or redo
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch polygon: $e");
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _onTapCanvas(TapUpDetails details, Size canvasSize) {
    if (_points.length >= 4 || _showCompleteDialog) return;
    final nx = (details.localPosition.dx / canvasSize.width).clamp(0.0, 1.0);
    final ny = (details.localPosition.dy / canvasSize.height).clamp(0.0, 1.0);
    setState(() {
      _points.add(PolygonPoint(nx, ny));
      if (_points.length == 4) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _showCompleteDialog = true);
        });
      }
    });
  }

  void _reset() => setState(() {
        _points.clear();
        _showCompleteDialog = false;
      });

  String get _progressText {
    if (_points.isEmpty) return 'Tap to place Top-Left corner';
    if (_points.length < 4) return 'Place ${_labels[_points.length]} corner';
    return '🎉 All 4 points placed! Ready to save.';
  }

  double get _progressValue => _points.length / 4.0;

  Future<void> _saveAndNext() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final provider = context.read<CameraProvider>();
      final propertyId =
          context.read<PropertyContextProvider>().selectedPropertyId;
      if (propertyId == null) {
        throw Exception('Select a property before saving the camera');
      }

      final cameraId = widget.cameraId.trim().isNotEmpty
          ? int.parse(widget.cameraId)
          : await _createCameraIfNeeded(provider, propertyId);

      if (cameraId == null) {
        throw Exception(
          provider.errorMessage.isNotEmpty
              ? provider.errorMessage
              : 'Failed to create camera',
        );
      }

      final points = _points.map((p) => p.toMap()).toList();
      final success = await provider.saveFenceConfig(cameraId, points);

      if (!mounted) return;

      if (!success) {
        _showError(
          provider.errorMessage.isNotEmpty
              ? provider.errorMessage
              : 'Failed to save fence config',
        );
        setState(() => _isSaving = false);
        return;
      }

      // Navigate to cell calibration, forwarding all draft/update params
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CameraCellCalibrationScreen(
            cameraId: cameraId.toString(),
            cameraName: widget.cameraName,
            isUpdate: widget.isUpdate,
            draftStreamUrl: widget.draftStreamUrl,
            draftCameraType: widget.draftCameraType,
            draftRow: widget.draftRow,
            draftCol: widget.draftCol,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('$e');
      setState(() => _isSaving = false);
    }
  }

  Future<int?> _createCameraIfNeeded(
    CameraProvider provider,
    String propertyId,
  ) {
    return provider.createCamera(
      propertyId: propertyId,
      name: widget.cameraName,
      rtspUrl: widget.draftStreamUrl ?? '',
      row: widget.draftRow ?? 0,
      col: widget.draftCol ?? 0,
      camera_type: widget.draftCameraType ?? 'entrance',
    );
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
      );

  // ── FIXED: Switched to MJPEG for valid stream display ──────────────────────
  Widget _buildStreamLayer() {
    final streamUrl = widget.draftStreamUrl ?? '';
    if (streamUrl.isEmpty) {
      return Container(
        color: const Color(0xFF0D0D0D),
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.white30, size: 64),
        ),
      );
    }

    return SizedBox.expand(
      child: Mjpeg(
        isLive: true,
        stream: streamUrl,
        fit: BoxFit.contain,
        loading: (context) => const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFC5A880),
          ),
        ),
        error: (context, error, stack) => Container(
          color: Colors.black,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image, color: Colors.white54, size: 42),
              const SizedBox(height: 10),
              Text(
                'Failed to load stream\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 420;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(compact),
                _buildStepper(compact),
                Expanded(child: _buildCanvas()),
                _buildBottomSheet(compact),
              ],
            ),
            if (_showCompleteDialog) _buildDialogOverlay(compact),
          ],
        ),
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar(bool compact) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 8 : 12,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          border: Border(
            bottom: BorderSide(color: Color(0xFF2B2B2B), width: 1),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            SizedBox(width: compact ? 8 : 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wall Calibration',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.cameraName,
                  style:
                      const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: _reset,
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
            IconButton(
              onPressed: _showInfoDialog,
              icon: const Icon(Icons.info_outline, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stepper ────────────────────────────────────────────────────────────────
  Widget _buildStepper(bool compact) {
    const muted = Color(0xFF555555);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 10,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF242424),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2B2B2B), width: 1),
        ),
      ),
      child: Row(
        children: [
          const _StepPill(
            label: 'Draw Polygon',
            number: '1',
            isActive: true,
          ),
          SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: muted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          const _StepPill(
            label: 'Define Cells',
            number: '2',
            isActive: false,
          ),
        ],
      ),
    );
  }

  // ── FIXED: Wrapped in AspectRatio to map coordinates perfectly ─────────────
  Widget _buildCanvas() {
    const double videoAspectRatio = 16 / 9;

    return Container(
      color: const Color(0xFF0D0D0D),
      child: Center(
        child: AspectRatio(
          aspectRatio: videoAspectRatio,
          child: LayoutBuilder(builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              onTapUp: (d) => _onTapCanvas(d, size),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: _buildStreamLayer()),
                  // Polygon overlay
                  CustomPaint(
                    size: size,
                    painter: _PolygonPainter(
                      points: _points,
                      canvasSize: size,
                      pulseAnimation: _pulseAnim,
                    ),
                  ),
                  // Hint chip
                  if (_points.length < 4)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Opacity(
                          opacity: _pulseAnim.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 191),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFFC5A880),
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_points.length}/4  •  ${_labels[_points.length]}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Bottom Sheet ───────────────────────────────────────────────────────────
  Widget _buildBottomSheet(bool compact) {
    const gold = Color(0xFFC5A880);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 20,
        compact ? 12 : 16,
        compact ? 12 : 20,
        compact ? 16 : 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _progressText,
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${(_progressValue * 100).round()}%',
                    style: const TextStyle(
                        color: gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progressValue,
                minHeight: 5,
                backgroundColor: const Color(0xFFEEEEEE),
                valueColor: const AlwaysStoppedAnimation<Color>(gold),
              ),
            ),
            const SizedBox(height: 16),
            if (compact) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _reset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF333333),
                    side: const BorderSide(color: Color(0xFFDDDDDD)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _points.length == 4 ? _saveAndNext : null,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save & Define Cells'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0xFFE0D0B8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF333333),
                      side: const BorderSide(color: Color(0xFFDDDDDD)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _points.length == 4 ? _saveAndNext : null,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save & Define Cells'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: const Color(0xFFE0D0B8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Complete Dialog ────────────────────────────────────────────────────────
  Widget _buildDialogOverlay(bool compact) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: compact ? 20 : 32),
          padding: EdgeInsets.all(compact ? 20 : 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A7C59).withValues(alpha: 31),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF4A7C59),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Polygon Complete!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Fence boundary defined.',
                style: TextStyle(color: Color(0xFF666666), fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                "Next: You'll name the sections (cells) inside this fence.",
                style: TextStyle(
                  color: Color(0xFFC5A880),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _points.clear();
                        _showCompleteDialog = false;
                      }),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF333333),
                        side: const BorderSide(color: Color(0xFFDDDDDD)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Redo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveAndNext,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Save & Define Cells'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC5A880),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('How to calibrate'),
        content: const Text(
          'Tap 4 corners of the fence/wall boundary in order:\n\n'
          '1. Top-Left\n2. Top-Right\n'
          '3. Bottom-Right\n4. Bottom-Left\n\n'
          'Then tap "Save & Define Cells" to proceed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// ─── Polygon Painter ──────────────────────────────────────────────────────────
class _PolygonPainter extends CustomPainter {
  final List<PolygonPoint> points;
  final Size canvasSize;
  final Animation<double> pulseAnimation;

  _PolygonPainter({
    required this.points,
    required this.canvasSize,
    required this.pulseAnimation,
  }) : super(repaint: pulseAnimation);

  Offset _toOffset(PolygonPoint p) =>
      Offset(p.x * canvasSize.width, p.y * canvasSize.height);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final offsets = points.map(_toOffset).toList();

    // Semi-transparent fill
    if (offsets.length >= 3) {
      final path = Path()..moveTo(offsets[0].dx, offsets[0].dy);
      for (var i = 1; i < offsets.length; i++) {
        path.lineTo(offsets[i].dx, offsets[i].dy);
      }
      path.close();
      canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFC5A880).withValues(alpha: 46)
            ..style = PaintingStyle.fill);
    }

    // Dashed border
    final borderPaint = Paint()
      ..color = const Color(0xFFC5A880)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (var i = 0; i < offsets.length; i++) {
      final next = offsets[(i + 1) % offsets.length];
      if (i < offsets.length - 1 || offsets.length == 4) {
        _drawDashedLine(canvas, offsets[i], next, borderPaint);
      }
    }

    // Corner dots + labels
    const labels = ['TL', 'TR', 'BR', 'BL'];
    for (var i = 0; i < offsets.length; i++) {
      final o = offsets[i];
      canvas.drawCircle(o, 12,
          Paint()..color = const Color(0xFFC5A880).withValues(alpha: 64));
      canvas.drawCircle(o, 6, Paint()..color = const Color(0xFFC5A880));
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o.translate(10, -18));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLen = 8.0;
    const gapLen = 5.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final ux = dx / len;
    final uy = dy / len;
    var d = 0.0;
    var drawing = true;
    while (d < len) {
      final segLen = drawing ? dashLen : gapLen;
      final end = (d + segLen).clamp(0.0, len);
      if (drawing) {
        canvas.drawLine(
          Offset(p1.dx + ux * d, p1.dy + uy * d),
          Offset(p1.dx + ux * end, p1.dy + uy * end),
          paint,
        );
      }
      d = end;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(_PolygonPainter old) =>
      old.points != points || old.canvasSize != canvasSize;
}

class _StepPill extends StatelessWidget {
  final String label;
  final String number;
  final bool isActive;

  const _StepPill({
    required this.label,
    required this.number,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? const Color(0xFFC5A880) : const Color(0xFF2A2A2A);
    final fg = isActive ? Colors.black : const Color(0xFF9A9A9A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? null
            : Border.all(color: const Color(0xFF444444), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? Colors.black : const Color(0xFF3A3A3A),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFFBBBBBB),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
