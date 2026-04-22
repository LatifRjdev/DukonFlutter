import 'package:equatable/equatable.dart';

abstract class ImportState extends Equatable {
  const ImportState();

  @override
  List<Object?> get props => [];
}

class ImportInitial extends ImportState {
  const ImportInitial();
}

class ImportLoading extends ImportState {
  const ImportLoading();
}

class ImportPreviewLoaded extends ImportState {
  final List<Map<String, dynamic>> rows;
  final int totalRows;
  final List<Map<String, dynamic>> errors;
  final String filePath;

  const ImportPreviewLoaded({
    required this.rows,
    required this.totalRows,
    required this.errors,
    required this.filePath,
  });

  @override
  List<Object?> get props => [rows, totalRows, errors, filePath];
}

class ImportSuccess extends ImportState {
  final int created;
  final int skipped;
  final List<Map<String, dynamic>> errors;

  const ImportSuccess({
    required this.created,
    required this.skipped,
    required this.errors,
  });

  @override
  List<Object?> get props => [created, skipped, errors];
}

class ImportTemplateDownloaded extends ImportState {
  final String filePath;

  const ImportTemplateDownloaded({required this.filePath});

  @override
  List<Object?> get props => [filePath];
}

class ImportError extends ImportState {
  final String message;

  const ImportError({required this.message});

  @override
  List<Object?> get props => [message];
}
