import 'package:flutter/material.dart';
import '../../../models/grid_cell_model.dart';
import '../../../core/providers/base_provider.dart';
import '../../../core/services/api_service.dart';

class DroneControlProvider extends BaseProvider {
  final ApiService apiService;

  DroneControlProvider({required this.apiService});

  String? _selectedDroneId;
  String? _selectedDroneName;
  GridCellModel _currentPosition = GridCellModel(row: 0, col: 0);
  int _maxRows = 8;
  int _maxCols = 3;
  bool _hasControlLock = false;

  String? get selectedDroneId => _selectedDroneId;
  String? get selectedDroneName => _selectedDroneName;
  GridCellModel get currentPosition => _currentPosition;
  bool get hasControlLock => _hasControlLock;

  /// Request exclusive control of the drone from FastAPI
  Future<bool> acquireControlLock() async {
    try {
      setLoading();
      // Directly hit your concrete lock API endpoint
      final response = await apiService.put('drone/lock');
      _hasControlLock = response['success'] ?? false;
      setSuccess();
      return _hasControlLock;
    } catch (e) {
      _hasControlLock = false;
      setError('Drone is currently locked by another device.');
      return false;
    }
  }

  /// Release the control lock when leaving the screen
  Future<void> releaseControlLock() async {
    try {
      await apiService.put('drone/unlock');
      _hasControlLock = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to cleanly unlock drone: $e');
    }
  }

  void selectDrone(String id, String name, GridCellModel homeCell) {
    _selectedDroneId = id;
    _selectedDroneName = name;
    _currentPosition = homeCell;
    notifyListeners();
  }

  void setGridBounds(int maxRows, int maxCols) {
    _maxRows = maxRows;
    _maxCols = maxCols;
    notifyListeners();
  }

  // --- Mapped D-Pad Movements (Local UI Feedback) ---
  void moveUp() {
    if (_currentPosition.row > 0) {
      _currentPosition = GridCellModel(
          row: _currentPosition.row - 1, col: _currentPosition.col);
      notifyListeners();
    }
  }

  void moveDown() {
    if (_currentPosition.row < _maxRows - 1) {
      _currentPosition = GridCellModel(
          row: _currentPosition.row + 1, col: _currentPosition.col);
      notifyListeners();
    }
  }

  void moveLeft() {
    if (_currentPosition.col > 0) {
      _currentPosition = GridCellModel(
          row: _currentPosition.row, col: _currentPosition.col - 1);
      notifyListeners();
    }
  }

  void moveRight() {
    if (_currentPosition.col < _maxCols - 1) {
      _currentPosition = GridCellModel(
          row: _currentPosition.row, col: _currentPosition.col + 1);
      notifyListeners();
    }
  }

  void returnToHome(GridCellModel homeCell) {
    _currentPosition = homeCell;
    notifyListeners();
  }
}
