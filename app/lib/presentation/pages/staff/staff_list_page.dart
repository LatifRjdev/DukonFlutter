import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_widget.dart';
import '../../blocs/staff/staff_bloc.dart';
import '../../blocs/staff/staff_event.dart';
import '../../blocs/staff/staff_state.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

class StaffListPage extends StatefulWidget {
  final String storeId;
  const StaffListPage({super.key, required this.storeId});
  @override
  State<StaffListPage> createState() => _StaffListPageState();
}

class _StaffListPageState extends State<StaffListPage> {
  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  void _loadStaff() {
    context.read<StaffBloc>().add(LoadStaff(storeId: widget.storeId));
  }

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  Color _roleBadgeColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN': return AppColors.primary;
      case 'CASHIER': return context.textSecondary;
      case 'WAREHOUSE': return AppColors.info;
      default: return context.textSecondary;
    }
  }

  String _roleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN': return 'Администратор';
      case 'CASHIER': return 'Кассир';
      case 'WAREHOUSE': return 'Склад';
      case 'OWNER': return 'Владелец';
      default: return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/staff/add', extra: widget.storeId),
        child: const Icon(Icons.add, color: AppColors.onPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), tooltip: l10n.back, onPressed: () => context.pop()),
                  const Text('Сотрудники',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add, color: AppColors.primary),
                    tooltip: l10n.addEmployee,
                    onPressed: () => context.push('/staff/add', extra: widget.storeId),
                  ),
                ],
              ),
            ),

            // Staff list
            Expanded(
              child: BlocBuilder<StaffBloc, StaffState>(
                builder: (context, state) {
                  if (state is StaffLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is StaffError) {
                    return AppErrorWidget(
                      message: state.message,
                      onRetry: _loadStaff,
                    );
                  }
                  if (state is StaffLoaded) {
                    if (state.staff.isEmpty) {
                      return AppEmptyState(
                        icon: Icons.people_outline,
                        title: 'Сотрудников пока нет',
                        subtitle: 'Добавьте сотрудников для учёта смен и зарплаты',
                        buttonText: 'Добавить сотрудника',
                        onButtonPressed: () => context.push('/staff/add', extra: widget.storeId),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async => _loadStaff(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.staff.length,
                        itemBuilder: (context, index) {
                          final staff = state.staff[index];
                          final isOnShift = staff.isOnShift;
                          final roleColor = _roleBadgeColor(staff.role);

                          return GestureDetector(
                            onTap: () => context.push('/staff/${staff.id}', extra: widget.storeId),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.surface,
                                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(staff.name,
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: roleColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                                              ),
                                              child: Text(_roleLabel(staff.role),
                                                style: TextStyle(fontSize: 12, color: roleColor, fontWeight: FontWeight.w500)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isOnShift ? AppColors.success : AppColors.error,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isOnShift ? 'На смене' : 'Не на смене',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isOnShift ? AppColors.success : context.textSecondary,
                                              ),
                                            ),
                                            if (isOnShift && staff.todaySales != null && staff.todaySales! > 0) ...[
                                              const SizedBox(width: 12),
                                              Text(
                                                'Сегодня: ${_formatPrice(staff.todaySales!)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: context.textSecondary, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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
}
