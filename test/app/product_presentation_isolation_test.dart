import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/diagnostics/data/method_channel_presentation_probe.dart';
import 'package:shiori/app/startup_screen.dart';
import 'package:shiori/main.dart' as product;

void main() {
  testWidgets('product entry point never calls presentation install', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    const channel = MethodChannel(MethodChannelPresentationProbe.channelName);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final originalErrorHandler = FlutterError.onError;
    final originalPlatformHandler = tester.platformDispatcher.onError;
    product.main();
    FlutterError.onError = originalErrorHandler;
    tester.platformDispatcher.onError = originalPlatformHandler;
    await tester.pump();
    await tester.pump();
    expect(find.byType(StartupScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
  });
}
