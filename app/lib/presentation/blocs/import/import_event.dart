import 'package:equatable/equatable.dart';

abstract class ImportEvent extends Equatable {
  const ImportEvent();

  @override
  List<Object?> get props => [];
}

class ImportFileSelected extends ImportEvent {
  final String storeId;
  final String filePath;

  const ImportFileSelected({required this.storeId, required this.filePath});

  @override
  List<Object?> get props => [storeId, filePath];
}

class ImportConfirmed extends ImportEvent {
  final String storeId;
  final String filePath;

  const ImportConfirmed({required this.storeId, required this.filePath});

  @override
  List<Object?> get props => [storeId, filePath];
}

class ImportTemplateRequested extends ImportEvent {
  final String storeId;

  const ImportTemplateRequested({required this.storeId});

  @override
  List<Object?> get props => [storeId];
}
