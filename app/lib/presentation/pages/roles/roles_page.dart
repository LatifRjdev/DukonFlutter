import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/roles/roles_bloc.dart';
import '../../blocs/roles/roles_event.dart';
import '../../blocs/roles/roles_state.dart';
import '../../widgets/staff/permission_toggle_row.dart';

class RolesPage extends StatefulWidget {
  final String storeId;
  const RolesPage({super.key, required this.storeId});
  @override
  State<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends State<RolesPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _roleTabs = ['OWNER', 'ADMIN', 'CASHIER', 'WAREHOUSE'];
  static const _roleLabels = ['Владелец', 'Админ', 'Кассир', 'Складовщик'];

  static const _allPermissions = [
    'manage_products',
    'manage_sales',
    'manage_returns',
    'view_reports',
    'manage_staff',
    'manage_expenses',
    'manage_customers',
    'manage_suppliers',
    'manage_stock',
    'manage_debts',
    'manage_settings',
    'open_close_shift',
    'apply_discounts',
    'manage_payroll',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _roleTabs.length, vsync: this);
    context.read<RolesBloc>().add(LoadRoles(storeId: widget.storeId));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Роли и права'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.lightTextSecondary,
          indicatorColor: AppColors.primary,
          tabs: _roleLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: BlocBuilder<RolesBloc, RolesState>(
        builder: (context, state) {
          if (state is RolesLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is RolesError) {
            return Center(child: Text(state.message));
          }
          if (state is RolesLoaded) {
            return TabBarView(
              controller: _tabController,
              children: _roleTabs.map((role) {
                final rolePermission = state.roles
                    .where((r) => r.role == role)
                    .toList();
                final permissions = rolePermission.isNotEmpty
                    ? rolePermission.first.permissions
                    : <String, bool>{};
                final isOwner = role == 'OWNER';

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
                  itemCount: _allPermissions.length,
                  itemBuilder: (context, index) {
                    final perm = _allPermissions[index];
                    final isEnabled = isOwner ? true : (permissions[perm] ?? false);

                    return PermissionToggleRow(
                      permissionKey: perm,
                      label: PermissionToggleRow.permissionLabel(perm),
                      value: isEnabled,
                      enabled: !isOwner,
                      onChanged: isOwner
                          ? null
                          : (value) {
                              context.read<RolesBloc>().add(UpdatePermission(
                                storeId: widget.storeId,
                                role: role,
                                permission: perm,
                                value: value,
                              ));
                            },
                    );
                  },
                );
              }).toList(),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
