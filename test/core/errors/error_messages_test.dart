import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/errors/error_messages.dart';
import 'package:shiori/l10n/l10n.dart';

import '../../helpers/provider_exception.dart';
import '../../helpers/pump_app.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('zh'));

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpApp(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox.shrink();
        },
      ),
    );
    return context;
  }

  final cases = <(String, Object, String)>[
    ('NetworkException', const NetworkException(), l10n.errorNetwork),
    (
      'UnauthorizedException',
      const UnauthorizedException(),
      l10n.errorUnauthorized,
    ),
    ('ServerException', const ServerException(500), l10n.errorServer),
    ('ParseException', const ParseException(), l10n.errorServer),
    ('a non-AppException error', StateError('bug'), l10n.errorUnexpected),
    (
      'a ProviderException wrapping NetworkException',
      providerException(const NetworkException()),
      l10n.errorNetwork,
    ),
    (
      'nested ProviderExceptions wrapping UnauthorizedException',
      providerException(providerException(const UnauthorizedException())),
      l10n.errorUnauthorized,
    ),
    (
      'a ProviderException wrapping a non-AppException error',
      providerException(StateError('bug')),
      l10n.errorUnexpected,
    ),
  ];

  for (final (description, error, expected) in cases) {
    testWidgets('maps $description', (tester) async {
      final context = await pumpContext(tester);

      expect(errorMessage(context, error), expected);
    });
  }
}
