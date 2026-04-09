import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'debt_event.dart';
import 'debt_state.dart';

class DebtBloc extends Bloc<DebtEvent, DebtState> {
  final DioClient _dioClient;

  DebtBloc({required DioClient dioClient})
      : _dioClient = dioClient,
        super(DebtInitial()) {
    on<CustomerDebtsRequested>(_onCustomerDebts);
    on<SupplierDebtsRequested>(_onSupplierDebts);
    on<DebtPaymentSubmitted>(_onDebtPayment);
    on<SupplierPaymentSubmitted>(_onSupplierPayment);
    on<DebtsOverviewRequested>(_onOverviewRequested);
  }

  Future<void> _onCustomerDebts(CustomerDebtsRequested event, Emitter<DebtState> emit) async {
    emit(DebtLoading());
    try {
      final response = await _dioClient.get(ApiEndpoints.customerDebts(event.storeId, event.customerId));
      final data = response.data as Map<String, dynamic>;
      final sales = (data['sales'] as List).map((s) => s as Map<String, dynamic>).toList();
      final totalDebt = (data['totalDebt'] as num).toDouble();
      emit(CustomerDebtsLoaded(sales: sales, totalDebt: totalDebt));
    } catch (e) {
      emit(DebtError(e.toString()));
    }
  }

  Future<void> _onSupplierDebts(SupplierDebtsRequested event, Emitter<DebtState> emit) async {
    emit(DebtLoading());
    try {
      final response = await _dioClient.get(ApiEndpoints.supplierDebts(event.storeId, event.supplierId));
      final data = response.data as Map<String, dynamic>;
      final debt = (data['debt'] as num).toDouble();
      final payments = (data['payments'] as List?)?.map((p) => p as Map<String, dynamic>).toList() ?? [];
      emit(SupplierDebtsLoaded(debt: debt, payments: payments));
    } catch (e) {
      emit(DebtError(e.toString()));
    }
  }

  Future<void> _onDebtPayment(DebtPaymentSubmitted event, Emitter<DebtState> emit) async {
    emit(DebtLoading());
    try {
      await _dioClient.post(
        ApiEndpoints.customerPayments(event.storeId, event.customerId),
        data: {
          'saleId': event.saleId,
          'amount': event.amount,
          'method': event.method,
          if (event.notes != null) 'notes': event.notes,
        },
      );
      emit(const DebtPaymentSuccess('Оплата принята'));
      add(CustomerDebtsRequested(storeId: event.storeId, customerId: event.customerId));
    } catch (e) {
      emit(DebtError(e.toString()));
    }
  }

  Future<void> _onOverviewRequested(DebtsOverviewRequested event, Emitter<DebtState> emit) async {
    emit(DebtLoading());
    try {
      final responses = await Future.wait([
        _dioClient.get(ApiEndpoints.customers(event.storeId)),
        _dioClient.get(ApiEndpoints.suppliers(event.storeId)),
      ]);
      final customersData = responses[0].data;
      final suppliersData = responses[1].data;
      final customersList = (customersData is Map ? customersData['data'] as List? : customersData as List?) ?? [];
      final suppliersList = (suppliersData is Map ? suppliersData['data'] as List? : suppliersData as List?) ?? [];

      final customers = customersList
          .map((c) => c as Map<String, dynamic>)
          .where((c) => (c['debt'] as num? ?? 0) > 0)
          .toList();
      final suppliers = suppliersList
          .map((s) => s as Map<String, dynamic>)
          .where((s) => (s['debt'] as num? ?? 0) > 0)
          .toList();

      final totalCustomerDebt = customers.fold<double>(0, (sum, c) => sum + (c['debt'] as num? ?? 0).toDouble());
      final totalSupplierDebt = suppliers.fold<double>(0, (sum, s) => sum + (s['debt'] as num? ?? 0).toDouble());

      emit(DebtsOverviewLoaded(
        customers: customers,
        suppliers: suppliers,
        totalCustomerDebt: totalCustomerDebt,
        totalSupplierDebt: totalSupplierDebt,
      ));
    } catch (e) {
      emit(DebtError(e.toString()));
    }
  }

  Future<void> _onSupplierPayment(SupplierPaymentSubmitted event, Emitter<DebtState> emit) async {
    emit(DebtLoading());
    try {
      await _dioClient.post(
        ApiEndpoints.supplierPayments(event.storeId, event.supplierId),
        data: {
          'amount': event.amount,
          'method': event.method,
          if (event.notes != null) 'notes': event.notes,
        },
      );
      emit(const DebtPaymentSuccess('Оплата записана'));
      add(SupplierDebtsRequested(storeId: event.storeId, supplierId: event.supplierId));
    } catch (e) {
      emit(DebtError(e.toString()));
    }
  }
}
