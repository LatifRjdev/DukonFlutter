import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/customer.dart';
import 'customer_detail_event.dart';
import 'customer_detail_state.dart';

class CustomerDetailBloc extends Bloc<CustomerDetailEvent, CustomerDetailState> {
  final DioClient _dioClient;

  CustomerDetailBloc({required DioClient dioClient})
      : _dioClient = dioClient,
        super(CustomerDetailInitial()) {
    on<CustomerDetailRequested>(_onRequested);
  }

  Future<void> _onRequested(CustomerDetailRequested event, Emitter<CustomerDetailState> emit) async {
    emit(CustomerDetailLoading());
    try {
      final response = await _dioClient.get(
        ApiEndpoints.customer(event.storeId, event.customerId),
      );
      final data = response.data as Map<String, dynamic>;
      final salesList = (data['sales'] as List?)?.map((s) => s as Map<String, dynamic>).toList() ?? [];

      final customer = Customer(
        id: data['id'] as String,
        storeId: data['storeId'] as String,
        name: data['name'] as String,
        phone: data['phone'] as String?,
        email: data['email'] as String?,
        notes: data['notes'] as String?,
        loyaltyPoints: (data['loyaltyPoints'] as num?)?.toInt() ?? 0,
        totalSpent: (data['totalSpent'] as num?)?.toDouble() ?? 0,
        debt: (data['debt'] as num?)?.toDouble() ?? 0,
      );

      emit(CustomerDetailLoaded(customer: customer, recentSales: salesList));
    } catch (e) {
      emit(CustomerDetailError(e.toString()));
    }
  }
}
