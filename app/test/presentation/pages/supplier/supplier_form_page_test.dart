import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dukonpro/domain/entities/supplier.dart';
import 'package:dukonpro/domain/repositories/supplier_repository.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/supplier/supplier_list_bloc.dart';
import 'package:dukonpro/presentation/pages/supplier/supplier_form_page.dart';

// --- Fakes ---

class FakeSupplierRepository extends Fake implements SupplierRepository {
  @override
  Future<Supplier> createSupplier(String storeId, Map<String, dynamic> data) async {
    return Supplier(
      id: 'new-id',
      storeId: storeId,
      name: data['name'] as String,
      phone: data['phone'] as String?,
      address: data['address'] as String?,
      notes: data['notes'] as String?,
    );
  }

  @override
  Future<Supplier> updateSupplier(
    String storeId,
    String id,
    Map<String, dynamic> data,
  ) async {
    return Supplier(
      id: id,
      storeId: storeId,
      name: data['name'] as String,
      phone: data['phone'] as String?,
      address: data['address'] as String?,
      notes: data['notes'] as String?,
    );
  }

  @override
  Future<({List<Supplier> data, int total, int totalPages})> getSuppliers(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    return (data: <Supplier>[], total: 0, totalPages: 0);
  }

  @override
  Future<Supplier> getSupplier(String storeId, String id) async {
    return Supplier(id: id, storeId: storeId, name: 'Test');
  }

  @override
  Future<void> deleteSupplier(String storeId, String id) async {}
}

// --- Helpers ---

Widget buildTestWidget({
  required SupplierListBloc supplierListBloc,
  String storeId = 'store-1',
  String? supplierId,
  Supplier? existingSupplier,
}) {
  // A placeholder root route sits below the form route so that the form's
  // context.pop() call on save-success has somewhere to pop back to.
  final router = GoRouter(
    initialLocation: '/suppliers',
    routes: [
      GoRoute(
        path: '/suppliers',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Suppliers')),
          body: Center(
            child: ElevatedButton(
              onPressed: () => context.push('/suppliers/form'),
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/suppliers/form',
        builder: (_, _) => SupplierFormPage(
          storeId: storeId,
          supplierId: supplierId,
          existingSupplier: existingSupplier,
        ),
      ),
    ],
  );
  return BlocProvider<SupplierListBloc>.value(
    value: supplierListBloc,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
    ),
  );
}

/// Pumps the placeholder root route, then pushes the supplier form on top
/// of it so the form has a route to pop back to.
Future<void> openForm(WidgetTester tester) async {
  await tester.pump();
  await tester.tap(find.text('Open form'));
  await tester.pumpAndSettle();
}

void main() {
  late FakeSupplierRepository fakeRepository;
  late SupplierListBloc supplierListBloc;

  setUp(() {
    fakeRepository = FakeSupplierRepository();
    supplierListBloc = SupplierListBloc(supplierRepository: fakeRepository);
  });

  tearDown(() {
    supplierListBloc.close();
  });

  group('SupplierFormPage — add mode', () {
    testWidgets(
      'should display "Новый поставщик" title when supplierId is null',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(supplierListBloc: supplierListBloc));
        await openForm(tester);

        expect(find.text('Новый поставщик'), findsOneWidget);
      },
    );

    testWidgets(
      'should display name, phone and address fields when page loads',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(supplierListBloc: supplierListBloc));
        await openForm(tester);

        expect(find.byIcon(Icons.factory_outlined), findsOneWidget);
        expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
        expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'should show validation error "Введите имя" when name is empty and save is tapped',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(supplierListBloc: supplierListBloc));
        await openForm(tester);

        await tester.tap(find.text('Сохранить'));
        await tester.pump();

        expect(find.text('Введите имя'), findsOneWidget);
      },
    );

    testWidgets(
      'should create a supplier and show a success snackbar when the form is valid',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(supplierListBloc: supplierListBloc));
        await openForm(tester);

        await tester.enterText(
          find.ancestor(
            of: find.byIcon(Icons.factory_outlined),
            matching: find.byType(TextField),
          ),
          'Новый поставщик ОсОО',
        );
        // runAsync forces the fake repository's Future to resolve on the
        // real event loop; a plain pump() sequence left the bloc stuck in
        // SupplierFormLoading indefinitely in this environment.
        await tester.runAsync(() async {
          await tester.tap(find.text('Сохранить'));
          await Future<void>.delayed(Duration.zero);
        });
        // Bounded pump rather than pumpAndSettle: the success snackbar has
        // a multi-second auto-dismiss timer (AppConstants.snackbarDuration),
        // and pumpAndSettle would keep advancing virtual time until that
        // timer fires too, dismissing the very snackbar we're asserting on.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Поставщик добавлен'), findsOneWidget);
      },
    );
  });

  group('SupplierFormPage — edit mode', () {
    final existingSupplier = Supplier(
      id: 'sup-1',
      storeId: 'store-1',
      name: 'ОсОО Ромашка',
      phone: '+992900112233',
      address: 'г. Душанбе, ул. Рудаки 1',
      notes: 'Основной поставщик овощей',
    );

    testWidgets(
      'should display "Редактировать поставщика" title when supplierId is provided',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(
          supplierListBloc: supplierListBloc,
          supplierId: existingSupplier.id,
          existingSupplier: existingSupplier,
        ));
        await openForm(tester);

        expect(find.text('Редактировать поставщика'), findsOneWidget);
      },
    );

    testWidgets(
      'should pre-fill name, phone and address fields with the existing supplier',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(
          supplierListBloc: supplierListBloc,
          supplierId: existingSupplier.id,
          existingSupplier: existingSupplier,
        ));
        await openForm(tester);

        expect(find.text('ОсОО Ромашка'), findsOneWidget);
        expect(find.text('+992900112233'), findsOneWidget);
        expect(find.text('г. Душанбе, ул. Рудаки 1'), findsOneWidget);
      },
    );

    testWidgets(
      'should update the supplier and show a success snackbar when saved',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(
          supplierListBloc: supplierListBloc,
          supplierId: existingSupplier.id,
          existingSupplier: existingSupplier,
        ));
        await openForm(tester);

        // See the add-mode test above: runAsync is required here so the
        // fake repository's Future actually resolves before we pump for it.
        await tester.runAsync(() async {
          await tester.tap(find.text('Сохранить'));
          await Future<void>.delayed(Duration.zero);
        });
        // Bounded pump rather than pumpAndSettle: the success snackbar has
        // a multi-second auto-dismiss timer (AppConstants.snackbarDuration),
        // and pumpAndSettle would keep advancing virtual time until that
        // timer fires too, dismissing the very snackbar we're asserting on.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Поставщик обновлён'), findsOneWidget);
      },
    );
  });
}
