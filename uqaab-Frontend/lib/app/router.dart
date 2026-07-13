import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/routes/app_routes.dart';
import '../features/splash/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/property/screens/welcome_screen.dart';
import '../features/property/screens/property_list_screen.dart';
import '../features/property/screens/add_property_screen.dart';
import '../features/property/screens/edit_property_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/alerts/screens/alerts_screen.dart';
import '../features/alerts/screens/alert_detail_screen.dart';
import '../features/map/screens/grid_map_screen.dart';
import '../features/drone_control/screens/drone_control_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/cameras/screens/camera_manage_screen.dart';
import '../features/cameras/screens/add_camera_screen.dart';
import '../features/cameras/screens/edit_camera_screen.dart';
import '../features/cameras/screens/fence_calibration_screen.dart';
import '../features/cameras/screens/camera_cell_calibration_screen.dart';
import '../features/drones/screens/drone_manage_screen.dart';
import '../features/drones/screens/add_drone_screen.dart';
import '../features/drones/screens/edit_drone_screen.dart';
import '../features/authorized_people/screens/authorized_people_screen.dart';
import '../features/authorized_people/screens/add_person_screen.dart';
import '../features/authorized_people/screens/edit_person_screen.dart';
import '../features/flight_logs/screens/flight_logs_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    routes: [
      // ── Splash ─────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Auth ───────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),

      // ── Welcome ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),

      // ── Properties ─────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.propertyList,
        builder: (context, state) => const PropertyListScreen(),
      ),
      GoRoute(
        path: AppRoutes.addProperty,
        builder: (context, state) => const AddPropertyScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProperty,
        builder: (context, state) {
          final propertyId = state.pathParameters['id']!;
          return EditPropertyScreen(propertyId: propertyId);
        },
      ),

      // ── Main Shell with Bottom Nav ─────────────────────────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.alerts,
            builder: (context, state) => const AlertsScreen(),
          ),
          GoRoute(
            path: AppRoutes.gridMap,
            builder: (context, state) => const GridMapScreen(),
          ),
          GoRoute(
            path: AppRoutes.droneControl,
            builder: (context, state) => const DroneControlScreen(),
          ),
        ],
      ),

      // ── Alert Detail ───────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.alertDetail,
        builder: (context, state) {
          final alertId = state.pathParameters['id']!;
          return AlertDetailScreen(alertId: alertId);
        },
      ),

      // ── Settings ───────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),

      // ── Camera Management ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.manageCameras,
        builder: (context, state) => const CameraManageScreen(),
      ),
      GoRoute(
        path: AppRoutes.addCamera,
        builder: (context, state) => const AddCameraScreen(),
      ),
      GoRoute(
        path: AppRoutes.editCamera,
        builder: (context, state) {
          final cameraId = state.pathParameters['id']!;
          return EditCameraScreen(cameraId: cameraId);
        },
      ),

      // ── Fence Calibration ──────────────────────────────────────────────────
      // Triggered after a camera is created (or when editing a fence camera).
      // Query params:
      //   name        → camera display name
      //   mode        → 'update' | 'add'
      //   streamUrl   → rtsp url (draft, not yet persisted to cells)
      //   cameraType  → 'fence' | 'entrance' | 'insider'
      //   row         → grid row  (int)
      //   col         → grid col  (int)
      GoRoute(
        path: '/cameras/calibrate/:id',
        builder: (context, state) {
          final cameraId = state.pathParameters['id']!;
          final cameraName =
              state.uri.queryParameters['name'] ?? 'Camera';
          final isUpdate =
              state.uri.queryParameters['mode'] == 'update';
          final draftStreamUrl =
              state.uri.queryParameters['streamUrl'];
          final draftCameraType =
              state.uri.queryParameters['cameraType'];
          final draftRow =
              int.tryParse(state.uri.queryParameters['row'] ?? '');
          final draftCol =
              int.tryParse(state.uri.queryParameters['col'] ?? '');

          return FenceCalibrationScreen(
            cameraId: cameraId,
            cameraName: cameraName,
            isUpdate: isUpdate,
            draftStreamUrl: draftStreamUrl,
            draftCameraType: draftCameraType,
            draftRow: draftRow,
            draftCol: draftCol,
          );
        },
      ),

      // ── Cell Calibration ───────────────────────────────────────────────────
      // Reached from FenceCalibrationScreen (pushReplacement) OR directly
      // for non-fence camera types.
      // Query params: same as fence calibration above.
      GoRoute(
        path: AppRoutes.cameraCells,
        builder: (context, state) {
          final cameraId = state.pathParameters['id']!;
          final cameraName =
              state.uri.queryParameters['name'] ?? 'Camera';
          final isUpdate =
              state.uri.queryParameters['mode'] == 'update';
          final draftStreamUrl =
              state.uri.queryParameters['streamUrl'];
          final draftCameraType =
              state.uri.queryParameters['cameraType'];
          final draftRow =
              int.tryParse(state.uri.queryParameters['row'] ?? '');
          final draftCol =
              int.tryParse(state.uri.queryParameters['col'] ?? '');

          return CameraCellCalibrationScreen(
            cameraId: cameraId,
            cameraName: cameraName,
            isUpdate: isUpdate,
            draftStreamUrl: draftStreamUrl,
            draftCameraType: draftCameraType,
            draftRow: draftRow,
            draftCol: draftCol,
          );
        },
      ),

      // ── Drone Management ───────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.manageDrones,
        builder: (context, state) => const DroneManageScreen(),
      ),
      GoRoute(
        path: AppRoutes.addDrone,
        builder: (context, state) => const AddDroneScreen(),
      ),
      GoRoute(
        path: AppRoutes.editDrone,
        builder: (context, state) {
          final droneId = state.pathParameters['id']!;
          return EditDroneScreen(droneId: droneId);
        },
      ),

      // ── Authorized People ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.authorizedPeople,
        builder: (context, state) => const AuthorizedPeopleScreen(),
      ),
      GoRoute(
        path: AppRoutes.addPerson,
        builder: (context, state) => const AddPersonScreen(),
      ),
      GoRoute(
        path: AppRoutes.editPerson,
        builder: (context, state) {
          final personId = state.pathParameters['id']!;
          return EditPersonScreen(personId: personId);
        },
      ),

      // ── Flight Logs ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.flightLogs,
        builder: (context, state) => const FlightLogsScreen(),
      ),
    ],
  );
}