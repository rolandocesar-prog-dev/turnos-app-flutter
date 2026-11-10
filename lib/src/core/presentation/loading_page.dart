import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Pantalla de espera mientras se lee la sesión.
class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(semanticsLabel: context.l10n.loading),
      ),
    );
  }
}
