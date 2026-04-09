import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/supplier.dart';
import 'supplier_detail_event.dart';
import 'supplier_detail_state.dart';

class SupplierDetailBloc extends Bloc<SupplierDetailEvent, SupplierDetailState> {
  final DioClient _dioClient;

  SupplierDetailBloc({required DioClient dioClient})
      : _dioClient = dioClient,
        super(SupplierDetailInitial()) {
    on<SupplierDetailRequested>(_onRequested);
  }

  Future<void> _onRequested(SupplierDetailRequested event, Emitter<SupplierDetailState> emit) async {
    emit(SupplierDetailLoading());
    try {
      final response = await _dioClient.get(
        ApiEndpoints.supplier(event.storeId, event.supplierId),
      );
      final data = response.data as Map<String, dynamic>;
      final supplier = Supplier(
        id: data['id'] as String,
        storeId: data['storeId'] as String,
        name: data['name'] as String,
        phone: data['phone'] as String?,
        email: data['email'] as String?,
        address: data['address'] as String?,
        notes: data['notes'] as String?,
        debt: (data['debt'] as num?)?.toDouble() ?? 0,
      );
      emit(SupplierDetailLoaded(supplier));
    } catch (e) {
      emit(SupplierDetailError(e.toString()));
    }
  }
}
