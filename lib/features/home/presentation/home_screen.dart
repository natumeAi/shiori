import 'package:flutter/material.dart';
import 'package:shiori/l10n/l10n.dart';

/// Placeholder landing screen. Exercises routing, theme, and l10n until the
/// first real feature replaces or extends it.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.homeWelcome,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: .center,
          ),
        ),
      ),
    );
  }
}
