import 'package:equatable/equatable.dart';

abstract class ShiftEvent extends Equatable {
  const ShiftEvent();
  @override
  List<Object?> get props => [];
}

class LoadCurrentShift extends ShiftEvent {
  final String storeId;
  const LoadCurrentShift({required this.storeId});
  @override
  List<Object?> get props => [storeId];
}

class OpenShift extends ShiftEvent {
  final String storeId;
  final double openingCash;
  const OpenShift({required this.storeId, required this.openingCash});
  @override
  List<Object?> get props => [storeId, openingCash];
}

class CloseShift extends ShiftEvent {
  final String storeId;
  final String shiftId;
  final double closingCash;
  const CloseShift({required this.storeId, required this.shiftId, required this.closingCash});
  @override
  List<Object?> get props => [storeId, shiftId, closingCash];
}

class LoadShifts extends ShiftEvent {
  final String storeId;
  final int page;
  final String? staffId;
  final String? dateFrom;
  final String? dateTo;
  const LoadShifts({required this.storeId, this.page = 1, this.staffId, this.dateFrom, this.dateTo});
  @override
  List<Object?> get props => [storeId, page, staffId, dateFrom, dateTo];
}

class LoadZReport extends ShiftEvent {
  final String storeId;
  final String shiftId;
  const LoadZReport({required this.storeId, required this.shiftId});
  @override
  List<Object?> get props => [storeId, shiftId];
}
