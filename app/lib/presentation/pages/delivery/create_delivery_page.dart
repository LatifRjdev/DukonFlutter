import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../injection.dart';
import '../../widgets/common/app_snackbar.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class _Sale {
  final String id;
  final String label;
  const _Sale({required this.id, required this.label});
  factory _Sale.fromJson(Map<String, dynamic> j) => _Sale(
        id: j['id'] as String,
        label: j['orderNumber'] as String? ?? '#${j['id']}',
      );
}

class _StaffMember {
  final String id;
  final String name;
  const _StaffMember({required this.id, required this.name});
  factory _StaffMember.fromJson(Map<String, dynamic> j) => _StaffMember(
        id: j['id'] as String,
        name: '${j['firstName'] ?? ''} ${j['lastName'] ?? ''}'.trim(),
      );
}

// ─── Cubit ───────────────────────────────────────────────────────────────────

abstract class _CreateState {}

class _CreateInitial extends _CreateState {}

class _CreateRefsLoading extends _CreateState {}

class _CreateRefsLoaded extends _CreateState {
  final List<_Sale> sales;
  final List<_StaffMember> staff;
  _CreateRefsLoaded({required this.sales, required this.staff});
}

class _CreateSubmitting extends _CreateState {
  final List<_Sale> sales;
  final List<_StaffMember> staff;
  _CreateSubmitting({required this.sales, required this.staff});
}

class _CreateSuccess extends _CreateState {}

class _CreateError extends _CreateState {
  final String message;
  final List<_Sale> sales;
  final List<_StaffMember> staff;
  _CreateError({required this.message, required this.sales, required this.staff});
}

class _CreateCubit extends Cubit<_CreateState> {
  final DioClient _client;
  final String storeId;

  _CreateCubit(this._client, this.storeId) : super(_CreateInitial());

  List<_Sale> _sales = [];
  List<_StaffMember> _staff = [];

  Future<void> loadRefs() async {
    emit(_CreateRefsLoading());
    try {
      final salesResp = await _client.get('/stores/$storeId/sales', queryParameters: {'limit': 50});
      final staffResp = await _client.get('/stores/$storeId/staff');

      List<dynamic> salesList;
      final raw = salesResp.data;
      if (raw is List) {
        salesList = raw;
      } else if (raw is Map && raw['data'] is List) {
        salesList = raw['data'] as List;
      } else {
        salesList = [];
      }

      List<dynamic> staffList;
      final rawS = staffResp.data;
      if (rawS is List) {
        staffList = rawS;
      } else if (rawS is Map && rawS['data'] is List) {
        staffList = rawS['data'] as List;
      } else {
        staffList = [];
      }

      _sales = salesList.map((e) => _Sale.fromJson(e as Map<String, dynamic>)).toList();
      _staff = staffList.map((e) => _StaffMember.fromJson(e as Map<String, dynamic>)).toList();
      emit(_CreateRefsLoaded(sales: _sales, staff: _staff));
    } catch (e) {
      emit(_CreateError(message: e.toString(), sales: _sales, staff: _staff));
    }
  }

  Future<void> submit({
    required String saleId,
    required String address,
    required String courierId,
    required String notes,
  }) async {
    emit(_CreateSubmitting(sales: _sales, staff: _staff));
    try {
      await _client.post(
        '/stores/$storeId/deliveries',
        data: {
          'saleId': saleId,
          'address': address,
          'courierId': courierId,
          if (notes.isNotEmpty) 'notes': notes,
        },
      );
      emit(_CreateSuccess());
    } catch (e) {
      emit(_CreateError(message: e.toString(), sales: _sales, staff: _staff));
    }
  }
}

// ─── Page ────────────────────────────────────────────────────────────────────

class CreateDeliveryPage extends StatelessWidget {
  final String storeId;

  const CreateDeliveryPage({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _CreateCubit(sl<DioClient>(), storeId)..loadRefs(),
      child: const _CreateView(),
    );
  }
}

