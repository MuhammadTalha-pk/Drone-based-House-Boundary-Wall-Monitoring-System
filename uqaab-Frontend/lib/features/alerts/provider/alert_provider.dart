// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';

// import '../../../core/config/app_config.dart';
// import '../../../core/errors/api_exception.dart';
// import '../../../core/providers/base_provider.dart';
// import '../../../core/services/secure_storage_service.dart';
// import '../../../core/services/notification_service.dart';
// import '../../../models/alert_model.dart';
// import '../../../repositories/alert_repository.dart';

// class AlertProvider extends BaseProvider {

//   final AlertRepository alertRepository;
//   final SecureStorageService _secureStorage = SecureStorageService();
//   final NotificationService _notificationService = NotificationService();

//   List<AlertModel> _alerts = [];
//   List<AlertModel> get alerts => _alerts;

//   AlertModel? _selectedAlert;
//   AlertModel? get selectedAlert => _selectedAlert;

//   String _currentFilter = 'new';
//   String get currentFilter => _currentFilter;

//   // Real-time WebSocket connection state variables
//   WebSocketChannel? _wsChannel;
//   Timer? _reconnectTimer;
//   Timer? _heartbeatTimer;
//   bool _isConnected = false;

//   final double _initialReconnectDelayMs = 1000;
//   final double _maxReconnectDelayMs = 30000;
//   double _currentReconnectDelayMs = 1000;

//   String? _activePropertyId;

//   AlertProvider({required this.alertRepository});

//   bool get isConnected => _isConnected;

//   // ===========================================================================
//   // EXISTING METHODS (PRESERVED NATIVELY)
//   // ===========================================================================

//   Future<void> loadAlerts(String propertyId,
//       {String filter = 'new', bool silent = false}) async {
//     try {
//       _currentFilter = filter;
//       if (!silent) setLoading();
//       _alerts = await alertRepository.getAlerts(propertyId, filter: filter);
//       setSuccess();
//     } on ApiException catch (e) {
//       if (!silent) setError(e.message);
//     } catch (e) {
//       if (!silent) setError('Failed to load alerts');
//     }
//   }

//   Future<void> loadAlertDetail(String alertId) async {
//     try {
//       setLoading();
//       _selectedAlert = await alertRepository.getAlert(alertId);
//       setSuccess();
//     } on ApiException catch (e) {
//       setError(e.message);
//     } catch (e) {
//       setError('Failed to load alert');
//     }
//   }

