import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/features/servers/presentation/server_activation_controller.dart';
import 'package:shiori/l10n/l10n.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activation = ref.watch(serverActivationControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.appTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: activation.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 16,
                    children: [
                      Text(context.l10n.serverRestoreFailed),
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(serverActivationControllerProvider),
                        child: Text(context.l10n.commonRetry),
                      ),
                    ],
                  )
                : CircularProgressIndicator(
                    semanticsLabel: context.l10n.serverRestoring,
                  ),
          ),
        ),
      ),
    );
  }
}
