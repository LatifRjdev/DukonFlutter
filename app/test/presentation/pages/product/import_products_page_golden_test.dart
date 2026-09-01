import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/injection.dart';
import 'package:dukonpro/presentation/blocs/import/import_bloc.dart';
import 'package:dukonpro/presentation/blocs/import/import_event.dart';
import 'package:dukonpro/presentation/blocs/import/import_state.dart';
import 'package:dukonpro/presentation/pages/product/import_products_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/golden_pump_helper.dart';

class MockImportBloc extends MockBloc<ImportEvent, ImportState>
    implements ImportBloc {}

void main() {
  late MockImportBloc importBloc;

  setUp(() {
    importBloc = MockImportBloc();
    when(() => importBloc.state).thenReturn(const ImportInitial());
    // Register mock in GetIt so ImportProductsPage's BlocProvider create: can
    // return it without touching any real datasources.
    if (sl.isRegistered<ImportBloc>()) sl.unregister<ImportBloc>();
    sl.registerFactory<ImportBloc>(() => importBloc);
  });

  tearDown(() {
    if (sl.isRegistered<ImportBloc>()) sl.unregister<ImportBloc>();
  });

  Widget page() => const ImportProductsPage(storeId: 'test-store-id');

  group('ImportProductsPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
      );
      await screenMatchesGolden(tester, 'import_products_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
      );
      await screenMatchesGolden(tester, 'import_products_dark');
    });
  });

  // ── Non-golden content test ──────────────────────────────────────────────
  //
  // The goldens above only ever render the initial (ImportInitial) state,
  // so they never render the preview/data-table screen and can't catch an
  // l10n key wired to the wrong call site. This test sets the mock bloc's
  // state directly to ImportPreviewLoaded and asserts on several of the
  // extracted-string key decisions (both new and reused keys).
  testWidgets('renders localized strings for a loaded import preview',
      (tester) async {
    when(() => importBloc.state).thenReturn(
      const ImportPreviewLoaded(
        rows: [
          {
            'name': 'Хлеб',
            'barcode': '4600000000001',
            'category': 'Выпечка',
            'salePrice': 12,
            'quantity': 5,
          },
        ],
        totalRows: 3,
        errors: [
          {'row': 2, 'message': 'Отсутствует штрихкод'},
        ],
        filePath: '/tmp/products.xlsx',
      ),
    );

    await pumpPageWithTheme(
      tester,
      page(),
      brightness: Brightness.light,
    );

    expect(find.text('3 товаров найдено'),
        findsOneWidget); // new importProductsFoundCount
    // TODO(i18n): "1 ошибок" is grammatically incorrect Russian (should be
    // "1 ошибка") — faithfully preserved from the pre-extraction literal,
    // not introduced here. Fixing the plural form requires switching this
    // placeholder from String to ICU plural, which is out of scope for a
    // byte-preserving extraction. Update this assertion if that ever lands.
    expect(
        find.text('1 ошибок'), findsOneWidget); // new importProductsErrorsBadge
    expect(find.text('Строка 2: Отсутствует штрихкод'),
        findsOneWidget); // new importProductsRowError
    expect(find.text('Штрихкод'), findsOneWidget); // reused barcode
    expect(find.text('Категория'), findsOneWidget); // reused category
    expect(find.text('Импортировать 3 товаров'),
        findsOneWidget); // new importProductsConfirmButton
  });

  // ── ImportError coverage ─────────────────────────────────────────────────
  //
  // Regression test for #27: the build method's state-switch used to fall
  // through to _InitialView for ImportError, silently hiding the failure.
  // Assert the error message and a retry action are actually visible, and
  // that the initial "pick a file" screen is NOT what's shown instead.
  testWidgets('renders visible error content for ImportError state',
      (tester) async {
    when(() => importBloc.state).thenReturn(
      const ImportError(message: 'Не удалось прочитать файл'),
    );

    await pumpPageWithTheme(
      tester,
      page(),
      brightness: Brightness.light,
    );

    expect(find.text('Не удалось прочитать файл'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget); // l10n.retry
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    // Must not silently fall through to the initial "select file" screen.
    expect(find.text('Выбрать файл'), findsNothing);

    // The retry button must be wired to a real handler (re-opens the same
    // file-picker flow as the initial screen's "select file" button), not a
    // dead no-op. The native file_picker plugin can't be driven from a
    // widget test without platform-channel mocking, so this is the level
    // of verification available without redesigning _pickFile's DI.
    // ElevatedButton.icon returns a private ElevatedButton subclass, so
    // find.widgetWithText(ElevatedButton, ...) (exact-runtimeType match)
    // wouldn't find it — use an `is ElevatedButton` predicate instead.
    final retryButton = find.ancestor(
      of: find.text('Повторить'),
      matching: find.byWidgetPredicate((widget) => widget is ElevatedButton),
    );
    expect(retryButton, findsOneWidget);
    expect((tester.widget(retryButton) as ElevatedButton).onPressed, isNotNull);
  });
}
