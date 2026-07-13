import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/property_context_provider.dart';
import '../../drones/provider/drone_provider.dart';
import '../provider/drone_control_provider.dart';
import '../../dashboard/provider/dashboard_provider.dart'; // <--- NEW IMPORT

class DroneControlScreen extends StatefulWidget {
  const DroneControlScreen({super.key});

  @override
  State<DroneControlScreen> createState() => _DroneControlScreenState();
}

class _DroneControlScreenState extends State<DroneControlScreen> {
  // Direct Hardware UDP Properties
  String targetIp = '192.168.0.200';
  int targetPort = 5000;
  bool isConnected = false;
  bool isArmed = false;

  RawDatagramSocket? _udpSocket;

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHardwareNetworkSettings();
    _initDirectUdpSocket();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initGlobalDroneContext();
    });
  }

  void _initGlobalDroneContext() {
    final propertyId =
        context.read<PropertyContextProvider>().selectedPropertyId;
    final property = context.read<PropertyContextProvider>().selectedProperty;

    if (propertyId != null) {
      context.read<DroneProvider>().loadDrones(propertyId);
    }
    if (property != null) {
      context.read<DroneControlProvider>().setGridBounds(
            property.laserGrid.yLasers,
            property.laserGrid.xLasers,
          );
    }
  }

  Future<void> _loadHardwareNetworkSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      targetIp = prefs.getString('targetIp') ?? '192.168.0.200';
      targetPort = prefs.getInt('targetPort') ?? 5000;
      _ipController.text = targetIp;
      _portController.text = targetPort.toString();
    });
  }

  Future<void> _saveHardwareNetworkSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('targetIp', _ipController.text);
    await prefs.setInt(
        'targetPort', int.tryParse(_portController.text) ?? 5000);
    setState(() {
      targetIp = _ipController.text;
      targetPort = int.tryParse(_portController.text) ?? 5000;
    });
  }

  Future<void> _initDirectUdpSocket() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      debugPrint("Direct local UDP socket open on port: ${_udpSocket?.port}");
    } catch (e) {
      debugPrint("Failed to bind raw socket interface: $e");
    }
  }

  // Pure Hardware UDP Transmissions
  void _sendDirectPacket(Map<String, dynamic> jsonPayload) {
    if (_udpSocket == null) return;
    try {
      final address = InternetAddress(targetIp);
      final byteStream = utf8.encode(jsonEncode(jsonPayload));
      _udpSocket!.send(byteStream, address, targetPort);
    } catch (e) {
      debugPrint("Direct UDP Transmission Crash: $e");
    }
  }

  void _fireEmergencyKill() {
    for (int i = 0; i < 5; i++) {
      _sendDirectPacket({"kill": true});
    }
    setState(() {
      isArmed = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Center(
            child: Text('EMERGENCY KILL SENT',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        backgroundColor: AppColors.danger,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showNetworkConfigurationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Pi 4 Network Link",
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.surface,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _ipController,
                  decoration:
                      const InputDecoration(labelText: "Pi 4 IP Address"),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _portController,
                  decoration:
                      const InputDecoration(labelText: "Target Drone Port"),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel",
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                _saveHardwareNetworkSettings();
                Navigator.pop(context);
              },
              child: const Text("Save Link",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _udpSocket?.close();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer3<DroneProvider, DroneControlProvider,
            PropertyContextProvider>(
          builder: (context, droneP, controlP, propertyP, _) {
            return Column(
              children: [
                /// 1. DYNAMIC SYSTEM ACTION BAR
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      _buildNetworkStatusToggle(),
                      const Spacer(),
                      _buildArmStatusToggle(),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.settings,
                            color: AppColors.textSecondary),
                        onPressed: _showNetworkConfigurationDialog,
                      )
                    ],
                  ),
                ),

                /// 2. LIVE FPV VIDEO STREAM (Now using DashboardProvider)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Container(
                      width: double.infinity,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.surfaceBorder, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Builder(
                        builder: (context) {
                          // Get the drone stream URL from DashboardProvider instead!
                          final dashboardData =
                              context.watch<DashboardProvider>().dashboardData;
                          final droneFeed = dashboardData?.drones.firstOrNull;

                          final hasStream = droneFeed?.streamUrl != null &&
                              droneFeed!.streamUrl!.isNotEmpty;

                          if (hasStream) {
                            return Mjpeg(
                              isLive: true,
                              stream: droneFeed!.streamUrl!, // <--- FIXED
                              fit: BoxFit.cover,
                              error: (context, error, stack) => const Center(
                                child: Icon(Icons.broken_image,
                                    color: Colors.white54, size: 48),
                              ),
                              loading: (context) => const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary),
                              ),
                            );
                          } else {
                            return const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.videocam_off,
                                    color: Colors.white54, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  "FPV Stream Offline",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),

                /// 3. STEPPED FLIGHT MODE ACTIONS
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _actionButton('TAKEOFF', AppColors.primary, () {
                          _sendDirectPacket({"macro": "takeoff"});
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionButton('LAND', AppColors.danger, () {
                          _sendDirectPacket({"macro": "land"});
                        }),
                      ),
                    ],
                  ),
                ),

                /// 4. CONTINUOUS MOTION ACTION PAD
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GestureDetector(
                    onTapDown: (_) =>
                        _sendDirectPacket({"macro": "pitch_forward_start"}),
                    onTapUp: (_) =>
                        _sendDirectPacket({"macro": "pitch_forward_stop"}),
                    onTapCancel: () =>
                        _sendDirectPacket({"macro": "pitch_forward_stop"}),
                    child: Container(
                      width: double.infinity,
                      height: 55,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.4),
                            width: 1.5),
                      ),
                      child: const Text(
                        "HOLD TO PITCH FORWARD",
                        style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1),
                      ),
                    ),
                  ),
                ),

                /// 5. ROTATIONAL & NUDGE CONTROL MATRIX
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Yaw Automation Sub-Stack
                      Column(
                        children: [
                          _circleMacroButton(
                              'YAW L',
                              () =>
                                  _sendDirectPacket({"macro": "yaw_left_90"})),
                          const SizedBox(height: 12),
                          _circleMacroButton(
                              'YAW R',
                              () =>
                                  _sendDirectPacket({"macro": "yaw_right_90"})),
                        ],
                      ),
                      // Directional Pad Core
                      Column(
                        children: [
                          _dpadButton(Icons.keyboard_arrow_up, () {
                            _sendDirectPacket({"macro": "pitch_front"});
                            controlP.moveUp();
                          }),
                          Row(
                            children: [
                              _dpadButton(Icons.keyboard_arrow_left, () {
                                _sendDirectPacket({"macro": "roll_left"});
                                controlP.moveLeft();
                              }),
                              const SizedBox(width: 4),
                              _buildCoordinateIndicator(controlP),
                              const SizedBox(width: 4),
                              _dpadButton(Icons.keyboard_arrow_right, () {
                                _sendDirectPacket({"macro": "roll_right"});
                                controlP.moveRight();
                              }),
                            ],
                          ),
                          _dpadButton(Icons.keyboard_arrow_down, () {
                            _sendDirectPacket({"macro": "pitch_back"});
                            controlP.moveDown();
                          }),
                        ],
                      ),
                      // Emergency Termination Sub-Stack
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _fireEmergencyKill,
                            child: Container(
                              width: 75,
                              height: 130,
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppColors.danger, width: 2),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.gpp_bad,
                                      color: AppColors.danger, size: 28),
                                  SizedBox(height: 8),
                                  Text("KILL",
                                      style: TextStyle(
                                          color: AppColors.danger,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          letterSpacing: 1)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Sub-Layout Widgets Blocks
  Widget _buildNetworkStatusToggle() {
    return Row(
      children: [
        Icon(Icons.link,
            color: isConnected ? AppColors.success : AppColors.textSecondary,
            size: 18),
        const SizedBox(width: 4),
        Switch(
          value: isConnected,
          activeThumbColor: AppColors.success, // <--- FIXED DEPRECATION
          activeTrackColor: AppColors.success.withValues(alpha: 0.5),
          onChanged: (val) {
            setState(() {
              isConnected = val;
              if (!isConnected && isArmed) {
                isArmed = false;
                _sendDirectPacket({"command": "disarm"});
              }
            });
            _sendDirectPacket({"command": val ? "connect" : "disconnect"});
          },
        ),
      ],
    );
  }

  Widget _buildArmStatusToggle() {
    return Row(
      children: [
        Icon(Icons.lock_open,
            color: isArmed ? AppColors.danger : AppColors.textSecondary,
            size: 18),
        const SizedBox(width: 4),
        Switch(
          value: isArmed,
          activeThumbColor: AppColors.danger, // <--- FIXED DEPRECATION
          activeTrackColor: AppColors.danger.withValues(alpha: 0.5),
          onChanged: isConnected
              ? (val) {
                  setState(() => isArmed = val);
                  _sendDirectPacket({"command": val ? "arm" : "disarm"});
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildCoordinateIndicator(DroneControlProvider controlP) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Center(
        child: Text(
          '${controlP.currentPosition.col},${controlP.currentPosition.row}',
          style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12),
        ),
      ),
    );
  }

  Widget _actionButton(String text, Color borderColor, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: borderColor,
        fixedSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              BorderSide(color: borderColor.withValues(alpha: 0.6), width: 1.5),
        ),
      ),
      onPressed: onTap,
      child: Text(text,
          style:
              const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }

  Widget _circleMacroButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: 60,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        onPressed: onTap,
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _dpadButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 55,
        height: 55,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 28),
      ),
    );
  }
}
