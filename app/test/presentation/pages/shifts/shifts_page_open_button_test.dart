// Regression test for the 2026-09-21 manual QA finding: when no shift is
// currently open, ShiftsPage's header is supposed to show an "Открыть
// смену" OutlinedButton (the only way to reach OpenShiftPage — there is no
// other entry point in the app). Instead, rendering it threw "BoxConstraints
// forces an infinite width" (shifts_page.dart:124, OutlinedButton placed
// directly in the header Row next to a Spacer()), and Flutter's rendering
// layer silently swallowed the exception — the button never painted, with
// no visible error and no crash of the rest of the page, making the whole
// "open a shift" flow unreachable from the UI. Fixed by wrapping the button
// in IntrinsicWidth so it reports a finite width to the Row instead of
// inheriting the Row's own unbounded incoming constraint.
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_bloc.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_event.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_state.dart';
import 'package:dukonpro/presentation/pages/shifts/shifts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockShiftBloc extends MockBloc<ShiftEvent, ShiftState>
    implements ShiftBloc {}

void main() {
  late _MockShiftBloc shiftBloc;

  setUp(() {
    shiftBloc = _MockShiftBloc();
    when(() => shiftBloc.state)
        .thenReturn(const ShiftLoaded(currentShift: null, shifts: []));
  });

  tearDown(() {
    shiftBloc.close();
  });

  testWidgets(
      'renders the "Открыть смену" header button without throwing when no '
      'shift is open, and it navigates to /shifts/open', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/shifts',
      routes: [
        GoRoute(
          path: '/shifts',
          builder: (context, state) => BlocProvider<ShiftBloc>.value(
            value: shiftBloc,
            child: const ShiftsPage(storeId: 'store-1'),
          ),
        ),
        GoRoute(
          path: '/shifts/open',
          builder: (context, state) => const Scaffold(
            body: Text('Open Shift Stub'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Открыть смену'), findsOneWidget);

    await tester.tap(find.text('Открыть смену'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Open Shift Stub'), findsOneWidget);
  });
}
