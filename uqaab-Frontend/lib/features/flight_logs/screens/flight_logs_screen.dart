import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/property_context_provider.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../provider/flight_log_provider.dart';

class FlightLogsScreen extends StatefulWidget {
  const FlightLogsScreen({super.key});
  @override
  State<FlightLogsScreen> createState() => _FlightLogsScreenState();
}

class _FlightLogsScreenState extends State<FlightLogsScreen> {
  @override
  void initState() {
    super.initState();
    final pid = context.read<PropertyContextProvider>().selectedPropertyId;
    if (pid != null) context.read<FlightLogProvider>().loadFlightLogs(pid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: AppStrings.flightLogs),
      body: Consumer<FlightLogProvider>(builder: (context, provider, _) {
        if (provider.isLoading) return const LoadingWidget();
        if (provider.logs.isEmpty) return const EmptyState(icon: Icons.list_alt, title: 'No flight logs yet');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.logs.length,
          itemBuilder: (context, index) {
            final log = provider.logs[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(log.droneName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text(log.type, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('Takeoff: ${log.takeoffTime}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                Text('Land: ${log.landTime}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]),
            );
          },
        );
      }),
    );
  }
}