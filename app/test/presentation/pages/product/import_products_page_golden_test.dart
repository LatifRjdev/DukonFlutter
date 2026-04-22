import 'package:bloc_test/bloc_test.dart';
import 'package:dokonpro/injection.dart';
import 'package:dokonpro/presentation/blocs/import/import_bloc.dart';
import 'package:dokonpro/presentation/blocs/import/import_event.dart';
import 'package:dokonpro/presentation/blocs/import/import_state.dart';
import 'package:dokonpro/presentation/pages/product/import_products_page.dart';
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
}
