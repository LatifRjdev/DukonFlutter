import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dukonpro/domain/entities/customer.dart';
import 'package:dukonpro/domain/repositories/customer_repository.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/customer_detail/customer_detail_bloc.dart';
import 'package:dukonpro/presentation/blocs/customer_detail/customer_detail_event.dart';
import 'package:dukonpro/presentation/blocs/customer_detail/customer_detail_state.dart';
import 'package:dukonpro/presentation/pages/customer/customer_form_page.dart';

// --- Fakes ---

class FakeCustomerRepository extends Fake implements CustomerRepository {
  @override
  Future<Customer> createCustomer(String storeId, Map<String, dynamic> data) async {
    return Customer(
      id: 'new-id',
      storeId: storeId,
      name: data['name'] as String,
      phone: data['phone'] as String?,
      notes: data['notes'] as String?,
    );
  }

  @override
  Future<Customer> updateCustomer(
    String storeId,
    String id,
    Map<String, dynamic> data,
  ) async {
    return Customer(
      id: id,
      storeId: storeId,
      name: data['name'] as String,
      phone: data['phone'] as String?,
      notes: data['notes'] as String?,
    );
  }

  @override
  Future<({List<Customer> data, int total, int totalPages})> getCustomers(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    return (data: <Customer>[], total: 0, totalPages: 0);
  }

  @override
  Future<Customer> getCustomer(String storeId, String id) async {
    return Customer(id: id, storeId: storeId, name: 'Test');
  }

  @override
  Future<void> deleteCustomer(String storeId, String id) async {}
}

class MockCustomerDetailBloc
    extends MockBloc<CustomerDetailEvent, CustomerDetailState>
    implements CustomerDetailBloc {}

// --- Helpers ---

Widget buildTestWidget({
  required CustomerListBloc customerListBloc,
  required CustomerDetailBloc customerDetailBloc,
  String storeId = 'store-1',
  String? customerId,
  Customer? existingCustomer,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<CustomerListBloc>.value(value: customerListBloc),
      BlocProvider<CustomerDetailBloc>.value(value: customerDetailBloc),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CustomerFormPage(
        storeId: storeId,
        customerId: customerId,
        existingCustomer: existingCustomer,
      ),
    ),
  );
}

void main() {
  late FakeCustomerRepository fakeRepository;
  late CustomerListBloc customerListBloc;
  late MockCustomerDetailBloc customerDetailBloc;

  setUp(() {
    fakeRepository = FakeCustomerRepository();
    customerListBloc = CustomerListBloc(customerRepository: fakeRepository);
    customerDetailBloc = MockCustomerDetailBloc();
    when(() => customerDetailBloc.state).thenReturn(CustomerDetailInitial());
    when(() => customerDetailBloc.stream)
        .thenAnswer((_) => const Stream.empty());
  });

  tearDown(() {
    customerListBloc.close();
    customerDetailBloc.close();
  });

  group('CustomerFormPage — add mode', () {
    testWidgets(
      'should display "Новый клиент" title when customerId is null',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(
          customerListBloc: customerListBloc,
          customerDetailBloc: customerDetailBloc,
        ));
        await tester.pump();

        expect(find.text('Новый клиент'), findsOneWidget);
      },
    );

    testWidgets(
      'should display name and phone fields when page loads',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(
          customerListBloc: customerListBloc,
          customerDetailBloc: customerDetailBloc,
        ));
        await tester.pump();

        expect(find.byIcon(Icons.person_outline), findsOneWidget);
        expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'should show validation error "Введите имя" when name is empty and save is tapped',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(
          customerListBloc: customerListBloc,
          customerDetailBloc: customerDetailBloc,
        ));
        await tester.pump();

        await tester.tap(find.text('Сохранить'));
        await tester.pump();

        expect(find.text('Введите имя'), findsOneWidget);
      },
    );
  });

  group('CustomerFormPage — edit mode', () {
    final existingCustomer = Customer(
      id: 'cust-1',
      storeId: 'store-1',
      name: 'Алишер Иванов',
      phone: '+992900112233',
      notes: 'VIP клиент',
    );

    testWidgets(
      'should display "Редактировать клиента" title when customerId is provided',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(
          customerListBloc: customerListBloc,
          customerDetailBloc: customerDetailBloc,
          customerId: existingCustomer.id,
          existingCustomer: existingCustomer,
        ));
        await tester.pump();

        expect(find.text('Редактировать клиента'), findsOneWidget);
      },
    );

    testWidgets(
      'should pre-fill name field with existing customer name',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(
          customerListBloc: customerListBloc,
          customerDetailBloc: customerDetailBloc,
          customerId: existingCustomer.id,
          existingCustomer: existingCustomer,
        ));
        await tester.pump();

        expect(find.text('Алишер Иванов'), findsOneWidget);
      },
    );
  });
}
