import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/entities/sale.dart';
import 'package:dukonpro/domain/repositories/sale_repository.dart';
import 'package:dukonpro/presentation/blocs/sales/sales_history_bloc.dart';
import 'package:dukonpro/presentation/blocs/sales/sales_history_event.dart';
import 'package:dukonpro/presentation/blocs/sales/sales_history_state.dart';

class MockSaleRepository extends Mock implements SaleRepository {}

Sale _makeSale({
  String id = 's1',
  String receiptNo = 'R-001',
  double total = 100,
  DateTime? createdAt,
}) {
  return Sale(
    id: id,
    storeId: 'store-1',
    receiptNo: receiptNo,
    subtotal: total,
    total: total,
    paymentType: 'CASH',
    paidAmount: total,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

typedef _SalesPage = ({List<Sale> data, int total, int totalPages, int skippedRows});

_SalesPage _page(List<Sale> sales, {int total = 1, int totalPages = 1, int skippedRows = 0}) {
  return (data: sales, total: total, totalPages: totalPages, skippedRows: skippedRows);
}

void main() {
  late MockSaleRepository repository;

  setUpAll(() {
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  setUp(() {
    repository = MockSaleRepository();
  });

  group('SalesHistoryBloc', () {
    test('initial state is SalesHistoryInitial', () {
      final bloc = SalesHistoryBloc(saleRepository: repository);
      expect(bloc.state, isA<SalesHistoryInitial>());
    });

    group('SalesHistoryLoadRequested', () {
      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'emits Loading then Loaded with sales data on success',
        setUp: () {
          when(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              )).thenAnswer((_) async => _page([_makeSale()], total: 1, totalPages: 1));
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        act: (bloc) => bloc.add(const SalesHistoryLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SalesHistoryLoading>(),
          isA<SalesHistoryLoaded>()
              .having((s) => s.sales.length, 'sales.length', 1)
              .having((s) => s.total, 'total', 1)
              .having((s) => s.currentPage, 'currentPage', 1)
              .having((s) => s.skippedRows, 'skippedRows', 0),
        ],
      );

      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'emits Loading then Error with a mapped user-facing message on '
        'repository failure',
        setUp: () {
          when(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              )).thenThrow(const NetworkException());
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        act: (bloc) => bloc.add(const SalesHistoryLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SalesHistoryLoading>(),
          isA<SalesHistoryError>()
              .having((s) => s.message, 'message', 'Нет подключения к интернету'),
        ],
      );

      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'never leaks a raw exception message into SalesHistoryError',
        setUp: () {
          when(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              )).thenThrow(Exception('DioException [bad response]: http://10.0.2.2/sales'));
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        act: (bloc) => bloc.add(const SalesHistoryLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SalesHistoryLoading>(),
          isA<SalesHistoryError>().having(
            (s) => s.message.contains('DioException') || s.message.contains('10.0.2.2'),
            'no leaky internal text',
            isFalse,
          ),
        ],
      );

      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'surfaces skippedRows from the repository result (BUG #28 parser '
        'resilience) instead of dropping it',
        setUp: () {
          when(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              )).thenAnswer((_) async => _page([_makeSale()], total: 3, skippedRows: 1));
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        act: (bloc) => bloc.add(const SalesHistoryLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SalesHistoryLoading>(),
          isA<SalesHistoryLoaded>().having((s) => s.skippedRows, 'skippedRows', 1),
        ],
      );

      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'reuses the dateFrom/dateTo/paymentType filters already present on '
        'a Loaded state when reloading a different page',
        setUp: () {
          when(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              )).thenAnswer((_) async => _page([_makeSale()]));
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        seed: () => SalesHistoryLoaded(
          sales: const [],
          total: 0,
          totalPages: 5,
          currentPage: 1,
          dateFrom: DateTime(2026, 1, 1),
          dateTo: DateTime(2026, 1, 31),
          paymentType: 'CARD',
        ),
        act: (bloc) => bloc.add(const SalesHistoryLoadRequested(storeId: 'store-1', page: 2)),
        expect: () => [
          isA<SalesHistoryLoading>(),
          isA<SalesHistoryLoaded>()
              .having((s) => s.dateFrom, 'dateFrom', DateTime(2026, 1, 1))
              .having((s) => s.dateTo, 'dateTo', DateTime(2026, 1, 31))
              .having((s) => s.paymentType, 'paymentType', 'CARD')
              .having((s) => s.currentPage, 'currentPage', 2),
        ],
        verify: (_) {
          verify(() => repository.getSales(
                'store-1',
                page: 2,
                dateFrom: DateTime(2026, 1, 1),
                dateTo: DateTime(2026, 1, 31),
                paymentType: 'CARD',
                status: null,
              )).called(1);
        },
      );
    });

    group('SalesHistoryFilterByDate', () {
      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'applies the new date range and reloads, ending in a Loaded state '
        'with those dates',
        setUp: () {
          when(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              )).thenAnswer((_) async => _page([_makeSale()]));
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        act: (bloc) async {
          bloc.add(const SalesHistoryLoadRequested(storeId: 'store-1'));
          await Future<void>.delayed(Duration.zero);
          bloc.add(SalesHistoryFilterByDate(
            dateFrom: DateTime(2026, 2, 1),
            dateTo: DateTime(2026, 2, 28),
          ));
        },
        skip: 2, // initial Loading + Loaded from the seeding load
        expect: () => [
          // synchronous copyWith update, still Loading not yet started
          isA<SalesHistoryLoaded>()
              .having((s) => s.dateFrom, 'dateFrom', DateTime(2026, 2, 1))
              .having((s) => s.dateTo, 'dateTo', DateTime(2026, 2, 28)),
          isA<SalesHistoryLoading>(),
          isA<SalesHistoryLoaded>()
              .having((s) => s.dateFrom, 'dateFrom', DateTime(2026, 2, 1))
              .having((s) => s.dateTo, 'dateTo', DateTime(2026, 2, 28)),
        ],
        verify: (_) {
          // The reload triggered by SalesHistoryFilterByDate must actually
          // query with the selected range, not silently drop it (SPEC.md #9:
          // period chips / custom date-range picker were pure UI state).
          verify(() => repository.getSales(
                'store-1',
                page: any(named: 'page'),
                dateFrom: DateTime(2026, 2, 1),
                dateTo: DateTime(2026, 2, 28),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              )).called(1);
        },
      );

      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'clears the date range when dateFrom/dateTo are both null',
        setUp: () {
          when(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              )).thenAnswer((_) async => _page([_makeSale()]));
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        seed: () => SalesHistoryLoaded(
          sales: const [],
          total: 0,
          totalPages: 1,
          dateFrom: DateTime(2026, 1, 1),
          dateTo: DateTime(2026, 1, 31),
        ),
        act: (bloc) => bloc.add(const SalesHistoryFilterByDate()),
        expect: () => [
          isA<SalesHistoryLoaded>()
              .having((s) => s.dateFrom, 'dateFrom', isNull)
              .having((s) => s.dateTo, 'dateTo', isNull),
          isA<SalesHistoryLoading>(),
          isA<SalesHistoryLoaded>()
              .having((s) => s.dateFrom, 'dateFrom', isNull)
              .having((s) => s.dateTo, 'dateTo', isNull),
        ],
      );
    });

    group('SalesHistoryFilterByPaymentMethod', () {
      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'applies the payment method filter and reloads',
        setUp: () {
          when(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              )).thenAnswer((_) async => _page([_makeSale()]));
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        seed: () => SalesHistoryLoaded(sales: const [], total: 0, totalPages: 1),
        act: (bloc) => bloc.add(const SalesHistoryFilterByPaymentMethod('DEBT')),
        expect: () => [
          isA<SalesHistoryLoaded>().having((s) => s.paymentType, 'paymentType', 'DEBT'),
          isA<SalesHistoryLoading>(),
          isA<SalesHistoryLoaded>().having((s) => s.paymentType, 'paymentType', 'DEBT'),
        ],
        verify: (_) {
          verify(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: 'DEBT',
                status: any(named: 'status'),
              )).called(1);
        },
      );

      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'clears the payment method filter when null is passed',
        setUp: () {
          when(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              )).thenAnswer((_) async => _page([_makeSale()]));
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        seed: () => SalesHistoryLoaded(sales: const [], total: 0, totalPages: 1, paymentType: 'CARD'),
        act: (bloc) => bloc.add(const SalesHistoryFilterByPaymentMethod(null)),
        expect: () => [
          isA<SalesHistoryLoaded>().having((s) => s.paymentType, 'paymentType', isNull),
          isA<SalesHistoryLoading>(),
          isA<SalesHistoryLoaded>().having((s) => s.paymentType, 'paymentType', isNull),
        ],
      );
    });

    group('SalesHistoryFilterByStatus', () {
      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'applies the status filter and reloads, ending in a Loaded state '
        'carrying that status, and actually queries with it (SPEC.md #10: '
        'the SalesFilterSheet status filter used to be collected but never '
        'threaded into the query)',
        setUp: () {
          when(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              )).thenAnswer((_) async => _page([_makeSale()]));
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        seed: () => SalesHistoryLoaded(sales: const [], total: 0, totalPages: 1),
        act: (bloc) => bloc.add(const SalesHistoryFilterByStatus('RETURNED')),
        expect: () => [
          isA<SalesHistoryLoaded>().having((s) => s.status, 'status', 'RETURNED'),
          isA<SalesHistoryLoading>(),
          isA<SalesHistoryLoaded>().having((s) => s.status, 'status', 'RETURNED'),
        ],
        verify: (_) {
          verify(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: 'RETURNED',
              )).called(1);
        },
      );

      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'clears the status filter when null is passed',
        setUp: () {
          when(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              )).thenAnswer((_) async => _page([_makeSale()]));
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        seed: () => SalesHistoryLoaded(sales: const [], total: 0, totalPages: 1, status: 'COMPLETED'),
        act: (bloc) => bloc.add(const SalesHistoryFilterByStatus(null)),
        expect: () => [
          isA<SalesHistoryLoaded>().having((s) => s.status, 'status', isNull),
          isA<SalesHistoryLoading>(),
          isA<SalesHistoryLoaded>().having((s) => s.status, 'status', isNull),
        ],
      );
    });

    group('SalesHistoryLoadMore', () {
      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'appends the next page of results and increments currentPage when '
        'hasMore is true',
        setUp: () {
          when(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              )).thenAnswer((_) async => _page([_makeSale(id: 's2', receiptNo: 'R-002')]));
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        seed: () => SalesHistoryLoaded(
          sales: [_makeSale(id: 's1', receiptNo: 'R-001')],
          total: 2,
          totalPages: 2,
          currentPage: 1,
          dateFrom: DateTime(2026, 1, 1),
          dateTo: DateTime(2026, 1, 31),
          paymentType: 'CARD',
          status: 'RETURNED',
        ),
        act: (bloc) => bloc.add(SalesHistoryLoadMore()),
        expect: () => [
          isA<SalesHistoryLoaded>().having((s) => s.isLoadingMore, 'isLoadingMore', true),
          isA<SalesHistoryLoaded>()
              .having((s) => s.sales.length, 'sales.length', 2)
              .having((s) => s.sales.map((e) => e.receiptNo), 'order', ['R-001', 'R-002'])
              .having((s) => s.currentPage, 'currentPage', 2)
              .having((s) => s.isLoadingMore, 'isLoadingMore reset', false)
              .having((s) => s.status, 'status carried into next page', 'RETURNED'),
        ],
        verify: (_) {
          // A pull-to-refresh-style "load more" must keep applying the
          // active filters, not silently drop them on page 2+ (same bug
          // class as SPEC.md #9/#10, different entry point).
          verify(() => repository.getSales(
                any(),
                page: 2,
                dateFrom: DateTime(2026, 1, 1),
                dateTo: DateTime(2026, 1, 31),
                paymentType: 'CARD',
                status: 'RETURNED',
              )).called(1);
        },
      );

      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'does nothing when hasMore is false (currentPage >= totalPages)',
        build: () => SalesHistoryBloc(saleRepository: repository),
        seed: () => SalesHistoryLoaded(
          sales: [_makeSale()],
          total: 1,
          totalPages: 1,
          currentPage: 1,
        ),
        act: (bloc) => bloc.add(SalesHistoryLoadMore()),
        expect: () => [],
        verify: (_) {
          verifyNever(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              ));
        },
      );

      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'does nothing when a load-more is already in flight (isLoadingMore '
        'guard prevents duplicate requests)',
        build: () => SalesHistoryBloc(saleRepository: repository),
        seed: () => SalesHistoryLoaded(
          sales: [_makeSale()],
          total: 2,
          totalPages: 2,
          currentPage: 1,
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(SalesHistoryLoadMore()),
        expect: () => [],
        verify: (_) {
          verifyNever(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              ));
        },
      );

      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'resets isLoadingMore to false and silently swallows the error when '
        'the next page fails to load (existing sales are preserved, no '
        'error state)',
        setUp: () {
          when(() => repository.getSales(
                any(),
                page: any(named: 'page'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                paymentType: any(named: 'paymentType'),
                status: any(named: 'status'),
              )).thenThrow(const ServerException('boom', statusCode: 500));
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        seed: () => SalesHistoryLoaded(
          sales: [_makeSale()],
          total: 2,
          totalPages: 2,
          currentPage: 1,
        ),
        act: (bloc) => bloc.add(SalesHistoryLoadMore()),
        expect: () => [
          isA<SalesHistoryLoaded>().having((s) => s.isLoadingMore, 'isLoadingMore', true),
          isA<SalesHistoryLoaded>()
              .having((s) => s.isLoadingMore, 'isLoadingMore reset', false)
              .having((s) => s.sales.length, 'sales preserved', 1)
              .having((s) => s.currentPage, 'currentPage unchanged', 1),
        ],
      );
    });

    group('SalesHistoryRefundSale', () {
      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'replaces the refunded sale in-place and clears isRefunding on '
        'success',
        setUp: () {
          when(() => repository.refundSale(any(), any(), any())).thenAnswer(
            (_) async => _makeSale(id: 's1', receiptNo: 'R-001', total: 0),
          );
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        seed: () => SalesHistoryLoaded(
          sales: [
            _makeSale(id: 's1', receiptNo: 'R-001', total: 100),
            _makeSale(id: 's2', receiptNo: 'R-002', total: 50),
          ],
          total: 2,
          totalPages: 1,
        ),
        act: (bloc) => bloc.add(const SalesHistoryRefundSale(
          storeId: 'store-1',
          saleId: 's1',
          refundData: {'reason': 'damaged'},
        )),
        expect: () => [
          isA<SalesHistoryLoaded>().having((s) => s.isRefunding, 'isRefunding', true),
          isA<SalesHistoryLoaded>()
              .having((s) => s.isRefunding, 'isRefunding reset', false)
              .having(
                (s) => s.sales.firstWhere((e) => e.id == 's1').total,
                'refunded sale total updated',
                0,
              )
              .having((s) => s.sales.length, 'sales.length unchanged', 2),
        ],
        verify: (_) {
          verify(() => repository.refundSale('store-1', 's1', {'reason': 'damaged'})).called(1);
        },
      );

      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'resets isRefunding to false, leaves the sales list untouched, and '
        'surfaces a mapped user-facing refundError when the refund call '
        'fails (SPEC.md #12: this used to be swallowed silently)',
        setUp: () {
          when(() => repository.refundSale(any(), any(), any()))
              .thenThrow(const NetworkException());
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        seed: () => SalesHistoryLoaded(
          sales: [_makeSale(id: 's1', receiptNo: 'R-001', total: 100)],
          total: 1,
          totalPages: 1,
        ),
        act: (bloc) => bloc.add(const SalesHistoryRefundSale(
          storeId: 'store-1',
          saleId: 's1',
          refundData: {},
        )),
        expect: () => [
          isA<SalesHistoryLoaded>()
              .having((s) => s.isRefunding, 'isRefunding', true)
              .having((s) => s.refundError, 'refundError cleared on start', isNull),
          isA<SalesHistoryLoaded>()
              .having((s) => s.isRefunding, 'isRefunding reset', false)
              .having((s) => s.sales.first.total, 'total unchanged', 100)
              .having(
                (s) => s.refundError,
                'refundError',
                'Нет подключения к интернету',
              ),
        ],
      );

      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'never leaks a raw exception message into refundError',
        setUp: () {
          when(() => repository.refundSale(any(), any(), any())).thenThrow(
            Exception('DioException [bad response]: http://10.0.2.2/refund'),
          );
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        seed: () => SalesHistoryLoaded(
          sales: [_makeSale(id: 's1', receiptNo: 'R-001', total: 100)],
          total: 1,
          totalPages: 1,
        ),
        act: (bloc) => bloc.add(const SalesHistoryRefundSale(
          storeId: 'store-1',
          saleId: 's1',
          refundData: {},
        )),
        expect: () => [
          isA<SalesHistoryLoaded>().having((s) => s.isRefunding, 'isRefunding', true),
          isA<SalesHistoryLoaded>().having(
            (s) =>
                s.refundError!.contains('DioException') ||
                s.refundError!.contains('10.0.2.2'),
            'no leaky internal text',
            isFalse,
          ),
        ],
      );

      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'clears a stale refundError from a prior failed attempt once a '
        'retry succeeds',
        setUp: () {
          when(() => repository.refundSale(any(), any(), any())).thenAnswer(
            (_) async => _makeSale(id: 's1', receiptNo: 'R-001', total: 0),
          );
        },
        build: () => SalesHistoryBloc(saleRepository: repository),
        seed: () => SalesHistoryLoaded(
          sales: [_makeSale(id: 's1', receiptNo: 'R-001', total: 100)],
          total: 1,
          totalPages: 1,
          refundError: 'Нет подключения к интернету',
        ),
        act: (bloc) => bloc.add(const SalesHistoryRefundSale(
          storeId: 'store-1',
          saleId: 's1',
          refundData: {'reason': 'damaged'},
        )),
        expect: () => [
          isA<SalesHistoryLoaded>()
              .having((s) => s.isRefunding, 'isRefunding', true)
              .having((s) => s.refundError, 'refundError cleared on start', isNull),
          isA<SalesHistoryLoaded>()
              .having((s) => s.isRefunding, 'isRefunding reset', false)
              .having((s) => s.refundError, 'refundError cleared on success', isNull),
        ],
      );

      blocTest<SalesHistoryBloc, SalesHistoryState>(
        'does nothing when the current state is not Loaded',
        build: () => SalesHistoryBloc(saleRepository: repository),
        act: (bloc) => bloc.add(const SalesHistoryRefundSale(
          storeId: 'store-1',
          saleId: 's1',
          refundData: {},
        )),
        expect: () => [],
        verify: (_) {
          verifyNever(() => repository.refundSale(any(), any(), any()));
        },
      );
    });
  });
}
