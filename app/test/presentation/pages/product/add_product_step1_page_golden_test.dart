import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/category/category_bloc.dart';
import 'package:dukonpro/presentation/blocs/category/category_event.dart';
import 'package:dukonpro/presentation/blocs/category/category_state.dart';
import 'package:dukonpro/presentation/blocs/product/product_form_bloc.dart';
import 'package:dukonpro/presentation/blocs/product/product_form_event.dart';
import 'package:dukonpro/presentation/blocs/product/product_form_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/product/add_product_step1_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

class MockCategoryBloc extends MockBloc<CategoryEvent, CategoryState>
    implements CategoryBloc {}

class MockProductFormBloc extends MockBloc<ProductFormEvent, ProductFormState>
    implements ProductFormBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockCategoryBloc categoryBloc;
  late MockProductFormBloc productFormBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    categoryBloc = MockCategoryBloc();
    productFormBloc = MockProductFormBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => categoryBloc.state).thenReturn(CategoryInitial());
    when(() => productFormBloc.state).thenReturn(const ProductFormState());
  });

  Future<void> pumpWithRouter(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/products/add',
      routes: [
        GoRoute(
          path: '/products/add',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<StoreBloc>.value(value: storeBloc),
              BlocProvider<CategoryBloc>.value(value: categoryBloc),
              BlocProvider<ProductFormBloc>.value(value: productFormBloc),
            ],
            child: const AddProductStep1Page(),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AddProductStep1Page goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpWithRouter(tester, Brightness.light);
      await screenMatchesGolden(tester, 'add_product_step1_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpWithRouter(tester, Brightness.dark);
      await screenMatchesGolden(tester, 'add_product_step1_dark');
    });
  });
}
