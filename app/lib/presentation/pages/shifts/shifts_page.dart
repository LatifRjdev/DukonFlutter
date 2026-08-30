import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/shift.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/shift/shift_bloc.dart';
import '../../blocs/shift/shift_event.dart';
import '../../blocs/shift/shift_state.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_widget.dart';
import '../../widgets/common/app_snackbar.dart';
import '../../widgets/common/app_text_field.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

class ShiftsPage extends StatefulWidget {
  final String storeId;
  const ShiftsPage({super.key, required this.storeId});
  @override
  State<ShiftsPage> createState() => _ShiftsPageState();
}

class _ShiftsPageState extends State<ShiftsPage> {
  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    context.read<ShiftBloc>().add(LoadCurrentShift(storeId: widget.storeId));
    context.read<ShiftBloc>().add(LoadShifts(storeId: widget.storeId));
  }

  void _showCloseShiftDialog(ShiftModel currentShift) {
    final cashController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    // Dispose controller once the dialog route is gone (FE-P1-004).
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Закрыть смену'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Введите сумму наличных в кассе:'),
              const SizedBox(height: 12),
              AppTextField(
                controller: cashController,
                label: 'Сумма наличных',
                prefixIcon: Icons.attach_money,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите сумму';
                  if (double.tryParse(v) == null) return 'Некорректная сумма';
                  if (double.parse(v) < 0) return 'Сумма не может быть отрицательной';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final cash = double.parse(cashController.text);
              context.read<ShiftBloc>().add(CloseShift(
                storeId: widget.storeId,
                shiftId: currentShift.id,
                closingCash: cash,
              ));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Закрыть', style: TextStyle(color: AppColors.onPrimary)),
          ),
        ],
      ),
    ).whenComplete(cashController.dispose);
  }

  String _formatDuration(DateTime start) {
    final now = DateTime.now();
    final diff = now.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return '$hoursч $minutesм';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), tooltip: l10n.back, onPressed: () => context.pop()),
                  const Text('Смены',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  BlocBuilder<ShiftBloc, ShiftState>(
                    builder: (context, state) {
                      if (state is ShiftLoaded && state.currentShift == null) {
                        return OutlinedButton(
                          onPressed: () => context.push('/shifts/open', extra: widget.storeId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
                          ),
                          child: const Text('Открыть смену', style: TextStyle(fontSize: 13)),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: BlocConsumer<ShiftBloc, ShiftState>(
                listener: (context, state) {
                  if (state is ShiftOpened) {
                    AppSnackbar.success(context, l10n.snackShiftOpened);
                    _loadData();
                  }
                  if (state is ShiftClosed) {
                    AppSnackbar.success(context, l10n.snackShiftClosed);
                    context.push('/shifts/${state.shift.id}/z-report', extra: widget.storeId);
                    _loadData();
                  }
                  if (state is ShiftError) {
                    AppSnackbar.error(context, state.message);
                  }
                },
                builder: (context, state) {
                  if (state is ShiftLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is ShiftLoaded) {
                    return RefreshIndicator(
                      onRefresh: () async => _loadData(),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Current shift card
                          if (state.currentShift != null) ...[
                            _buildCurrentShiftCard(state.currentShift!),
                            const SizedBox(height: 20),
                          ],
                          // History
                          if (state.shifts.isNotEmpty) ...[
                            const Text('История смен',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            ...state.shifts.map((shift) => _buildShiftHistoryCard(shift)),
                          ],
                          if (state.currentShift == null && state.shifts.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 60),
                              child: AppEmptyState(
                                icon: Icons.access_time,
                                title: 'Нет смен',
                                subtitle: 'Откройте смену, чтобы начать приём платежей',
                              ),
                            ),
                        ],
                      ),
                    );
                  }
                  if (state is ShiftError) {
                    return AppErrorWidget(
                      message: state.message,
                      onRetry: _loadData,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentShiftCard(ShiftModel shift) {
    final timeFormat = DateFormat('HH:mm');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: const Border(left: BorderSide(color: AppColors.success, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Текущая смена',
                style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: const Text('Активна',
                  style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Кассир: ${shift.staffName ?? 'Не указан'}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Открыта: ${timeFormat.format(shift.openedAt)}  •  Время работы: ${_formatDuration(shift.openedAt)}',
            style: TextStyle(fontSize: 13, color: context.textSecondary)),
          const SizedBox(height: 4),
          Text('Продаж: ${shift.salesCount}  |  Сумма: ${_formatPrice(shift.salesTotal)}',
            style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showCloseShiftDialog(shift),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
              ),
              child: const Text('Закрыть смену', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftHistoryCard(ShiftModel shift) {
    final dateFormat = DateFormat('dd.MM');
    final timeFormat = DateFormat('HH:mm');

    return Semantics(
      label: AppLocalizations.of(context)!.a11yOpenZReport,
      button: true,
      child: GestureDetector(
      onTap: () => context.push('/shifts/${shift.id}/z-report', extra: widget.storeId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(dateFormat.format(shift.openedAt),
                        style: TextStyle(fontSize: 13, color: context.textSecondary)),
                      const SizedBox(width: 8),
                      Text(shift.staffName ?? '—',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${timeFormat.format(shift.openedAt)}–${shift.closedAt != null ? timeFormat.format(shift.closedAt!) : '...'}  •  ${shift.salesCount} продаж  •  ${_formatPrice(shift.salesTotal)}',
                    style: TextStyle(fontSize: 12, color: context.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: shift.closedAt != null
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
              child: Text(
                shift.closedAt != null ? 'Сдано' : 'Открыта',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: shift.closedAt != null ? AppColors.success : AppColors.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
