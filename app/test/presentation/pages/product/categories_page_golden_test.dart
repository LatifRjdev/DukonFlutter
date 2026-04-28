import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/category/category_bloc.dart';
import 'package:dukonpro/presentation/blocs/category/category_event.dart';
import 'package:dukonpro/presentation/blocs/category/category_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/product/categories_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockCategoryBloc extends MockBloc<CategoryEvent, CategoryState>
    implements CategoryBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockCategoryBloc categoryBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    categoryBloc = MockCategoryBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => categoryBloc.state).thenReturn(CategoryInitial());
  });

  Widget page() => const CategoriesPage();

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<CategoryBloc>.value(value: categoryBloc),
        ],
        child: child,
      );

  group('CategoriesPage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'categories_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page(),
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'categories_dark');
    });
  });
}
