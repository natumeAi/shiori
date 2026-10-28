/// Diagnostic-only native sampling. Calls must not run in pointer/ticker work.
abstract interface class PresentationProbe {
  Future<PresentationReport> install();
  Future<void> start({required String runId, required PresentationMode mode});
  Future<PresentationReport> stop();
  Future<void> dispose();
}

enum PresentationMode {
  inventory,
  a1,
  a2,
  b;

  String get evidence => switch (this) {
    inventory => 'metadata',
    a1 => 'layer_commit_cadence',
    a2 => 'layer_commit_cadence_per_display_period',
    b => 'system_drawable_presentation_non_product_path',
  };
}

/// Native clock timestamps remain in their own domain. No epoch is inferred.
final class PresentationReport {
  const PresentationReport({
    required this.available,
    required this.evidence,
    required this.omission,
    this.inventory = const {},
    this.samples = const [],
    this.overflow = 0,
    this.contentionDrops = 0,
    this.unmatchedCallbacks = 0,
    this.lossAccountingVersion,
  });
  final bool available;
  final String evidence;
  final String? omission;
  final Map<String, Object?> inventory;
  final List<Map<String, Object?>> samples;
  final int overflow;
  final int contentionDrops;
  final int unmatchedCallbacks;
  final int? lossAccountingVersion;
  Map<String, Object?> toJson() => {
    'available': available,
    'evidence': evidence,
    'omission': omission,
    'inventory': inventory,
    'samples': samples,
    'overflow': overflow,
    'contentionDrops': contentionDrops,
    if (lossAccountingVersion != null)
      'lossAccountingVersion': lossAccountingVersion,
    // Additive loss detail; preserve existing zero-loss fixture exports.
    if (unmatchedCallbacks > 0) 'unmatchedCallbacks': unmatchedCallbacks,
    'clock': 'native_monotonic_seconds; epoch not correlated with Dart',
    'physicalPresentation': 'unverified',
    'touchToPhoton': 'unverified',
  };
}

/// Storage-free fallback for unsupported platforms or an unavailable channel.
final class UnavailablePresentationProbe implements PresentationProbe {
  const UnavailablePresentationProbe({
    this.reason = 'native_probe_unavailable',
  });
  final String reason;
  static const report = PresentationReport(
    available: false,
    evidence: 'unverified',
    omission: 'native_probe_unavailable',
  );
  PresentationReport get _report => PresentationReport(
    available: false,
    evidence: 'unverified',
    omission: reason,
  );
  @override
  Future<PresentationReport> install() async => _report;
  @override
  Future<void> start({
    required String runId,
    required PresentationMode mode,
  }) async {}
  @override
  Future<PresentationReport> stop() async => _report;
  @override
  Future<void> dispose() async {}
}
