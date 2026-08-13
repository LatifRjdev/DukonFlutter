import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/z_report.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_bloc.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_event.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_state.dart';
import 'package:dukonpro/presentation/pages/shifts/z_report_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class _MockShiftBloc extends MockBloc<ShiftEvent, ShiftState>
    implements ShiftBloc {}

void main() {
  late _MockShiftBloc shiftBloc;

  setUp(() {
    shiftBloc = _MockShiftBloc();
    when(() => shiftBloc.state).thenReturn(ShiftInitial());
  });

  tearDown(() {
    shiftBloc.close();
  });

  Widget page() => const ZReportPage(
        storeId: 'test-store-id',
        shiftId: 'test-shift-id',
      );

  Widget wrapWithBlocs(Widget child) => BlocProvider<ShiftBloc>.value(
        value: shiftBloc,
        child: child,
      );

  group('ZReportPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'z_report_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
        size: const Size(412, 900),
      );
      tester.takeException();
      await screenMatchesGolden(tester, 'z_report_dark');
    });
  });

  // ── Non-golden content test ──────────────────────────────────────────────
  //
  // The goldens above only cover ShiftInitial (an empty SizedBox.shrink()),
  // so they never render a ZReportLoaded report and can't catch a l10n key
  // wired to the wrong call site (e.g. l10n.someOtherKey where l10n.debt
  // belongs) — a literal-diff of the ARB values alone can't catch that
  // either, since it only checks the value is correct, not where it's used.
  // This test renders a real ZReportLoaded state and pins several of the
  // extracted-string key-reuse decisions from the AppLocalizations migration.
  //
  // Intentionally NOT calling tester.takeException() here (unlike the golden
  // tests above) — that call swallows exceptions thrown during pump, which
  // would let this test stay green even if ZReportLoaded rendering crashed.
  testWidgets('renders localized labels for a loaded report', (tester) async {
    when(() => shiftBloc.state).thenReturn(ZReportLoaded(
      report: ZReport(
        staffName: 'Иван',
        openedAt: DateTime(2026, 8, 1, 9),
        closedAt: DateTime(2026, 8, 1, 18),
        duration: '9ч',
        salesCount: 3,
        salesTotal: 1500,
        returnsCount: 1,
        returnsTotal: 200,
      ),
    ));

    await pumpPageWithTheme(
      tester,
      page(),
      brightness: Brightness.light,
      wrap: wrapWithBlocs,
      size: const Size(412, 900),
    );

    expect(find.text('Z-ОТЧЁТ'), findsOneWidget); // new zReportHeaderTitle
    expect(find.text('Количество продаж'), findsOneWidget); // new zReportSalesCount
    expect(find.text('Разница'), findsOneWidget); // reused cashDifference
    expect(find.text('В долг'), findsOneWidget); // reused debt
    expect(find.text('Касса'), findsOneWidget); // reused pos
    expect(find.text('Поделиться'), findsOneWidget); // new share
  });
}
