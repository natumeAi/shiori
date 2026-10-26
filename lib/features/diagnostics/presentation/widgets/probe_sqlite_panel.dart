import 'package:flutter/material.dart';
import 'package:shiori/features/diagnostics/data/probe_sqlite_result.dart';
import 'package:shiori/l10n/l10n.dart';

class ProbeSqlitePanel extends StatelessWidget {
  const ProbeSqlitePanel({
    super.key,
    required this.result,
    required this.running,
    required this.onRun,
  });

  final ProbeSqliteResult? result;
  final bool running;
  final VoidCallback? onRun;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = result;
    String status(bool? passed) => switch (passed) {
      true => l10n.diagnosticsSqlitePass,
      false => l10n.diagnosticsSqliteFail,
      null => l10n.diagnosticsSqliteNotRun,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          l10n.diagnosticsSqliteTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(l10n.diagnosticsSqliteHelp),
        OutlinedButton(
          onPressed: onRun,
          child: Text(
            running ? l10n.diagnosticsSqliteRunning : l10n.diagnosticsSqliteRun,
          ),
        ),
        if (value == null) Text(l10n.diagnosticsSqliteNotRun),
        if (value != null) ...[
          Text(l10n.diagnosticsSqliteOutcome(status(value.passed))),
          Text(
            l10n.diagnosticsBuild(
              value.buildId,
              value.buildNumber.isEmpty
                  ? l10n.diagnosticsUnknown
                  : value.buildNumber,
            ),
          ),
          Text(
            l10n.diagnosticsSqliteCheckedAt(value.checkedAt.toIso8601String()),
          ),
          for (final step in ProbeSqliteResult.stepNames)
            Text(
              l10n.diagnosticsSqliteStep(switch (step) {
                'open' => l10n.diagnosticsSqliteOpen,
                'commit' => l10n.diagnosticsSqliteCommit,
                'reopen' => l10n.diagnosticsSqliteReopen,
                'rollback' => l10n.diagnosticsSqliteRollback,
                'futureSchema' => l10n.diagnosticsSqliteFutureSchema,
                _ => l10n.diagnosticsSqliteCleanup,
              }, status(value.steps[step])),
            ),
          SelectableText(
            l10n.diagnosticsSqliteRuntime(
              value.packageVersion,
              value.libraryVersion ?? l10n.diagnosticsUnknown,
              value.journalMode ?? l10n.diagnosticsUnknown,
              value.synchronous?.toString() ?? l10n.diagnosticsUnknown,
              value.elapsedUs,
            ),
          ),
          SelectableText(
            l10n.diagnosticsSqliteSource(
              value.sourceId ?? l10n.diagnosticsUnknown,
            ),
          ),
          SelectableText(
            l10n.diagnosticsSqliteOptions(
              value.compileOptions.isEmpty
                  ? l10n.diagnosticsUnknown
                  : value.compileOptions.join(', '),
            ),
          ),
        ],
      ],
    );
  }
}
