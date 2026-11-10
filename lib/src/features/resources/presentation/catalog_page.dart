import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/schedule_labels.dart';
import '../../../routing/session_redirect.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/user_profile_repository.dart';
import '../application/resource_providers.dart';
import '../domain/resource.dart';

/// Inicio: catálogo de recursos activos, en tiempo real (RF-02).
class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final resources = ref.watch(activeResourcesProvider);
    final isAdmin = ref.watch(currentRoleProvider).value == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.catalogTitle),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: l10n.adminTooltip,
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => context.go(AppRoutes.admin),
            ),
          IconButton(
            tooltip: l10n.myBookingsTooltip,
            icon: const Icon(Icons.event_note),
            onPressed: () => context.go(AppRoutes.myBookings),
          ),
          IconButton(
            tooltip: l10n.signOutTooltip,
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: resources.when(
        loading: () => Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.catalogLoading),
        ),
        error: (_, __) =>
            _Message(icon: Icons.cloud_off, text: l10n.catalogError),
        data: (items) => items.isEmpty
            ? _Message(icon: Icons.event_busy, text: l10n.catalogEmpty)
            : _CatalogList(items),
      ),
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList(this.resources);

  final List<Resource> resources;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = ScheduleLabels(l10n);
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.catalogHeadline, style: textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(l10n.catalogSubtitle, style: textTheme.bodyMedium),
        const SizedBox(height: 16),
        for (final resource in resources)
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_available),
              title: Text(resource.name),
              subtitle: Text(
                '${resource.description}\n'
                '${labels.slotDuration(resource.slotMinutes)}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/recursos/${resource.id}'),
            ),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
