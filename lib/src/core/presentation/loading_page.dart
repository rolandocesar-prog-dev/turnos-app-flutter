import 'package:flutter/material.dart';

/// Pantalla de espera mientras se lee la sesión.
class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(semanticsLabel: 'Cargando'),
      ),
    );
  }
}
