import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/l10n.dart';
import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

/// Raíz de la aplicación: tema, textos y navegación con go_router (design.md §7 y §14). Por ahora
/// el único idioma es el español; agregar otro es sumar su `.arb`.
class TurnosApp extends ConsumerWidget {
  const TurnosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
