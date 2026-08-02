import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/local/auth_local_datasource.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_bloc.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_event.dart';
import 'package:dukonpro/presentation/blocs/auth/auth_state.dart';
import 'package:dukonpro/presentation/widgets/home/impersonation_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDioClient extends Mock implements DioClient {}

class _MockAuthLocalDatasource extends Mock implements AuthLocalDatasource {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(AuthLogoutRequested());
  });

  late _MockDioClient dioClient;
  late _MockAuthLocalDatasource authLocal;
  late _MockAuthBloc authBloc;

  Response<T> resp<T>(T body) => Response<T>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  setUp(() {
    dioClient = _MockDioClient();
    authLocal = _MockAuthLocalDatasource();
    authBloc = _MockAuthBloc();

    if (sl.isRegistered<DioClient>()) sl.unregister<DioClient>();
    sl.registerSingleton<DioClient>(dioClient);
    if (sl.isRegistered<AuthLocalDatasource>()) {
      sl.unregister<AuthLocalDatasource>();
    }
    sl.registerSingleton<AuthLocalDatasource>(authLocal);

    when(() => authBloc.state).thenReturn(AuthInitial());
  });

  tearDown(() {
    if (sl.isRegistered<DioClient>()) sl.unregister<DioClient>();
    if (sl.isRegistered<AuthLocalDatasource>()) {
      sl.unregister<AuthLocalDatasource>();
    }
  });

  Widget wrap(Widget child) => MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: Scaffold(body: child),
        ),
      );

  group('ImpersonationBanner', () {
    testWidgets(
        'shows nothing when the stored token has no impersonationRequestId',
        (tester) async {
      when(() => authLocal.getImpersonationRequestId())
          .thenAnswer((_) async => null);

      await tester.pumpWidget(wrap(const ImpersonationBanner()));
      await tester.pumpAndSettle();

      expect(find.text('Вы вошли как поддержка Dukon'), findsNothing);
    });

    testWidgets('shows nothing when reading the claim throws', (tester) async {
      when(() => authLocal.getImpersonationRequestId())
          .thenThrow(Exception('storage unavailable'));

      await tester.pumpWidget(wrap(const ImpersonationBanner()));
      await tester.pumpAndSettle();

      expect(find.text('Вы вошли как поддержка Dukon'), findsNothing);
    });

    testWidgets(
        'shows the persistent banner when an impersonationRequestId is present',
        (tester) async {
      when(() => authLocal.getImpersonationRequestId())
          .thenAnswer((_) async => 'req-1');

      await tester.pumpWidget(wrap(const ImpersonationBanner()));
      await tester.pumpAndSettle();

      expect(find.text('Вы вошли как поддержка Dukon'), findsOneWidget);
      expect(find.text('Завершить сессию'), findsOneWidget);
    });

    testWidgets(
        'tapping "Завершить сессию" ends the session on the backend and logs out',
        (tester) async {
      when(() => authLocal.getImpersonationRequestId())
          .thenAnswer((_) async => 'req-1');
      when(() => dioClient.post<dynamic>('/admin/impersonation/req-1/end'))
          .thenAnswer((_) async => resp<dynamic>(null));

      await tester.pumpWidget(wrap(const ImpersonationBanner()));
      await tester.pumpAndSettle();

      // Not pumpAndSettle(): the button shows an indeterminate
      // CircularProgressIndicator while _ending is true, which (correctly)
      // never settles on its own in this test — the widget only leaves
      // the tree once the real app navigates away after logout, which is
      // outside this widget's scope. A couple of explicit pumps are
      // enough to let the mocked async work resolve.
      await tester.tap(find.text('Завершить сессию'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      verify(
        () => dioClient.post<dynamic>('/admin/impersonation/req-1/end'),
      ).called(1);
      verify(() => authBloc.add(any(that: isA<AuthLogoutRequested>())))
          .called(1);
    });

    testWidgets(
        'still logs out locally even if ending the session on the backend fails',
        (tester) async {
      when(() => authLocal.getImpersonationRequestId())
          .thenAnswer((_) async => 'req-1');
      when(() => dioClient.post<dynamic>('/admin/impersonation/req-1/end'))
          .thenThrow(Exception('network unavailable'));

      await tester.pumpWidget(wrap(const ImpersonationBanner()));
      await tester.pumpAndSettle();

      // Not pumpAndSettle(): the button shows an indeterminate
      // CircularProgressIndicator while _ending is true, which (correctly)
      // never settles on its own in this test — the widget only leaves
      // the tree once the real app navigates away after logout, which is
      // outside this widget's scope. A couple of explicit pumps are
      // enough to let the mocked async work resolve.
      await tester.tap(find.text('Завершить сессию'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      verify(() => authBloc.add(any(that: isA<AuthLogoutRequested>())))
          .called(1);
    });
  });
}
