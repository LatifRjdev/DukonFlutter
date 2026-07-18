import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/data/datasources/remote/product_remote_datasource.dart';
import 'package:dukonpro/presentation/blocs/import/import_bloc.dart';
import 'package:dukonpro/presentation/blocs/import/import_event.dart';
import 'package:dukonpro/presentation/blocs/import/import_state.dart';

class MockProductRemoteDatasource extends Mock
    implements ProductRemoteDatasource {}

void main() {
  late MockProductRemoteDatasource datasource;

  const storeId = 'store-1';
  const filePath = '/tmp/products.xlsx';

  setUp(() {
    datasource = MockProductRemoteDatasource();
  });

  group('ImportBloc', () {
    test('initial state is ImportInitial', () {
      final bloc = ImportBloc(productDatasource: datasource);
      expect(bloc.state, const ImportInitial());
    });

    group('ImportFileSelected', () {
      blocTest<ImportBloc, ImportState>(
        'emits loading then preview loaded on successful parse',
        setUp: () {
          when(() => datasource.importPreview(storeId, filePath))
              .thenAnswer((_) async => {
                    'previewRows': [
                      {'name': 'Bread', 'sellPrice': 10},
                      {'name': 'Milk', 'sellPrice': 15},
                    ],
                    'totalRows': 2,
                    'errors': [],
                  });
        },
        build: () => ImportBloc(productDatasource: datasource),
        act: (bloc) => bloc.add(
          const ImportFileSelected(storeId: storeId, filePath: filePath),
        ),
        expect: () => [
          const ImportLoading(),
          predicate<ImportState>((s) =>
              s is ImportPreviewLoaded &&
              s.rows.length == 2 &&
              s.rows[0]['name'] == 'Bread' &&
              s.totalRows == 2 &&
              s.errors.isEmpty &&
              s.filePath == filePath),
        ],
        verify: (_) {
          verify(() => datasource.importPreview(storeId, filePath)).called(1);
        },
      );

      blocTest<ImportBloc, ImportState>(
        'surfaces per-row errors alongside successfully parsed rows '
        '(partial-row / resilient parsing)',
        setUp: () {
          when(() => datasource.importPreview(storeId, filePath))
              .thenAnswer((_) async => {
                    'previewRows': [
                      {'name': 'Bread', 'sellPrice': 10},
                    ],
                    'totalRows': 3,
                    'errors': [
                      {'row': 2, 'message': 'Missing sellPrice'},
                      {'row': 3, 'message': 'Invalid barcode'},
                    ],
                  });
        },
        build: () => ImportBloc(productDatasource: datasource),
        act: (bloc) => bloc.add(
          const ImportFileSelected(storeId: storeId, filePath: filePath),
        ),
        expect: () => [
          const ImportLoading(),
          predicate<ImportState>((s) =>
              s is ImportPreviewLoaded &&
              s.rows.length == 1 &&
              s.totalRows == 3 &&
              s.errors.length == 2 &&
              s.errors[0]['row'] == 2 &&
              s.errors[1]['message'] == 'Invalid barcode'),
        ],
      );

      blocTest<ImportBloc, ImportState>(
        'defaults rows/totalRows/errors when response omits those keys '
        '(malformed / minimal response body)',
        setUp: () {
          when(() => datasource.importPreview(storeId, filePath))
              .thenAnswer((_) async => <String, dynamic>{});
        },
        build: () => ImportBloc(productDatasource: datasource),
        act: (bloc) => bloc.add(
          const ImportFileSelected(storeId: storeId, filePath: filePath),
        ),
        expect: () => [
          const ImportLoading(),
          predicate<ImportState>((s) =>
              s is ImportPreviewLoaded &&
              s.rows.isEmpty &&
              s.totalRows == 0 &&
              s.errors.isEmpty &&
              s.filePath == filePath),
        ],
      );

      blocTest<ImportBloc, ImportState>(
        'emits loading then user-facing error on NetworkException '
        '(malformed file / offline)',
        setUp: () {
          when(() => datasource.importPreview(storeId, filePath))
              .thenThrow(const NetworkException());
        },
        build: () => ImportBloc(productDatasource: datasource),
        act: (bloc) => bloc.add(
          const ImportFileSelected(storeId: storeId, filePath: filePath),
        ),
        expect: () => [
          const ImportLoading(),
          const ImportError(message: 'Нет подключения к интернету'),
        ],
      );

      blocTest<ImportBloc, ImportState>(
        'maps ServerException 400 (malformed file rejected by backend) to '
        'a friendly validation message',
        setUp: () {
          when(() => datasource.importPreview(storeId, filePath)).thenThrow(
            const ServerException('bad file', statusCode: 400),
          );
        },
        build: () => ImportBloc(productDatasource: datasource),
        act: (bloc) => bloc.add(
          const ImportFileSelected(storeId: storeId, filePath: filePath),
        ),
        expect: () => [
          const ImportLoading(),
          const ImportError(message: 'Некорректные данные'),
        ],
      );

      blocTest<ImportBloc, ImportState>(
        'never leaks raw exception text into ImportError.message '
        '(FE-P1-002 regression)',
        setUp: () {
          when(() => datasource.importPreview(storeId, filePath)).thenThrow(
            Exception(
              'DioException [bad response]: http://10.0.2.2:4455/import',
            ),
          );
        },
        build: () => ImportBloc(productDatasource: datasource),
        act: (bloc) => bloc.add(
          const ImportFileSelected(storeId: storeId, filePath: filePath),
        ),
        expect: () => [
          const ImportLoading(),
          predicate<ImportState>((s) {
            if (s is! ImportError) return false;
            return !s.message.contains('10.0.2.2') &&
                !s.message.contains('DioException') &&
                s.message.isNotEmpty;
          }, 'error set but no leaky internal text'),
        ],
      );
    });

    group('ImportConfirmed', () {
      blocTest<ImportBloc, ImportState>(
        'emits loading then success with created/skipped counts',
        setUp: () {
          when(() => datasource.importProducts(storeId, filePath))
              .thenAnswer((_) async => {
                    'created': 8,
                    'skipped': 2,
                    'errors': [
                      {'row': 5, 'message': 'Duplicate barcode'},
                    ],
                  });
        },
        build: () => ImportBloc(productDatasource: datasource),
        act: (bloc) => bloc.add(
          const ImportConfirmed(storeId: storeId, filePath: filePath),
        ),
        expect: () => [
          const ImportLoading(),
          predicate<ImportState>((s) =>
              s is ImportSuccess &&
              s.created == 8 &&
              s.skipped == 2 &&
              s.errors.length == 1 &&
              s.errors[0]['message'] == 'Duplicate barcode'),
        ],
        verify: (_) {
          verify(() => datasource.importProducts(storeId, filePath))
              .called(1);
        },
      );

      blocTest<ImportBloc, ImportState>(
        'defaults created/skipped/errors when response omits those keys',
        setUp: () {
          when(() => datasource.importProducts(storeId, filePath))
              .thenAnswer((_) async => <String, dynamic>{});
        },
        build: () => ImportBloc(productDatasource: datasource),
        act: (bloc) => bloc.add(
          const ImportConfirmed(storeId: storeId, filePath: filePath),
        ),
        expect: () => [
          const ImportLoading(),
          predicate<ImportState>((s) =>
              s is ImportSuccess &&
              s.created == 0 &&
              s.skipped == 0 &&
              s.errors.isEmpty),
        ],
      );

      blocTest<ImportBloc, ImportState>(
        'emits loading then user-facing error on server failure',
        setUp: () {
          when(() => datasource.importProducts(storeId, filePath)).thenThrow(
            const ServerException('boom', statusCode: 500),
          );
        },
        build: () => ImportBloc(productDatasource: datasource),
        act: (bloc) => bloc.add(
          const ImportConfirmed(storeId: storeId, filePath: filePath),
        ),
        expect: () => [
          const ImportLoading(),
          const ImportError(message: 'Ошибка сервера — попробуйте позже'),
        ],
      );

      blocTest<ImportBloc, ImportState>(
        'emits loading then session-expired message on UnauthorizedException',
        setUp: () {
          when(() => datasource.importProducts(storeId, filePath))
              .thenThrow(const UnauthorizedException());
        },
        build: () => ImportBloc(productDatasource: datasource),
        act: (bloc) => bloc.add(
          const ImportConfirmed(storeId: storeId, filePath: filePath),
        ),
        expect: () => [
          const ImportLoading(),
          const ImportError(message: 'Сессия истекла. Войдите снова.'),
        ],
      );
    });

    group('ImportTemplateRequested', () {
      blocTest<ImportBloc, ImportState>(
        'emits loading then template downloaded with the returned path',
        setUp: () {
          when(() => datasource.downloadTemplatePath(storeId))
              .thenAnswer((_) async => '/tmp/dukon-import-template.xlsx');
        },
        build: () => ImportBloc(productDatasource: datasource),
        act: (bloc) =>
            bloc.add(const ImportTemplateRequested(storeId: storeId)),
        expect: () => [
          const ImportLoading(),
          const ImportTemplateDownloaded(
            filePath: '/tmp/dukon-import-template.xlsx',
          ),
        ],
        verify: (_) {
          verify(() => datasource.downloadTemplatePath(storeId)).called(1);
        },
      );

      blocTest<ImportBloc, ImportState>(
        'emits loading then user-facing error when template download fails',
        setUp: () {
          when(() => datasource.downloadTemplatePath(storeId))
              .thenThrow(const NetworkException());
        },
        build: () => ImportBloc(productDatasource: datasource),
        act: (bloc) =>
            bloc.add(const ImportTemplateRequested(storeId: storeId)),
        expect: () => [
          const ImportLoading(),
          const ImportError(message: 'Нет подключения к интернету'),
        ],
      );
    });
  });
}
