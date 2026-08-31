// app/test/presentation/pages/customer/customer_list_filter_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/domain/entities/customer.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_bloc.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_event.dart';
import 'package:dukonpro/presentation/blocs/customer/customer_list_state.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/pages/customer/customer_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class MockCustomerListBloc
    extends MockBloc<CustomerListEvent, CustomerListState>
    implements CustomerListBloc {}

void main() {
  late MockStoreBloc storeBloc;
  late MockCustomerListBloc customerListBloc;

  final now = DateTime.now();

  // Alice: no debt, not VIP, created 5 days ago -> matches only "Новые".
  final alice = Customer(
    id: 'c1',
    storeId: 'test-store-id',
    name: 'Alice',
    debt: 0,
    loyaltyPoints: 0,
    totalSpent: 0,
    createdAt: now.subtract(const Duration(days: 5)),
  );
  // Bob: has debt, not VIP, created long ago -> matches only "С долгом".
  final bob = Customer(
    id: 'c2',
    storeId: 'test-store-id',
    name: 'Bob',
    debt: 500,
    loyaltyPoints: 0,
    totalSpent: 0,
    createdAt: now.subtract(const Duration(days: 200)),
  );
  // Carol: no debt, VIP via loyaltyPoints, created long ago -> matches only "VIP".
  final carol = Customer(
    id: 'c3',
    storeId: 'test-store-id',
    name: 'Carol',
    debt: 0,
    loyaltyPoints: 2000,
    totalSpent: 0,
    createdAt: now.subtract(const Duration(days: 200)),
  );
  // Dave: no debt, not VIP, created long ago -> matches none of the specific filters.
  final dave = Customer(
    id: 'c4',
    storeId: 'test-store-id',
    name: 'Dave',
    debt: 0,
    loyaltyPoints: 0,
    totalSpent: 0,
    createdAt: now.subtract(const Duration(days: 200)),
  );

  setUp(() {
    storeBloc = MockStoreBloc();
    customerListBloc = MockCustomerListBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    when(() => customerListBloc.state).thenReturn(
      CustomerListLoaded(
        customers: [alice, bob, carol, dave],
        total: 4,
        totalPages: 1,
        currentPage: 1,
      ),
    );
  });

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<CustomerListBloc>.value(value: customerListBloc),
        ],
        child: child,
      );

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpPageWithTheme(
      tester,
      const CustomerListPage(),
      brightness: Brightness.light,
      wrap: wrapWithBlocs,
    );
  }

  group('CustomerListPage filter chips', () {
    testWidgets('should show every customer when "Все" is selected', (tester) async {
      await pumpPage(tester);

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Carol'), findsOneWidget);
      expect(find.text('Dave'), findsOneWidget);
    });

    testWidgets('should only show customers with a debt when "С долгом" is tapped', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('С долгом'));
      await tester.pumpAndSettle();

      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
      expect(find.text('Carol'), findsNothing);
      expect(find.text('Dave'), findsNothing);
    });

    testWidgets('should only show VIP customers when "VIP" is tapped', (tester) async {
      await pumpPage(tester);

      // "VIP" also appears on Carol's badge once she's shown, so target the
      // filter chip specifically, which is mounted first in the tree.
      await tester.tap(find.text('VIP').first);
      await tester.pumpAndSettle();

      expect(find.text('Carol'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
      expect(find.text('Bob'), findsNothing);
      expect(find.text('Dave'), findsNothing);
    });

    testWidgets('should only show recently-created customers when "Новые" is tapped', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Новые'));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsNothing);
      expect(find.text('Carol'), findsNothing);
      expect(find.text('Dave'), findsNothing);
    });

    testWidgets('should show every customer again after returning to "Все"', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('VIP').first);
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsNothing);

      await tester.tap(find.text('Все'));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Carol'), findsOneWidget);
      expect(find.text('Dave'), findsOneWidget);
    });
  });
}
