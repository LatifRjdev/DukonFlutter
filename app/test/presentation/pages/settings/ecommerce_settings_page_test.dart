import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/pages/settings/ecommerce_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dioClient;

  Response<T> resp<T>(T body) => Response<T>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    dioClient = _MockDioClient();
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
    sl.registerSingleton<DioClient>(dioClient);
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) {
      sl.unregister<DioClient>();
    }
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  group('EcommerceSettingsPage', () {
    testWidgets('shows a loading indicator while fetching settings',
        (tester) async {
      final completer = Completer<Response<dynamic>>();
      when(() => dioClient
              .get<dynamic>('/stores/store-1/ecommerce/integration'))
          .thenAnswer((_) => completer.future);

      await tester
          .pumpWidget(wrap(const EcommerceSettingsPage(storeId: 'store-1')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(resp<dynamic>(null));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
        'initial load failure shows an error snackbar instead of getting '
        'stuck on the spinner', (tester) async {
      // Reject via a real Future (not a synchronous thenThrow) so the
      // failure surfaces after an await, matching how a real DioException
      // would arrive — and so the catch/setState/SnackBar dispatch happens
      // on a later frame rather than synchronously inside initState.
      when(() => dioClient
              .get<dynamic>('/stores/store-1/ecommerce/integration'))
          .thenAnswer((_) async => throw Exception('network unavailable'));

      await tester
          .pumpWidget(wrap(const EcommerceSettingsPage(storeId: 'store-1')));
      // Deliberately avoid pumpAndSettle: the error SnackBar auto-dismisses
      // after AppConstants.snackbarDuration (3s), and pumpAndSettle pumps
      // through the entire display+dismiss animation before returning, so
      // by the time it settles the SnackBar text would already be gone.
      // A couple of bounded pumps is enough to flush the failed load and
      // render the SnackBar while it's still on screen.
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Не удалось выполнить операцию'), findsOneWidget);
    });

    testWidgets(
        'not-yet-configured state shows a placeholder instead of an API key',
        (tester) async {
      when(() => dioClient
              .get<dynamic>('/stores/store-1/ecommerce/integration'))
          .thenAnswer((_) async => resp<dynamic>(null));

      await tester
          .pumpWidget(wrap(const EcommerceSettingsPage(storeId: 'store-1')));
      await tester.pumpAndSettle();

      expect(
        find.text('Сохраните настройки, чтобы создать ключ'),
        findsOneWidget,
      );
    });

    testWidgets('save button sends the webhook URL and enabled flag as PUT',
        (tester) async {
      when(() => dioClient
              .get<dynamic>('/stores/store-1/ecommerce/integration'))
          .thenAnswer((_) async => resp<dynamic>(null));
      when(() => dioClient.put<dynamic>(
            '/stores/store-1/ecommerce/integration',
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => resp<dynamic>({
          'apiKey': 'generated-key-123',
          'outboundWebhookUrl': 'https://shop.example.com/hook',
          'enabled': true,
        }),
      );

      await tester
          .pumpWidget(wrap(const EcommerceSettingsPage(storeId: 'store-1')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField), 'https://shop.example.com/hook');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      final captured = verify(() => dioClient.put<dynamic>(
            '/stores/store-1/ecommerce/integration',
            data: captureAny(named: 'data'),
          )).captured.single as Map<String, dynamic>;
      expect(captured['outboundWebhookUrl'], 'https://shop.example.com/hook');
      expect(captured['enabled'], true);

      // The API key returned by the save response should now be present and
      // copyable — masked by default (see the dedicated masking test below),
      // so it shows the reveal toggle rather than the raw key text.
      expect(find.text('generated-key-123'), findsNothing);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('copying the API key writes it to the clipboard',
        (tester) async {
      when(() => dioClient
              .get<dynamic>('/stores/store-1/ecommerce/integration'))
          .thenAnswer(
        (_) async => resp<dynamic>({
          'apiKey': 'existing-key-456',
          'outboundWebhookUrl': null,
          'enabled': true,
        }),
      );

      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester
          .pumpWidget(wrap(const EcommerceSettingsPage(storeId: 'store-1')));
      await tester.pumpAndSettle();

      // Two copy buttons exist (URL, API key) — the API key one is second.
      await tester.tap(find.byIcon(Icons.copy_outlined).last);
      await tester.pumpAndSettle();

      expect(copiedText, 'existing-key-456');
    });

    testWidgets('API key is masked by default and reveals on tap',
        (tester) async {
      when(() => dioClient
              .get<dynamic>('/stores/store-1/ecommerce/integration'))
          .thenAnswer(
        (_) async => resp<dynamic>({
          'apiKey': 'super-secret-key-value',
          'outboundWebhookUrl': null,
          'enabled': true,
        }),
      );

      await tester
          .pumpWidget(wrap(const EcommerceSettingsPage(storeId: 'store-1')));
      await tester.pumpAndSettle();

      expect(find.text('super-secret-key-value'), findsNothing);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(find.text('super-secret-key-value'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });
}
