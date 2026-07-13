import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/property_context_provider.dart';
import '../../core/routes/app_routes.dart';
import '../alerts/provider/alert_provider.dart';

class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();

    // ✅ Kickstart the persistent background security stream globally
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final propertyId =
          context.read<PropertyContextProvider>().selectedPropertyId;
      if (propertyId != null) {
        debugPrint(
            '🚀 MainShell initialized. Launching global real-time alert listener.');
        context
            .read<AlertProvider>()
            .initializeRealtimeAlertsStream(propertyId);
      }
    });
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/alerts')) return 1;
    if (location.startsWith('/map')) return 2;
    if (location.startsWith('/drone')) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.dashboard);
        break;
      case 1:
        context.go(AppRoutes.alerts);
        break;
      case 2:
        context.go(AppRoutes.gridMap);
        break;
      case 3:
        context.go(AppRoutes.droneControl);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child, // ✅ Updated from child to widget.child
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.surfaceBorder, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex(context),
          onTap: (i) => _onTap(context, i),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.flight_outlined),
              activeIcon: Icon(Icons.flight),
              label: 'Drone',
            ),
          ],
        ),
      ),
    );
  }
}
