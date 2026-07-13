// lib/features/cameras/screens/camera_cell_calibration_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../../../core/providers/property_context_provider.dart';
import '../provider/camera_provider.dart';

// ─── Models ───────────────────────────────────────────────────────────────────
class CellPoint {
  final double x; // normalised 0–1
  final double y;
  const CellPoint(this.x, this.y);
  Map<String, double> toMap() => {'x': x, 'y': y};
}

class DrawnCell {
  final String name;
  final List<CellPoint> points; // exactly 4
  final Color color;
  const DrawnCell({
    required this.name,
    required this.points,
    required this.color,
  });
}

// ─── Cell colour palette ──────────────────────────────────────────────────────
const _cellColors = [
  Color(0xFFB03030),
  Color(0xFF2E7D44),
  Color(0xFF2960B0),
  Color(0xFFC07820),
  Color(0xFF6A2FA0),
  Color(0xFF1E7070),
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class CameraCellCalibrationScreen extends StatefulWidget {
  /// String camera id — from GoRouter path param or int.toString()
  final String cameraId;
  final String cameraName;

  /// true  → editing existing camera
  /// false → adding new camera
  final bool isUpdate;

  // Draft fields forwarded through the calibration flow
  final String? draftStreamUrl;
  final String? draftCameraType;
  final int? draftRow;
  final int? draftCol;

  const CameraCellCalibrationScreen({
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
  State<CameraCellCalibrationScreen> createState() =>
      _CameraCellCalibrationScreenState();
}

class _CameraCellCalibrationScreenState
    extends State<CameraCellCalibrationScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  final List<DrawnCell> _cells = [];
  List<CellPoint> _currentPoints = [];
  List<CellPoint> _fencePolygon = [];
  bool _isDrawing = false;
  bool _isSaving = false;
  String _nextCellName = '';

  final TextEditingController _nameCtrl = TextEditingController();

  int? _draggingCellIndex;
  int? _draggingPointIndex;
  Offset? _lastDragPosition;

  /// ── INIT & FETCH ───────────────────────────────────────────────────────────
  // ── INIT & FETCH ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.cameraId.trim().isNotEmpty && widget.cameraId != '0') {
      _loadCameraData();
    }
  }

  Future<void> _loadCameraData() async {
    try {
      final camId = int.parse(widget.cameraId);
      final provider = context.read<CameraProvider>();

      // 1. Fetch the Fence Polygon so we can draw it as a guide!
      List<CellPoint> loadedPolygon = [];
      if (_isFence) {
        final polyData = await provider.getFenceConfig(camId);
        if (polyData != null) {
          loadedPolygon =
              polyData.map((p) => CellPoint(p['x']!, p['y']!)).toList();
        }
      }

      // 2. Fetch the existing cells
      final rawCells = await provider.getCells(camId);
      final List<DrawnCell> loadedCells = [];

      if (rawCells.isNotEmpty) {
        for (int i = 0; i < rawCells.length; i++) {
          final cellMap = rawCells[i];
          final pointsList = cellMap['polygon_points'] as List;
          final points = pointsList
              .map((p) => CellPoint(
                  (p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
              .toList();

          loadedCells.add(DrawnCell(
            name: cellMap['cell_name'] ?? 'Cell ${i + 1}',
            points: points,
            color: _colorForIndex(i),
          ));
        }
      }

      if (mounted) {
        setState(() {
          _fencePolygon = loadedPolygon; // Save the polygon
          _cells.clear();
          _cells.addAll(loadedCells); // Save the cells
        });
      }
    } catch (e) {
      debugPrint("Failed to load camera data: $e");
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _deleteCell(int index) {
    setState(() {
      _cells.removeAt(index);
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Camera type: from draft param or fall back to 'entrance'
  String get _cameraType => widget.draftCameraType ?? 'entrance';

  bool get _isFence => _cameraType == 'fence';

  String _nextDefaultName() {
    final idx = _cells.length;
    final letter = String.fromCharCode(65 + (idx ~/ 9));
    final num = (idx % 9) + 1;
    return '$letter$num';
  }

  Color _colorForIndex(int i) => _cellColors[i % _cellColors.length];

  void _onTapCanvas(TapUpDetails details, Size canvasSize) {
    if (!_isDrawing || _currentPoints.length >= 4) return;
    final nx = (details.localPosition.dx / canvasSize.width).clamp(0.0, 1.0);
    final ny = (details.localPosition.dy / canvasSize.height).clamp(0.0, 1.0);
    setState(() {
      _currentPoints.add(CellPoint(nx, ny));
      if (_currentPoints.length == 4) _finishCell();
    });
  }

  // ── Dragging Logic ─────────────────────────────────────────────────────────

  List<int>? _hitTestCorner(Offset localPosition, Size canvasSize) {
    const double hitRadius = 25.0;
    for (int i = _cells.length - 1; i >= 0; i--) {
      final cell = _cells[i];
      for (int j = 0; j < cell.points.length; j++) {
        final p = cell.points[j];
        final pointOffset =
            Offset(p.x * canvasSize.width, p.y * canvasSize.height);
        if ((pointOffset - localPosition).distance <= hitRadius) {
          return [i, j];
        }
      }
    }
    return null;
  }

  int? _hitTestCell(Offset localPosition, Size canvasSize) {
    for (int i = _cells.length - 1; i >= 0; i--) {
      final cell = _cells[i];
      if (cell.points.isEmpty) continue;
      final path = Path();
      path.moveTo(cell.points[0].x * canvasSize.width,
          cell.points[0].y * canvasSize.height);
      for (int j = 1; j < cell.points.length; j++) {
        path.lineTo(cell.points[j].x * canvasSize.width,
            cell.points[j].y * canvasSize.height);
      }
      path.close();
      if (path.contains(localPosition)) {
        return i;
      }
    }
    return null;
  }

  void _onPanStart(DragStartDetails details, Size canvasSize) {
    if (_isDrawing) return;

    final cornerHit = _hitTestCorner(details.localPosition, canvasSize);
    if (cornerHit != null) {
      setState(() {
        _draggingCellIndex = cornerHit[0];
        _draggingPointIndex = cornerHit[1];
        _lastDragPosition = details.localPosition;
      });
      return;
    }

    final hitIndex = _hitTestCell(details.localPosition, canvasSize);
    if (hitIndex != null) {
      setState(() {
        _draggingCellIndex = hitIndex;
        _draggingPointIndex = null;
        _lastDragPosition = details.localPosition;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Size canvasSize) {
    if (_draggingCellIndex == null || _lastDragPosition == null) return;

    final dx = details.localPosition.dx - _lastDragPosition!.dx;
    final dy = details.localPosition.dy - _lastDragPosition!.dy;

    double ndx = dx / canvasSize.width;
    double ndy = dy / canvasSize.height;

    setState(() {
      final cell = _cells[_draggingCellIndex!];

      if (_draggingPointIndex != null) {
        final p = cell.points[_draggingPointIndex!];
        double newX = (p.x + ndx).clamp(0.0, 1.0);
        double newY = (p.y + ndy).clamp(0.0, 1.0);

        final newPoints = List<CellPoint>.from(cell.points);
        newPoints[_draggingPointIndex!] = CellPoint(newX, newY);

        _cells[_draggingCellIndex!] = DrawnCell(
          name: cell.name,
          points: newPoints,
          color: cell.color,
        );
      } else {
        double minX = 1.0, maxX = 0.0, minY = 1.0, maxY = 0.0;
        for (var p in cell.points) {
          if (p.x < minX) minX = p.x;
          if (p.x > maxX) maxX = p.x;
          if (p.y < minY) minY = p.y;
          if (p.y > maxY) maxY = p.y;
        }

        if (minX + ndx < 0.0) ndx = -minX;
        if (maxX + ndx > 1.0) ndx = 1.0 - maxX;
        if (minY + ndy < 0.0) ndy = -minY;
        if (maxY + ndy > 1.0) ndy = 1.0 - maxY;

        final newPoints =
            cell.points.map((p) => CellPoint(p.x + ndx, p.y + ndy)).toList();

        _cells[_draggingCellIndex!] = DrawnCell(
          name: cell.name,
          points: newPoints,
          color: cell.color,
        );
      }
      _lastDragPosition = details.localPosition;
    });
  }

  void _onPanEnd() {
    if (_draggingCellIndex != null) {
      setState(() {
        _draggingCellIndex = null;
        _draggingPointIndex = null;
        _lastDragPosition = null;
      });
    }
  }

  void _finishCell() {
    final name = _nextCellName.isNotEmpty ? _nextCellName : _nextDefaultName();
    setState(() {
      _cells.add(DrawnCell(
        name: name,
        points: List.from(_currentPoints),
        color: _colorForIndex(_cells.length),
      ));
      _currentPoints = [];
      _nextCellName = '';
      _nameCtrl.clear();
      _isDrawing = false;
    });
  }

  void _startAddCell() {
    _nameCtrl.text = _nextDefaultName();
    showDialog(
      context: context,
      builder: (_) => _NameCellDialog(
        controller: _nameCtrl,
        defaultName: _nextDefaultName(),
        onConfirm: (name) => setState(() {
          _nextCellName = name;
          _currentPoints = [];
          _isDrawing = true;
        }),
      ),
    );
  }

  void _cancelDrawing() => setState(() {
        _currentPoints = [];
        _isDrawing = false;
      });

  void _removeLastCell() {
    if (_isDrawing) {
      _cancelDrawing();
      return;
    }
    if (_cells.isNotEmpty) setState(() => _cells.removeLast());
  }

  Future<void> _saveCells() async {
    if (_isSaving || _cells.isEmpty) return;
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

      final cellsPayload = _cells.asMap().entries.map((e) {
        final i = e.key;
        final cell = e.value;
        return {
          'cell_name': cell.name,
          'row': i ~/ 3,
          'col': i % 3,
          'polygon_points': cell.points.map((p) => p.toMap()).toList(),
        };
      }).toList();

      final success = await provider.saveCells(cameraId, cellsPayload);

      if (!mounted) return;

      if (!success) {
        _showError(
          provider.errorMessage.isNotEmpty
              ? provider.errorMessage
              : 'Failed to save cells',
        );
        setState(() => _isSaving = false);
        return;
      }

      Navigator.of(context)
          .popUntil((r) => r.isFirst || r.settings.name == '/cameras/manage');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${widget.cameraName}" ${widget.isUpdate ? 'updated' : 'added'} '
            'with ${_cells.length} cell${_cells.length == 1 ? '' : 's'}!',
          ),
          backgroundColor: const Color(0xFF4A7C59),
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
        child: Column(
          children: [
            _buildAppBar(compact),
            if (_isFence) _buildStepper(compact),
            Expanded(child: _buildCanvas()),
            _buildBottomSheet(compact),
          ],
        ),
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar(bool compact) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 6 : 8,
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
                  'Define Camera Cells',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  widget.cameraName,
                  style:
                      const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            if (_isDrawing)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC5A880),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 12, color: Colors.black),
                    SizedBox(width: 4),
                    Text('Drawing',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  // ── Stepper (fence cameras only — step 2 active) ───────────────────────────
  Widget _buildStepper(bool compact) {
    const gold = Color(0xFFC5A880);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 24,
        vertical: compact ? 6 : 8,
      ),
      child: Row(
        children: [
          Column(children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                  color: Color(0xFF4A7C59), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
            const SizedBox(height: 4),
            const Text('Draw Polygon',
                style: TextStyle(
                    color: Color(0xFF4A7C59),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ]),
          Expanded(
            child: Container(
              height: 1.5,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient:
                    const LinearGradient(colors: [Color(0xFF4A7C59), gold]),
              ),
            ),
          ),
          Column(children: [
            Container(
              width: 28,
              height: 28,
              decoration:
                  const BoxDecoration(color: gold, shape: BoxShape.circle),
              child: const Center(
                  child: Text('2',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 13))),
            ),
            const SizedBox(height: 4),
            const Text('Define Cells',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }

  // ── Canvas ─────────────────────────────────────────────────────────────────
  Widget _buildCanvas() {
    const double videoAspectRatio = 16 / 9;

    return Container(
      color: const Color(0xFF0D0D0D),
      child: Center(
        child: AspectRatio(
          aspectRatio: videoAspectRatio,
          child: LayoutBuilder(builder: (ctx, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);

            return GestureDetector(
              onTapUp: (d) => _onTapCanvas(d, size),
              onPanStart: (d) => _onPanStart(d, size),
              onPanUpdate: (d) => _onPanUpdate(d, size),
              onPanEnd: (_) => _onPanEnd(),
              onPanCancel: _onPanEnd,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: _buildStreamLayer()),
                  CustomPaint(
                    size: size,
                    painter: _CellPainter(
                      cells: _cells,
                      currentPoints: _currentPoints,
                      fencePolygon: _fencePolygon,
                      canvasSize: size,
                      currentColor: _colorForIndex(_cells.length),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 191),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_cells.length} cell${_cells.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                          if (_isDrawing)
                            Text(
                              _currentPoints.isEmpty
                                  ? 'Click Top-Left'
                                  : 'Point ${_currentPoints.length}/4',
                              style: const TextStyle(
                                  color: Color(0xFFC5A880), fontSize: 10),
                            ),
                        ],
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
        compact ? 12 : 16,
        compact ? 10 : 12,
        compact ? 12 : 16,
        compact ? 16 : 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              if (_cells.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _cells
                        .asMap()
                        .entries
                        .map((e) => _CellChip(
                              cell: e.value,
                              onDelete: () => _deleteCell(e.key),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                _isDrawing
                    ? (_currentPoints.isEmpty
                        ? 'Tap Top-Left corner of the cell'
                        : 'Tap point ${_currentPoints.length + 1} / 4')
                    : 'Click Top-Left corner to start a new cell',
                style: const TextStyle(color: Color(0xFF777777), fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (compact) ...[
                Row(
                  children: [
                    GestureDetector(
                      onTap: _removeLastCell,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFDDDDDD)),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(Icons.undo,
                            color: Color(0xFF555555), size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isDrawing ? _cancelDrawing : _startAddCell,
                        icon: Icon(_isDrawing ? Icons.close : Icons.add,
                            size: 16),
                        label: Text(_isDrawing ? 'Cancel' : 'Add Cell'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _isDrawing
                              ? Colors.red.shade700
                              : const Color(0xFF333333),
                          side: BorderSide(
                            color: _isDrawing
                                ? Colors.red.shade300
                                : const Color(0xFFDDDDDD),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        (_cells.isNotEmpty && !_isSaving) ? _saveCells : null,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.save_outlined, size: 16),
                    label: Text(
                        'Save ${_cells.length} Cell${_cells.length == 1 ? '' : 's'}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: const Color(0xFFE0D0B8),
                      padding: const EdgeInsets.symmetric(vertical: 13),
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
                    GestureDetector(
                      onTap: _removeLastCell,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFDDDDDD)),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(Icons.undo,
                            color: Color(0xFF555555), size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (!_isDrawing)
                      OutlinedButton.icon(
                        onPressed: _startAddCell,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Cell'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF333333),
                          side: const BorderSide(color: Color(0xFFDDDDDD)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _cancelDrawing,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_cells.isNotEmpty && !_isSaving)
                            ? _saveCells
                            : null,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.save_outlined, size: 16),
                        label: Text(
                            'Save ${_cells.length} Cell${_cells.length == 1 ? '' : 's'}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: const Color(0xFFE0D0B8),
                          padding: const EdgeInsets.symmetric(vertical: 13),
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
      ),
    );
  }
}

// ─── Cell chip ────────────────────────────────────────────────────────────────
class _CellChip extends StatelessWidget {
  final DrawnCell cell;
  final VoidCallback onDelete;

  const _CellChip({required this.cell, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDDDDD)),
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: cell.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(cell.name,
              style: const TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.black87),
            ),
          )
        ],
      ),
    );
  }
}

// ─── Name cell dialog ─────────────────────────────────────────────────────────
class _NameCellDialog extends StatelessWidget {
  final TextEditingController controller;
  final String defaultName;
  final void Function(String) onConfirm;

  const _NameCellDialog({
    required this.controller,
    required this.defaultName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Name this cell'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: defaultName,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        textCapitalization: TextCapitalization.characters,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = controller.text.trim().isEmpty
                ? defaultName
                : controller.text.trim().toUpperCase();
            Navigator.pop(context);
            onConfirm(name);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC5A880),
            foregroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Start Drawing'),
        ),
      ],
    );
  }
}

// ─── Cell painter ─────────────────────────────────────────────────────────────
class _CellPainter extends CustomPainter {
  final List<DrawnCell> cells;
  final List<CellPoint> currentPoints;
  final List<CellPoint> fencePolygon; // <--- ADDED THIS
  final Size canvasSize;
  final Color currentColor;

  const _CellPainter({
    required this.cells,
    required this.currentPoints,
    required this.fencePolygon, // <--- ADDED THIS
    required this.canvasSize,
    required this.currentColor,
  });

  Offset _toOffset(CellPoint p) =>
      Offset(p.x * canvasSize.width, p.y * canvasSize.height);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw the Fence Boundary (Subtle Golden Outline)
    if (fencePolygon.length >= 3) {
      final offsets = fencePolygon.map(_toOffset).toList();
      final path = Path()..moveTo(offsets[0].dx, offsets[0].dy);
      for (var i = 1; i < offsets.length; i++) {
        path.lineTo(offsets[i].dx, offsets[i].dy);
      }
      path.close();

      canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFC5A880)
                .withValues(alpha: 0.15) // Light gold fill
            ..style = PaintingStyle.fill);
      canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFC5A880)
                .withValues(alpha: 0.8) // Solid gold border
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0);
    }

    // 2. Draw the Cells
    for (final cell in cells) {
      _drawCell(
          canvas, cell.points.map(_toOffset).toList(), cell.color, cell.name,
          filled: true);
    }

    // 3. Draw the Cell currently being drawn
    if (currentPoints.isNotEmpty) {
      _drawCell(canvas, currentPoints.map(_toOffset).toList(), currentColor, '',
          filled: false);
    }
  }

  void _drawCell(Canvas canvas, List<Offset> offsets, Color color, String label,
      {required bool filled}) {
    if (offsets.isEmpty) return;

    if (offsets.length >= 3) {
      final path = Path()..moveTo(offsets[0].dx, offsets[0].dy);
      for (var i = 1; i < offsets.length; i++) {
        path.lineTo(offsets[i].dx, offsets[i].dy);
      }
      if (filled) path.close();
      canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: 64)
            ..style = PaintingStyle.fill);
    }

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (var i = 0; i < offsets.length - 1; i++) {
      canvas.drawLine(offsets[i], offsets[i + 1], borderPaint);
    }
    if (filled && offsets.length == 4) {
      canvas.drawLine(offsets.last, offsets.first, borderPaint);
    }

    for (final o in offsets) {
      canvas.drawCircle(o, 5, Paint()..color = color);
    }

    if (label.isNotEmpty && offsets.length == 4) {
      final cx = offsets.map((o) => o.dx).reduce((a, b) => a + b) / 4;
      final cy = offsets.map((o) => o.dy).reduce((a, b) => a + b) / 4;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                  color: Colors.black.withValues(alpha: 204),
                  blurRadius: 4,
                  offset: const Offset(0, 1))
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_CellPainter old) =>
      old.cells != cells ||
      old.currentPoints != currentPoints ||
      old.fencePolygon != fencePolygon || // <--- Added to check
      old.canvasSize != canvasSize;
}