class _CreateView extends StatefulWidget {
  const _CreateView();

  @override
  State<_CreateView> createState() => _CreateViewState();
}

class _CreateViewState extends State<_CreateView> {
  final _formKey = GlobalKey<FormState>();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _selectedSaleId;
  String? _selectedCourierId;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit(List<_Sale> sales, List<_StaffMember> staff) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedSaleId == null) {
      AppSnackbar.info(context, AppLocalizations.of(context)!.snackSelectOrder);
      return;
    }
    if (_selectedCourierId == null) {
      AppSnackbar.info(context, AppLocalizations.of(context)!.snackSelectCourier);
      return;
    }
    context.read<_CreateCubit>().submit(
          saleId: _selectedSaleId!,
          address: _addressCtrl.text.trim(),
          courierId: _selectedCourierId!,
          notes: _notesCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<_CreateCubit, _CreateState>(
      listener: (context, state) {
        if (state is _CreateSuccess) {
          context.pop();
        }
        if (state is _CreateError) {
          AppSnackbar.error(context, state.message);
        }
      },
      child: Scaffold(
        backgroundColor: context.bg,
        appBar: AppBar(
          title: const Text('Новая доставка',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
          backgroundColor: Colors.white,
          foregroundColor: context.textPrimary,
          elevation: 0,
        ),
        body: BlocBuilder<_CreateCubit, _CreateState>(
          builder: (context, state) {
            if (state is _CreateRefsLoading || state is _CreateInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            List<_Sale> sales = [];
            List<_StaffMember> staff = [];
            bool isSubmitting = false;

            if (state is _CreateRefsLoaded) {
              sales = state.sales;
              staff = state.staff;
            } else if (state is _CreateSubmitting) {
              sales = state.sales;
              staff = state.staff;
              isSubmitting = true;
            } else if (state is _CreateError) {
              sales = state.sales;
              staff = state.staff;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sale dropdown
                    _FieldLabel('Заказ'),
                    const SizedBox(height: AppConstants.spacingXs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        border: Border.all(color: context.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSaleId,
                          isExpanded: true,
                          hint: Text('Выберите заказ',
                              style: TextStyle(color: context.textMuted)),
                          items: sales
                              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.label)))
                              .toList(),
                          onChanged: isSubmitting
                              ? null
                              : (v) => setState(() => _selectedSaleId = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingMd),

                    // Address
                    _FieldLabel('Адрес доставки'),
                    const SizedBox(height: AppConstants.spacingXs),
                    TextFormField(
                      controller: _addressCtrl,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        hintText: 'Введите адрес',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                          borderSide: BorderSide(color: context.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                          borderSide: BorderSide(color: context.border),
                        ),
                      ),
                      maxLines: 2,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Введите адрес' : null,
                    ),
                    const SizedBox(height: AppConstants.spacingMd),

                    // Courier dropdown
                    _FieldLabel('Курьер'),
                    const SizedBox(height: AppConstants.spacingXs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        border: Border.all(color: context.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCourierId,
                          isExpanded: true,
                          hint: Text('Выберите курьера',
                              style: TextStyle(color: context.textMuted)),
                          items: staff
                              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                              .toList(),
                          onChanged: isSubmitting
                              ? null
                              : (v) => setState(() => _selectedCourierId = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingMd),

                    // Notes
                    _FieldLabel('Примечания'),
                    const SizedBox(height: AppConstants.spacingXs),
                    TextFormField(
                      controller: _notesCtrl,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        hintText: 'Необязательно',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                          borderSide: BorderSide(color: context.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                          borderSide: BorderSide(color: context.border),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppConstants.spacingXl),

                    // Save
                    SizedBox(
                      width: double.infinity,
                      height: AppConstants.buttonHeight,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : () => _submit(sales, staff),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusLg)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.onPrimary))
                            : const Text('Создать доставку',
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingXl),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textSecondary));
  }
}
