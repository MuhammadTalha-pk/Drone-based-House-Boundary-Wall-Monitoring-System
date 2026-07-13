// lib/features/authorized_people/screens/authorized_people_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/property_context_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../models/authorized_person_model.dart';
import '../provider/person_provider.dart';
import '../../../core/config/app_config.dart';

class AuthorizedPeopleScreen extends StatefulWidget {
  const AuthorizedPeopleScreen({super.key});

  @override
  State<AuthorizedPeopleScreen> createState() => _AuthorizedPeopleScreenState();
}

class _AuthorizedPeopleScreenState extends State<AuthorizedPeopleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pid = context.read<PropertyContextProvider>().selectedPropertyId;
      if (pid != null) context.read<PersonProvider>().loadPeople(pid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Authorized People'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addPerson),
        child: const Icon(Icons.add),
      ),
      body: Consumer<PersonProvider>(
        builder: (ctx, provider, _) {
          if (provider.isLoading) return const LoadingWidget();

          // Use hasError + errorMessage (real BaseProvider)
          if (provider.hasError) {
            return ErrorState(
              message: provider.errorMessage,
              onRetry: () {
                final pid =
                    context.read<PropertyContextProvider>().selectedPropertyId;
                if (pid != null) provider.loadPeople(pid);
              },
            );
          }

          if (provider.people.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'No Authorized People',
              subtitle: 'Add people so entrance cameras can recognize them.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.people.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final person = provider.people[i];
              return _PersonCard(
                person: person,
                onEdit: () => context
                    .push(AppRoutes.editPerson.replaceFirst(':id', person.id)),
                onDelete: () => _confirmDelete(ctx, provider, person),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext ctx,
    PersonProvider provider,
    AuthorizedPersonModel person,
  ) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove Person',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Remove ${person.name} from authorized people?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final pid =
                  context.read<PropertyContextProvider>().selectedPropertyId;
              if (pid != null) {
                await provider.deletePerson(
                    personId: person.id, propertyId: pid);
              }
            },
            child:
                const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ─── Person Card ──────────────────────────────────────────────────────────────

class _PersonCard extends StatelessWidget {
  final AuthorizedPersonModel person;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PersonCard({
    required this.person,
    required this.onEdit,
    required this.onDelete,
  });

  String _getFullUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http')) return url;

    try {
      // This forces Flutter to ignore '/api/v1' and just grab 'http://192.168.10.x:8000'
      final uri = Uri.parse(AppConfig.baseUrl);
      final hostPort = '${uri.scheme}://${uri.host}:${uri.port}';

      final path = url.startsWith('/') ? url : '/$url';
      return '$hostPort$path';
    } catch (e) {
      return url;
    }
  }

  Color get _roleColor {
    switch (person.role) {
      case 'Guard':
        return AppColors.warning;
      case 'Authorized Person':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  IconData get _roleIcon {
    switch (person.role) {
      case 'Guard':
        return Icons.security;
      case 'Authorized Person':
        return Icons.verified_user;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          // Avatar (NOW SHOWS REAL IMAGE!)
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _roleColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _roleColor.withValues(alpha: 0.4)),
            ),
            child: person.photoUrls.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.network(
                      _getFullUrl(person.photoUrls.first),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(_roleIcon, color: _roleColor, size: 26),
                    ),
                  )
                : Icon(_roleIcon, color: _roleColor, size: 26),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _badge(person.role, _roleColor),
                    if (person.hasFaceEncoding)
                      _badgeWithIcon(
                          'Face Enrolled', AppColors.success, Icons.face)
                    else
                      _badgeWithIcon('No Face', AppColors.warning,
                          Icons.warning_amber_rounded),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          PopupMenuButton<String>(
            color: AppColors.surface,
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined,
                      color: AppColors.textSecondary, size: 18),
                  SizedBox(width: 8),
                  Text('Edit', style: TextStyle(color: AppColors.textPrimary)),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                  SizedBox(width: 8),
                  Text('Remove', style: TextStyle(color: AppColors.danger)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _badgeWithIcon(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
