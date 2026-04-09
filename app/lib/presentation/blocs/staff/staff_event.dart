import 'package:equatable/equatable.dart';

abstract class StaffEvent extends Equatable {
  const StaffEvent();
  @override
  List<Object?> get props => [];
}

class LoadStaff extends StaffEvent {
  final String storeId;
  final int page;
  final String? search;
  final String? role;
  const LoadStaff({required this.storeId, this.page = 1, this.search, this.role});
  @override
  List<Object?> get props => [storeId, page, search, role];
}

class LoadStaffDetail extends StaffEvent {
  final String storeId;
  final String id;
  const LoadStaffDetail({required this.storeId, required this.id});
  @override
  List<Object?> get props => [storeId, id];
}

class DeleteStaff extends StaffEvent {
  final String storeId;
  final String id;
  const DeleteStaff({required this.storeId, required this.id});
  @override
  List<Object?> get props => [storeId, id];
}
