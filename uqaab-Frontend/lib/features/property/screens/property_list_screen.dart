import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/providers/property_context_provider.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../auth/provider/auth_provider.dart';
import '../provider/property_provider.dart';
import '../widgets/property_card.dart';

class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  bool _initialLoadDone = false;
  final Set<String> _selectedPropertyIds = {};

  bool get _hasSelection => _selectedPropertyIds.isNotEmpty;

  void _togglePropertySelection(String propertyId) {
    setState(() {
      if (_selectedPropertyIds.contains(propertyId)) {
        _selectedPropertyIds.remove(propertyId);
      } else {
        _selectedPropertyIds.add(propertyId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPropertyIds.clear();
    });
  }

  Future<void> _deleteSelectedProperties() async {
    if (_selectedPropertyIds.isEmpty) return;

    final selectedProperties = context
        .read<PropertyProvider>()
        .properties
        .where((property) => _selectedPropertyIds.contains(property.id))
        .toList();

    final message = selectedProperties.length == 1
        ? 'Delete "${selectedProperties.first.name}"?'
        : 'Delete ${selectedProperties.length} selected properties?';

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Properties',
      message: message,
    );

    if (confirmed != true || !mounted) return;

    final contextProvider = context.read<PropertyContextProvider>();
    final selectedPropertyId = contextProvider.selectedPropertyId;
    final deleted = await context
        .read<PropertyProvider>()
        .deleteProperties(_selectedPropertyIds.toList());

    if (!mounted || !deleted) return;

    if (selectedPropertyId != null &&
        _selectedPropertyIds.contains(selectedPropertyId)) {
      contextProvider.clearSelection();
    }

    _clearSelection();

    if (context.read<PropertyProvider>().properties.isEmpty && mounted) {
      contextProvider.clearSelection();
      context.go(AppRoutes.welcome);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProperties();
    });
  }

  Future<void> _loadProperties() async {
    await context.read<PropertyProvider>().loadProperties();

    if (!mounted) return;

    setState(() {
      _initialLoadDone = true;
    });

    // Only redirect AFTER load completes and list is truly empty
    final properties = context.read<PropertyProvider>().properties;
    final contextProvider = context.read<PropertyContextProvider>();
    if (properties.isEmpty && mounted) {
      contextProvider.clearSelection();
      context.go(AppRoutes.welcome);
      return;
    }

    if (contextProvider.selectedPropertyId != null &&
        !properties.any(
            (property) => property.id == contextProvider.selectedPropertyId)) {
      contextProvider.clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          _hasSelection
              ? '${_selectedPropertyIds.length} selected'
              : AppStrings.yourProperties,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          if (_hasSelection) ...[
            IconButton(
              tooltip: 'Delete selected',
              onPressed: _deleteSelectedProperties,
              icon: const Icon(Icons.delete_outline),
              color: AppColors.danger,
            ),
            IconButton(
              tooltip: 'Clear selection',
              onPressed: _clearSelection,
              icon: const Icon(Icons.close),
              color: AppColors.textSecondary,
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    context.go(AppRoutes.login);
                  }
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Logout'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.surfaceBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      body: Consumer<PropertyProvider>(
        builder: (context, provider, _) {
          // Show loading until initial load is done
          if (provider.isLoading || !_initialLoadDone) {
            return const LoadingWidget(message: 'Loading properties...');
          }

          if (provider.hasError) {
            return ErrorState(
              message: provider.errorMessage,
              onRetry: () => _loadProperties(),
            );
          }

          // If empty after load, show empty state briefly
          // (redirect already triggered in _loadProperties)
          if (provider.properties.isEmpty) {
            return const LoadingWidget(message: 'Redirecting...');
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.properties.length,
            itemBuilder: (context, index) {
              final property = provider.properties[index];
              return PropertyCard(
                property: property,
                onTap: () {
                  if (_hasSelection) {
                    _togglePropertySelection(property.id);
                    return;
                  }
                  context
                      .read<PropertyContextProvider>()
                      .selectProperty(property);
                  context.go(AppRoutes.dashboard);
                },
                onLongPress: () => _togglePropertySelection(property.id),
                selected: _selectedPropertyIds.contains(property.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addProperty),
        child: const Icon(Icons.add),
      ),
    );
  }
}
