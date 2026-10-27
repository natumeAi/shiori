import 'package:shiori/features/library/presentation/covers/cover_failure.dart';
import 'package:shiori/features/library/presentation/covers/cover_lease.dart';

/// A success owns a lease; every other result renders a placeholder.
sealed class CoverLoadResult {
  const CoverLoadResult();
}

final class CoverLoaded extends CoverLoadResult {
  const CoverLoaded(this.lease);
  final CoverLease lease;
}

final class CoverPlaceholder extends CoverLoadResult {
  const CoverPlaceholder(this.reason);
  final CoverFailure reason;
}
