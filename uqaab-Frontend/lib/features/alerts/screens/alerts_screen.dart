// lib/features/alerts/screens/alerts_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/property_context_provider.dart';
// import '../../../models/alert_model.dart';
// import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../provider/alert_provider.dart';
import '../widgets/alert_card.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter = 'new';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadAlerts(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadAlerts({bool silent = false}) {
    final propertyId =
        context.read<PropertyContextProvider>().selectedPropertyId;
    if (propertyId != null) {
      context.read<AlertProvider>().loadAlerts(
            propertyId,
            filter: _filter,
            silent: silent,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final propertyName =
        context.read<PropertyContextProvider>().selectedProperty?.name ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Text('Alerts: $propertyName',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _loadAlerts,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterPill('New', 'new'),
                const SizedBox(width: 8),
                _buildFilterPill('All', 'all'),
                const Spacer(),
                Consumer<AlertProvider>(
                  builder: (context, provider, _) {
                    if (provider.alerts.isEmpty) return const SizedBox();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${provider.alerts.length} alerts',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: Consumer<AlertProvider>(
              builder: (ctx, provider, _) {
                if (provider.isLoading && provider.alerts.isEmpty) {
                  return const LoadingWidget();
                }
                if (provider.hasError && provider.alerts.isEmpty) {
                  return ErrorState(
                    message: provider.errorMessage,
                    onRetry: _loadAlerts,
                  );
                }
                if (provider.alerts.isEmpty) {
                  return const EmptyState(
                    icon: Icons.notifications_none,
                    title: 'No Alerts',
                    subtitle: 'All clear — no alerts to show.',
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => _loadAlerts(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.alerts.length,
                    itemBuilder: (context, index) {
                      final alert = provider.alerts[index];
                      return AlertCard(
                        alert: alert,
                        onTap: () async {
                          if (!alert.isRead) {
                            await context
                                .read<AlertProvider>()
                                .markAsRead(alert.id);
                          }
                          if (!context.mounted) return;
                          context.push('/alerts/${alert.id}');
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label, String value) {
    final isActive = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _loadAlerts();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
