import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../blocs/staff/staff_bloc.dart';
import '../../blocs/staff/staff_event.dart';
import '../../blocs/staff/staff_state.dart';

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
      case 'CASHIER': return AppColors.textSecondary;
      case 'WAREHOUSE': return const Color(0xFF9C27B0);
      default: return AppColors.textSecondary;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/staff/add', extra: widget.storeId),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                  const Text('Сотрудники',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add, color: AppColors.primary),
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
                    return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
                  }
                  if (state is StaffLoaded) {
                    if (state.staff.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: AppColors.disabled),
                            SizedBox(height: 16),
                            Text('Сотрудников пока нет',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                          ],
                        ),
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
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
                                            Text(staff.name,
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: roleColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(_roleLabel(staff.role),
                                                style: TextStyle(fontSize: 11, color: roleColor, fontWeight: FontWeight.w500)),
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
                                                color: isOnShift ? AppColors.success : AppColors.textSecondary,
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
                                  const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
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
