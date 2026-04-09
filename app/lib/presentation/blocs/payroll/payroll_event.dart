import 'package:equatable/equatable.dart';

abstract class PayrollEvent extends Equatable {
  const PayrollEvent();
  @override
  List<Object?> get props => [];
}

class LoadPayrollPeriods extends PayrollEvent {
  final String storeId;
  const LoadPayrollPeriods({required this.storeId});
  @override
  List<Object?> get props => [storeId];
}

class LoadPayrollPeriod extends PayrollEvent {
  final String storeId;
  final String periodId;
  const LoadPayrollPeriod({required this.storeId, required this.periodId});
  @override
  List<Object?> get props => [storeId, periodId];
}

class CalculatePayroll extends PayrollEvent {
  final String storeId;
  final int month;
  final int year;
  const CalculatePayroll({required this.storeId, required this.month, required this.year});
  @override
  List<Object?> get props => [storeId, month, year];
}

class AddAdjustment extends PayrollEvent {
  final String storeId;
  final String periodId;
  final Map<String, dynamic> data;
  const AddAdjustment({required this.storeId, required this.periodId, required this.data});
  @override
  List<Object?> get props => [storeId, periodId, data];
}

class RemoveAdjustment extends PayrollEvent {
  final String storeId;
  final String periodId;
  final String adjustmentId;
  const RemoveAdjustment({required this.storeId, required this.periodId, required this.adjustmentId});
  @override
  List<Object?> get props => [storeId, periodId, adjustmentId];
}

class PayIndividual extends PayrollEvent {
  final String storeId;
  final String periodId;
  final String payrollId;
  const PayIndividual({required this.storeId, required this.periodId, required this.payrollId});
  @override
  List<Object?> get props => [storeId, periodId, payrollId];
}

class PayAll extends PayrollEvent {
  final String storeId;
  final String periodId;
  const PayAll({required this.storeId, required this.periodId});
  @override
  List<Object?> get props => [storeId, periodId];
}
