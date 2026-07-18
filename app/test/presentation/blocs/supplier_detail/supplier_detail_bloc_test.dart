import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/constants/api_endpoints.dart';
import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/domain/entities/supplier.dart';
import 'package:dukonpro/presentation/blocs/supplier_detail/supplier_detail_bloc.dart';
import 'package:dukonpro/presentation/blocs/supplier_detail/supplier_detail_event.dart';
import 'package:dukonpro/presentation/blocs/supplier_detail/supplier_detail_state.dart';

class MockDioClient extends Mock implements DioClient {}

Response<dynamic> _response(dynamic data) =>
    Response(data: data, requestOptions: RequestOptions(path: '/x'));

void main() {
  late MockDioClient dioClient;

  setUp(() {
    dioClient = MockDioClient();
  });

  group('SupplierDetailBloc', () {
    test('initial state is SupplierDetailInitial', () {
      final bloc = SupplierDetailBloc(dioClient: dioClient);
      expect(bloc.state, isA<SupplierDetailInitial>());
    });

    group('SupplierDetailRequested', () {
      blocTest<SupplierDetailBloc, SupplierDetailState>(
        'emits [Loading, Loaded] with parsed supplier on success',
        setUp: () {
          when(() => dioClient.get(ApiEndpoints.supplier('store-1', 's1')))
              .thenAnswer((_) async => _response({
                    'id': 's1',
                    'storeId': 'store-1',
                    'name': 'ACME',
                    'phone': '+992900000000',
                    'email': 'acme@example.com',
                    'address': 'Dushanbe',
                    'notes': 'notes',
                    'debt': 75.5,
                  }));
        },
        build: () => SupplierDetailBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SupplierDetailRequested(
          storeId: 'store-1',
          supplierId: 's1',
        )),
        expect: () => [
          isA<SupplierDetailLoading>(),
          isA<SupplierDetailLoaded>().having(
            (s) => s.supplier,
            'supplier',
            predicate<Supplier>((supplier) =>
                supplier.id == 's1' &&
                supplier.storeId == 'store-1' &&
                supplier.name == 'ACME' &&
                supplier.phone == '+992900000000' &&
                supplier.email == 'acme@example.com' &&
                supplier.address == 'Dushanbe' &&
                supplier.notes == 'notes' &&
                supplier.debt == 75.5),
          ),
        ],
      );

      blocTest<SupplierDetailBloc, SupplierDetailState>(
        'defaults optional fields to null and debt to 0 when absent from JSON',
        setUp: () {
          when(() => dioClient.get(ApiEndpoints.supplier('store-1', 's1')))
              .thenAnswer((_) async => _response({
                    'id': 's1',
                    'storeId': 'store-1',
                    'name': 'ACME',
                  }));
        },
        build: () => SupplierDetailBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SupplierDetailRequested(
          storeId: 'store-1',
          supplierId: 's1',
        )),
        expect: () => [
          isA<SupplierDetailLoading>(),
          isA<SupplierDetailLoaded>().having(
            (s) => s.supplier,
            'supplier',
            predicate<Supplier>((supplier) =>
                supplier.phone == null &&
                supplier.email == null &&
                supplier.address == null &&
                supplier.notes == null &&
                supplier.debt == 0),
          ),
        ],
      );

      blocTest<SupplierDetailBloc, SupplierDetailState>(
        'emits [Loading, Error] with mapped message on NetworkException',
        setUp: () {
          when(() => dioClient.get(any())).thenThrow(const NetworkException());
        },
        build: () => SupplierDetailBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SupplierDetailRequested(
          storeId: 'store-1',
          supplierId: 's1',
        )),
        expect: () => [
          isA<SupplierDetailLoading>(),
          isA<SupplierDetailError>()
              .having((s) => s.message, 'message', 'Нет подключения к интернету'),
        ],
      );

      blocTest<SupplierDetailBloc, SupplierDetailState>(
        'emits [Loading, Error] when response body cannot be cast (malformed JSON)',
        setUp: () {
          when(() => dioClient.get(any())).thenAnswer((_) async => _response('not-a-map'));
        },
        build: () => SupplierDetailBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SupplierDetailRequested(
          storeId: 'store-1',
          supplierId: 's1',
        )),
        expect: () => [
          isA<SupplierDetailLoading>(),
          isA<SupplierDetailError>(),
        ],
      );

      blocTest<SupplierDetailBloc, SupplierDetailState>(
        'never leaks raw exception text into the error state',
        setUp: () {
          when(() => dioClient.get(any()))
              .thenThrow(Exception('DioException [bad response]: http://10.0.2.2:4455/x'));
        },
        build: () => SupplierDetailBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SupplierDetailRequested(
          storeId: 'store-1',
          supplierId: 's1',
        )),
        expect: () => [
          isA<SupplierDetailLoading>(),
          predicate<SupplierDetailState>((s) {
            if (s is! SupplierDetailError) return false;
            return !s.message.contains('10.0.2.2') &&
                !s.message.contains('DioException') &&
                s.message.isNotEmpty;
          }, 'error set but no leaky internal text'),
        ],
      );
    });
  });
}
