import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../data/datasources/remote/product_remote_datasource.dart';
import 'import_event.dart';
import 'import_state.dart';

class ImportBloc extends Bloc<ImportEvent, ImportState> {
  final ProductRemoteDatasource _productDatasource;

  ImportBloc({required ProductRemoteDatasource productDatasource})
      : _productDatasource = productDatasource,
        super(const ImportInitial()) {
    on<ImportFileSelected>(_onFileSelected);
    on<ImportConfirmed>(_onConfirmed);
    on<ImportTemplateRequested>(_onTemplateRequested);
  }

  Future<void> _onFileSelected(
    ImportFileSelected event,
    Emitter<ImportState> emit,
  ) async {
    emit(const ImportLoading());
    try {
      final result = await _productDatasource.importPreview(
        event.storeId,
        event.filePath,
      );
      final previewRows = (result['previewRows'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      final errors = (result['errors'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      emit(ImportPreviewLoaded(
        rows: previewRows,
        totalRows: result['totalRows'] as int? ?? 0,
        errors: errors,
        filePath: event.filePath,
      ));
    } catch (e) {
      emit(ImportError(message: mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onConfirmed(
    ImportConfirmed event,
    Emitter<ImportState> emit,
  ) async {
    emit(const ImportLoading());
    try {
      final result = await _productDatasource.importProducts(
        event.storeId,
        event.filePath,
      );
      final errors = (result['errors'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      emit(ImportSuccess(
        created: result['created'] as int? ?? 0,
        skipped: result['skipped'] as int? ?? 0,
        errors: errors,
      ));
    } catch (e) {
      emit(ImportError(message: mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onTemplateRequested(
    ImportTemplateRequested event,
    Emitter<ImportState> emit,
  ) async {
    emit(const ImportLoading());
    try {
      final filePath = await _productDatasource.downloadTemplatePath(
        event.storeId,
      );
      emit(ImportTemplateDownloaded(filePath: filePath));
    } catch (e) {
      emit(ImportError(message: mapErrorToUserMessage(e)));
    }
  }
}
