// Regression coverage for #1: editing a product must dispatch the event
// that seeds ProductFormBloc.editingProductId, so ProductFormSubmit later
// calls updateProduct instead of createProduct (which silently created a
// duplicate product instead of saving the edit).
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/domain/entities/product.dart';
import 'package:dukonpro/domain/repositories/product_repository.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/category/category_bloc.dart';
import 'package:dukonpro/presentation/blocs/category/category_event.dart';
import 'package:dukonpro/presentation/blocs/category/category_state.dart';
import 'package:dukonpro/presentation/blocs/product/product_form_bloc.dart';
import 'package:dukonpro/presentation/blocs/product/product_form_event.dart';
import 'package:dukonpro/presentation/blocs/product/product_form_state.dart';
import 'package:dukonpro/presentation/blocs/product/product_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/product/product_list_event.dart';
import 'package:dukonpro/presentation/blocs/product/product_list_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/blocs/supplier/supplier_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/supplier/supplier_list_event.dart';
import 'package:dukonpro/presentation/blocs/supplier/supplier_list_state.dart';
import 'package:dukonpro/presentation/pages/product/add_product_step1_page.dart';
import 'package:dukonpro/presentation/pages/product/add_product_step2_page.dart';
import 'package:dukonpro/presentation/pages/product/add_product_step3_page.dart';
import 'package:dukonpro/presentation/widgets/common/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

class MockProductRepository extends Mock implements ProductRepository {}

class MockCategoryBloc extends MockBloc<CategoryEvent, CategoryState>
    implements CategoryBloc {}

class MockProductFormBloc extends MockBloc<ProductFormEvent, ProductFormState>
    implements ProductFormBloc {}

class MockSupplierListBloc
    extends MockBloc<SupplierListEvent, SupplierListState>
    implements SupplierListBloc {}

class MockProductListBloc extends MockBloc<ProductListEvent, ProductListState>
    implements ProductListBloc {}

void main() {
  Product mkProduct({String id = 'prod-edit-1'}) => Product(
        id: id,
        storeId: 'store-1',
        name: 'Old Name',
        sku: 'SKU1',
        barcode: '111',
        description: 'Old description',
        costPrice: 5,
        sellPrice: 10,
        wholesalePrice: 8,
        quantity: 3,
        minQuantity: 1,
        unit: 'PCS',
        createdAt: DateTime.utc(2026, 1, 1),
      );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(ProductFormReset());
  });

  group('AddProductStep1Page edit-mode wiring (mocked bloc)', () {
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

    Future<void> pumpStep1(WidgetTester tester, {Object? extra}) async {
      final router = GoRouter(
        initialLocation: '/products/add',
        initialExtra: extra,
        routes: [
          GoRoute(
            path: '/products/add',
            builder: (_, _) => const AddProductStep1Page(),
          ),
        ],
      );
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<StoreBloc>.value(value: storeBloc),
            BlocProvider<CategoryBloc>.value(value: categoryBloc),
            BlocProvider<ProductFormBloc>.value(value: productFormBloc),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ru'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
        'dispatches ProductFormStartEditing with the in-hand product when '
        'entered with isEditing: true (#1)', (tester) async {
      final product = mkProduct();
      await pumpStep1(tester, extra: {'product': product, 'isEditing': true});

      final captured = verify(() => productFormBloc.add(captureAny(
            that: isA<ProductFormStartEditing>(),
          ))).captured;
      expect(captured, hasLength(1));
      final event = captured.single as ProductFormStartEditing;
      expect(event.product.id, product.id);
      expect(event.product.name, product.name);

      verifyNever(() => productFormBloc.add(any(that: isA<ProductFormReset>())));
    });

    testWidgets(
        'dispatches ProductFormReset (not StartEditing) when entered fresh '
        'for a new product, guarding against a leftover editingProductId '
        'from an abandoned edit', (tester) async {
      await pumpStep1(tester, extra: null);

      verify(() => productFormBloc.add(any(that: isA<ProductFormReset>())))
          .called(1);
      verifyNever(
          () => productFormBloc.add(any(that: isA<ProductFormStartEditing>())));
    });
  });

  group('Editing a product end-to-end (real bloc + fake repository)', () {
    late MockProductRepository repository;
    late ProductFormBloc productFormBloc;
    late MockStoreBloc storeBloc;
    late MockCategoryBloc categoryBloc;
    late MockSupplierListBloc supplierListBloc;
    late MockProductListBloc productListBloc;

    setUp(() {
      repository = MockProductRepository();
      productFormBloc = ProductFormBloc(productRepository: repository);
      storeBloc = MockStoreBloc();
      categoryBloc = MockCategoryBloc();
      supplierListBloc = MockSupplierListBloc();
      productListBloc = MockProductListBloc();
      when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
      when(() => categoryBloc.state).thenReturn(CategoryInitial());
      when(() => supplierListBloc.state).thenReturn(SupplierListInitial());
      when(() => productListBloc.state).thenReturn(ProductListInitial());
      when(() => repository.updateProduct(any(), any(), any()))
          .thenAnswer((_) async => mkProduct());
    });

    tearDown(() => productFormBloc.close());

    Future<void> pumpFlow(WidgetTester tester, Product product) async {
      final router = GoRouter(
        initialLocation: '/products/add',
        initialExtra: {'product': product, 'isEditing': true},
        routes: [
          GoRoute(
            path: '/products/add',
            builder: (_, _) => const AddProductStep1Page(),
          ),
          GoRoute(
            path: '/products/add/step2',
            builder: (_, _) => const AddProductStep2Page(),
          ),
          GoRoute(
            path: '/products/add/step3',
            builder: (_, _) => const AddProductStep3Page(),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
        ],
      );
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<StoreBloc>.value(value: storeBloc),
            BlocProvider<CategoryBloc>.value(value: categoryBloc),
            BlocProvider<ProductFormBloc>.value(value: productFormBloc),
            BlocProvider<SupplierListBloc>.value(value: supplierListBloc),
            BlocProvider<ProductListBloc>.value(value: productListBloc),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ru'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
        'submitting an edit through all 3 steps calls updateProduct, not '
        'createProduct (#1)', (tester) async {
      final product = mkProduct();
      await pumpFlow(tester, product);

      // Step 1 is prefilled and the bloc already knows this is an edit.
      expect(find.text('Old Name'), findsOneWidget);
      expect(productFormBloc.state.isEditing, isTrue);
      expect(productFormBloc.state.editingProductId, product.id);

      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();

      // Step 2: cost price / sell price are required fields.
      expect(find.byType(AddProductStep2Page), findsOneWidget);
      final step2Fields = find.descendant(
        of: find.byType(AddProductStep2Page),
        matching: find.byType(AppTextField),
      );
      await tester.enterText(step2Fields.at(0), '15');
      await tester.enterText(step2Fields.at(1), '25');
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();

      // Step 3: quantity is a required field.
      expect(find.byType(AddProductStep3Page), findsOneWidget);
      final step3Fields = find.descendant(
        of: find.byType(AddProductStep3Page),
        matching: find.byType(AppTextField),
      );
      await tester.enterText(step3Fields.at(0), '5');
      await tester.tap(find.text('Добавить товар'));
      await tester.pumpAndSettle();

      final captured = verify(
        () => repository.updateProduct(
            captureAny(), captureAny(), captureAny()),
      ).captured;
      expect(captured[0], 'test-store-id');
      expect(captured[1], product.id);
      verifyNever(() => repository.createProduct(any(), any()));
    });
  });
}
