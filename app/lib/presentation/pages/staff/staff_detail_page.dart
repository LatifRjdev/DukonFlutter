import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/staff/staff_bloc.dart';
import '../../blocs/staff/staff_event.dart';
import '../../blocs/staff/staff_state.dart';
import '../../blocs/shift/shift_bloc.dart';
import '../../blocs/shift/shift_event.dart';
import '../../blocs/shift/shift_state.dart';
import '../../widgets/shifts/shift_card.dart';

class StaffDetailPage extends StatefulWidget {
  final String storeId;
  final String staffId;
  const StaffDetailPage({super.key, required this.storeId, required this.staffId});
  @override
  State<StaffDetailPage> createState() => _StaffDetailPageState();
}

class _StaffDetailPageState extends State<StaffDetailPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<StaffBloc>().add(LoadStaffDetail(storeId: widget.storeId, id: widget.staffId));
    context.read<ShiftBloc>().add(LoadShifts(storeId: widget.storeId, staffId: widget.staffId));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'OWNER':
        return 'Владелец';
      case 'ADMIN':
        return 'Админ';
      case 'CASHIER':
        return 'Кассир';
      case 'WAREHOUSE':
        return 'Складовщик';
      default:
        return role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'OWNER':
        return AppColors.warning;
      case 'ADMIN':
        return AppColors.info;
      case 'CASHIER':
        return AppColors.success;
      case 'WAREHOUSE':
        return AppColors.warning;
      default:
        return context.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль сотрудника'),
        actions: [
          BlocBuilder<StaffBloc, StaffState>(
            builder: (context, state) {
              if (state is StaffDetailLoaded) {
                return IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => context.push(
                    '/edit-staff/${widget.storeId}/${widget.staffId}',
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<StaffBloc, StaffState>(
        builder: (context, state) {
          if (state is StaffLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is StaffError) {
            return Center(child: Text(state.message));
          }
          if (state is StaffDetailLoaded) {
            final member = state.staffMember;
            final roleColor = _roleColor(member.role);
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.spacingLg),
                  color: context.surface,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: roleColor.withValues(alpha: 0.15),
                        backgroundImage: member.avatar != null ? NetworkImage(member.avatar!) : null,
                        child: member.avatar == null
                            ? Text(
                                member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                                style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 28),
                              )
                            : null,
                      ),
                      const SizedBox(height: AppConstants.spacingMd),
                      Text(
                        member.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        ),
                        child: Text(
                          _roleLabel(member.role),
                          style: TextStyle(color: roleColor, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (member.phone != null) ...[
                        const SizedBox(height: AppConstants.spacingSm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone, size: 16, color: context.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              member.phone!,
                              style: TextStyle(fontSize: 14, color: context.textSecondary),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppConstants.spacingMd),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _InfoColumn(
                            label: 'Оклад',
                            value: member.salary != null ? '${member.salary!.toStringAsFixed(0)} TJS' : '-',
                          ),
                          _InfoColumn(
                            label: 'Комиссия',
                            value: member.commission != null ? '${member.commission!.toStringAsFixed(1)}%' : '-',
                          ),
                          _InfoColumn(
                            label: 'Статус',
                            value: member.isOnShift ? 'На смене' : 'Нет смены',
                            valueColor: member.isOnShift ? AppColors.success : context.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: context.textSecondary,
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'Смены'),
                    Tab(text: 'Статистика'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _ShiftsTab(storeId: widget.storeId, staffId: widget.staffId),
                      _StatsTab(member: member),
                    ],
                  ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoColumn({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: valueColor ?? context.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary)),
      ],
    );
  }
}

class _ShiftsTab extends StatelessWidget {
  final String storeId;
  final String staffId;
  const _ShiftsTab({required this.storeId, required this.staffId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShiftBloc, ShiftState>(
      builder: (context, state) {
        if (state is ShiftLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ShiftLoaded) {
          if (state.shifts.isEmpty) {
            return Center(
              child: Text('Нет смен', style: TextStyle(color: context.textSecondary, fontSize: 16)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            itemCount: state.shifts.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppConstants.spacingSm),
            itemBuilder: (context, index) {
              final shift = state.shifts[index];
              return ShiftCard(
                shift: shift,
                onTap: () => context.push('/z-report/$storeId/${shift.id}'),
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _StatsTab extends StatelessWidget {
  final dynamic member;
  const _StatsTab({required this.member});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        children: [
          _StatRow(label: 'Продажи сегодня', value: '${member.todaySales?.toStringAsFixed(0) ?? "0"} TJS'),
          Divider(height: 1, color: context.border),
          _StatRow(label: 'Дата регистрации', value: '${member.createdAt.day.toString().padLeft(2, '0')}.${member.createdAt.month.toString().padLeft(2, '0')}.${member.createdAt.year}'),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: context.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