//   Future<bool> markAsRead(String alertId) async {
//     try {
//       await alertRepository.markAsRead(alertId);
//       final index = _alerts.indexWhere((a) => a.id == alertId);
//       if (index != -1) {
//         _alerts[index] = AlertModel(
//           id: _alerts[index].id,
//           type: _alerts[index].type,
//           cameraName: _alerts[index].cameraName,
//           timestamp: _alerts[index].timestamp,
//           isRead: true,
//           confidence: _alerts[index].confidence,
//           severity: _alerts[index].severity,
//           imageUrl: _alerts[index].imageUrl,
//           clipUrl: _alerts[index].clipUrl,
//           cameraCell: _alerts[index].cameraCell,
//           status: _alerts[index].status,
//         );
//         notifyListeners();
//       }
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   Future<bool> markAsFalsePositive(String alertId) async {
//     try {
//       await alertRepository.markAsFalsePositive(alertId);
//       _alerts.removeWhere((a) => a.id == alertId);
//       notifyListeners();
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   Future<bool> resolveAlert(String alertId) async {
//     try {
//       await alertRepository.resolveAlert(alertId);
//       _alerts.removeWhere((a) => a.id == alertId);
//       notifyListeners();
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   Future<bool> deleteAlert(String alertId) async {
//     try {
//       await alertRepository.deleteAlert(alertId);
//       _alerts.removeWhere((a) => a.id == alertId);
//       notifyListeners();
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   // ===========================================================================
//   // REAL-TIME WEBSOCKET STREAM ENGINE
//   // ===========================================================================

//   Future<void> initializeRealtimeAlertsStream(String propertyId) async {
//     if (_activePropertyId == propertyId && _isConnected) return;

//     _activePropertyId = propertyId;
//     final token = await _secureStorage.getToken();

//     if (token == null || token.isEmpty) {
//       debugPrint("WebSocket initialization aborted: Auth Token unavailable.");
//       return;
//     }

//     final baseUri = Uri.parse(AppConfig.baseUrl);
//     final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';

//     final wsUrl = Uri(
//       scheme: wsScheme,
//       host: baseUri.host,
//       port: baseUri.port,
//       path: '${baseUri.path}/ws/alerts/$propertyId',
//       queryParameters: {'token': token},
//     );

//     debugPrint("[WS Stream Launcher] Connecting to alert pipeline: $wsUrl");

//     try {
//       _wsChannel = WebSocketChannel.connect(wsUrl);
//       _isConnected = true;
//       _currentReconnectDelayMs = _initialReconnectDelayMs;
//       notifyListeners();

//       _startSocketHeartbeat();

//       _wsChannel!.stream.listen(
//         (message) => _onIncomingAlertReceived(message),
//         onDone: () => _handleSocketClosedEvent(),
//         onError: (err) => debugPrint("[WS ERROR] Pipeline Crash: $err"),
//       );
//     } catch (e) {
//       debugPrint("WebSocket initialization error: $e");
//       _handleSocketClosedEvent();
//     }
//   }

//   void _onIncomingAlertReceived(dynamic incomingData) {
//     try {
//       final payload = jsonDecode(incomingData.toString());

//       if (payload['type'] == 'new_alert') {
//         debugPrint("🚨 Security anomaly detected via stream channel: $payload");

//         final message =
//             payload['message'] ?? 'Perimeter violation alert triggered!';
//         final cameraName = payload['camera_name'] ?? 'Unknown Camera';

//         // Post high-priority heads-up banner to phone system notification drawer
//         _notificationService.showAlertNotification(
//           title: "🚨 INTRUSION THREAT REPORTED",
//           body: "$message (Cam: $cameraName)",
//           id: DateTime.now().millisecond,
//         );

//         // ✅ FIXED: Wrap inside a post-frame callback schedule routine to stop state crashes
//         if (_activePropertyId != null) {
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             loadAlerts(_activePropertyId!,
//                 filter: _currentFilter, silent: true);
//           });
//         }
//       }
//     } catch (e) {
//       debugPrint("Exception caught decoding packet data segment: $e");
//     }
//   }

//   void _startSocketHeartbeat() {
//     _heartbeatTimer?.cancel();
//     _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
//       if (_wsChannel != null && _isConnected) {
//         _wsChannel!.sink.add(jsonEncode({
//           'type': 'ping',
//           'timestamp': DateTime.now().millisecondsSinceEpoch
//         }));
//       }
//     });
//   }

//   void _handleSocketClosedEvent() {
//     _isConnected = false;
//     _heartbeatTimer?.cancel();
//     notifyListeners();

//     if (_activePropertyId == null) return;

//     debugPrint(
//         "[WS Closed] Interface line severed. Retrying stream loop in $_currentReconnectDelayMs ms...");

//     _reconnectTimer?.cancel();
//     _reconnectTimer =
//         Timer(Duration(milliseconds: _currentReconnectDelayMs.toInt()), () {
//       initializeRealtimeAlertsStream(_activePropertyId!);
//     });

//     _currentReconnectDelayMs = (_currentReconnectDelayMs * 2)
//         .clamp(_initialReconnectDelayMs, _maxReconnectDelayMs);
//   }

//   void disconnectStreamCleanly() {
//     _activePropertyId = null;
//     _heartbeatTimer?.cancel();
//     _reconnectTimer?.cancel();
//     _wsChannel?.sink.close();
//     _isConnected = false;
//   }

//   @override
//   void dispose() {
//     disconnectStreamCleanly();
//     super.dispose();
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/providers/base_provider.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../models/alert_model.dart';
import '../../../repositories/alert_repository.dart';

class AlertProvider extends BaseProvider {
  final AlertRepository alertRepository;
  final SecureStorageService _secureStorage = SecureStorageService();
  final NotificationService _notificationService = NotificationService();

  List<AlertModel> _alerts = [];
  List<AlertModel> get alerts => _alerts;

  AlertModel? _selectedAlert;
  AlertModel? get selectedAlert => _selectedAlert;

  AlertModel? _latestAlert;
  AlertModel? get latestAlert => _latestAlert;

  String _currentFilter = 'new';
  String get currentFilter => _currentFilter;

  WebSocketChannel? _wsChannel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _isConnected = false;

  final double _initialReconnectDelayMs = 1000;
  final double _maxReconnectDelayMs = 30000;
  double _currentReconnectDelayMs = 1000;

  String? _activePropertyId;

  AlertProvider({required this.alertRepository});

  bool get isConnected => _isConnected;

  // ===========================================================================
  // EXISTING METHODS
  // ===========================================================================

  Future<void> loadAlerts(String propertyId,
      {String filter = 'new', bool silent = false}) async {
    try {
      _currentFilter = filter;
      if (!silent) setLoading();
      _alerts = await alertRepository.getAlerts(propertyId, filter: filter);
      setSuccess();
    } on ApiException catch (e) {
      if (!silent) setError(e.message);
    } catch (e) {
      if (!silent) setError('Failed to load alerts');
    }
  }

  Future<void> loadAlertDetail(String alertId) async {
    try {
      setLoading();
      _selectedAlert = await alertRepository.getAlert(alertId);
      setSuccess();
    } on ApiException catch (e) {
      setError(e.message);
    } catch (e) {
      setError('Failed to load alert');
    }
  }

  Future<bool> markAsRead(String alertId) async {
    try {
      await alertRepository.markAsRead(alertId);
      final index = _alerts.indexWhere((a) => a.id == alertId);
      if (index != -1) {
        _alerts[index] = AlertModel(
          id: _alerts[index].id,
          type: _alerts[index].type,
          cameraName: _alerts[index].cameraName,
          timestamp: _alerts[index].timestamp,
          isRead: true,
          confidence: _alerts[index].confidence,
          severity: _alerts[index].severity,
          imageUrl: _alerts[index].imageUrl,
          clipUrl: _alerts[index].clipUrl,
          cameraCell: _alerts[index].cameraCell,
          status: _alerts[index].status,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAsFalsePositive(String alertId) async {
    try {
      await alertRepository.markAsFalsePositive(alertId);
      _alerts.removeWhere((a) => a.id == alertId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> resolveAlert(String alertId) async {
    try {
      await alertRepository.resolveAlert(alertId);
      _alerts.removeWhere((a) => a.id == alertId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAlert(String alertId) async {
    try {
      await alertRepository.deleteAlert(alertId);
      _alerts.removeWhere((a) => a.id == alertId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // REAL-TIME WEBSOCKET STREAM ENGINE
  // ===========================================================================

  Future<void> initializeRealtimeAlertsStream(String propertyId) async {
    if (_activePropertyId == propertyId && _isConnected) return;

    _activePropertyId = propertyId;
    final token = await _secureStorage.getToken();

    if (token == null || token.isEmpty) {
      debugPrint("WebSocket initialization aborted: Auth Token unavailable.");
      return;
    }

    final baseUri = Uri.parse(AppConfig.baseUrl);
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';

    final wsUrl = Uri(
      scheme: wsScheme,
      host: baseUri.host,
      port: baseUri.port,
      path: '${baseUri.path}/ws/alerts/$propertyId',
      queryParameters: {'token': token},
    );

    debugPrint("[WS Stream Launcher] Connecting to alert pipeline: $wsUrl");

    try {
      _wsChannel = WebSocketChannel.connect(wsUrl);
      _isConnected = true;
      _currentReconnectDelayMs = _initialReconnectDelayMs;
      notifyListeners();

      _startSocketHeartbeat();

      _wsChannel!.stream.listen(
        (message) => _onIncomingAlertReceived(message),
        onDone: () => _handleSocketClosedEvent(),
        onError: (err) => debugPrint("[WS ERROR] Pipeline Crash: $err"),
      );
    } catch (e) {
      debugPrint("WebSocket initialization error: $e");
      _handleSocketClosedEvent();
    }
  }

  void _onIncomingAlertReceived(dynamic incomingData) {
    try {
      final payload = jsonDecode(incomingData.toString());

      if (payload['type'] == 'new_alert') {
        debugPrint("🚨 Security anomaly detected via stream channel: $payload");

        final alertId = payload['alert_number']?.toString() ?? '0';
        final message =
            payload['message'] ?? 'Perimeter violation alert triggered!';
        final cameraName = payload['camera_name'] ?? 'Unknown Camera';

        _notificationService.showAlertNotification(
          title: "🚨 INTRUSION THREAT REPORTED",
          body: "$message (Cam: $cameraName)",
          alertId: alertId,
          id: DateTime.now().millisecond,
        );

        if (_activePropertyId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await loadAlerts(_activePropertyId!,
                filter: _currentFilter, silent: true);
            if (_alerts.isNotEmpty) {
              _latestAlert = _alerts.first;
              notifyListeners();
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Exception caught decoding packet data segment: $e");
    }
  }

  void _startSocketHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_wsChannel != null && _isConnected) {
        _wsChannel!.sink.add(jsonEncode({
          'type': 'ping',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }));
      }
    });
  }

  void _handleSocketClosedEvent() {
    _isConnected = false;
    _heartbeatTimer?.cancel();
    notifyListeners();

    if (_activePropertyId == null) return;

    debugPrint(
        "[WS Closed] Interface line severed. Retrying stream loop in $_currentReconnectDelayMs ms...");

    _reconnectTimer?.cancel();
    _reconnectTimer =
        Timer(Duration(milliseconds: _currentReconnectDelayMs.toInt()), () {
      initializeRealtimeAlertsStream(_activePropertyId!);
    });

    _currentReconnectDelayMs = (_currentReconnectDelayMs * 2)
        .clamp(_initialReconnectDelayMs, _maxReconnectDelayMs);
  }

  void disconnectStreamCleanly() {
    _activePropertyId = null;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _wsChannel?.sink.close();
    _isConnected = false;
  }

  void clearLatestAlert() {
    _latestAlert = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnectStreamCleanly();
    super.dispose();
  }
}
