import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/features/servers/data/server_activation_state.dart';
import 'package:shiori/features/servers/presentation/server_activation_controller.dart';
import 'package:shiori/features/servers/presentation/server_feedback.dart';
import 'package:shiori/l10n/l10n.dart';

class ServerSetupScreen extends ConsumerStatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  ConsumerState<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends ConsumerState<ServerSetupScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _address;
  late final ServerActivationController _activation;

  @override
  void initState() {
    super.initState();
    _activation = ref.read(serverActivationControllerProvider.notifier);
    _address = TextEditingController(
      text: ref
          .read(serverActivationControllerProvider)
          .value
          ?.session
          ?.endpoint
          .normalizedText,
    );
  }

  @override
  void dispose() {
    // A route replacement can dispose during a build. The controller also
    // tolerates this cleanup after its provider has been disposed.
    Future.microtask(_activation.cancelCandidate);
    _address.dispose();
    super.dispose();
  }

  void _connect() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _activation.activate(_address.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serverActivationControllerProvider).value;
    final phase = state?.phase ?? CandidatePhase.idle;
    final busy = phase != CandidatePhase.idle;
    final l10n = context.l10n;
    final current = state?.session;
    return PopScope(
      canPop: phase != CandidatePhase.committing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && phase == CandidatePhase.validating) {
          Future.microtask(_activation.cancelCandidate);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            current == null ? l10n.serverSetupTitle : l10n.serverChangeTitle,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 20,
                    children: [
                      Text(l10n.serverSetupHelp),
                      if (current != null)
                        Text(
                          l10n.serverCurrent(current.endpoint.normalizedText),
                        ),
                      TextFormField(
                        controller: _address,
                        enabled: !busy,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: l10n.serverUrlLabel,
                          border: const OutlineInputBorder(),
                          errorMaxLines: 5,
                        ),
                        validator: (text) {
                          final issue = ServerEndpoint.parse(text ?? '').issue;
                          return issue == null
                              ? null
                              : endpointIssueMessage(context, issue);
                        },
                        onFieldSubmitted: (_) => _connect(),
                      ),
                      if (state?.failure case final failure?)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            activationFailureMessage(context, failure),
                          ),
                        ),
                      if (busy) ...[
                        LinearProgressIndicator(
                          semanticsLabel: l10n.serverConnecting,
                        ),
                        Text(
                          phase == CandidatePhase.committing
                              ? l10n.serverSaving
                              : l10n.serverConnecting,
                        ),
                        OutlinedButton(
                          onPressed: phase == CandidatePhase.validating
                              ? _activation.cancelCandidate
                              : null,
                          child: Text(l10n.commonCancel),
                        ),
                      ] else
                        FilledButton(
                          onPressed: _connect,
                          child: Text(l10n.serverConnect),
                        ),
                      Text(
                        l10n.serverLocalNetworkHelp,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
