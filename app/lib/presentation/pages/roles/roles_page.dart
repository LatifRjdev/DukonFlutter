import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/role_permission.dart';
import '../../blocs/roles/roles_bloc.dart';
import '../../blocs/roles/roles_event.dart';
import '../../blocs/roles/roles_state.dart';
import '../../widgets/common/app_snackbar.dart';
import '../../widgets/staff/permission_toggle_row.dart';

class RolesPage extends StatefulWidget {
  final String storeId;
  const RolesPage({super.key, required this.storeId});
  @override
  State<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends State<RolesPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isSaving = false;

  static const _roleTabs = ['OWNER', 'ADMIN', 'CASHIER', 'WAREHOUSE'];

  List<String> _roleLabels(AppLocalizations l10n) => [
        l10n.owner,
        l10n.adminRoleShort,
        l10n.cashier,
        l10n.warehouse,
      ];

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
    // The footer Save button's enabled state depends on the selected role
    // (disabled for OWNER), so rebuild whenever the tab selection settles.
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    context.read<RolesBloc>().add(LoadRoles(storeId: widget.storeId));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onSave() {
    final role = _roleTabs[_tabController.index];
    final state = context.read<RolesBloc>().state;
    if (state is! RolesLoaded) return;

    final rolePermission = state.roles.firstWhere(
      (r) => r.role == role,
      orElse: () => RolePermission(role: role, permissions: const {}),
    );

    setState(() => _isSaving = true);
    context.read<RolesBloc>().add(SavePermissions(
          storeId: widget.storeId,
          role: role,
          permissions: rolePermission.permissions,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moreRolesAndPermissions),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: _roleLabels(l10n).map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: BlocConsumer<RolesBloc, RolesState>(
        listener: (context, state) {
          if (!_isSaving) return;
          if (state is RolesLoaded) {
            setState(() => _isSaving = false);
            AppSnackbar.success(context, l10n.snackSettingsSaved);
          } else if (state is RolesError) {
            setState(() => _isSaving = false);
            AppSnackbar.error(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is RolesLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is RolesError) {
            return Center(child: Text(state.message));
          }
          if (state is RolesLoaded) {
            final currentRole = _roleTabs[_tabController.index];
            final canSaveCurrentRole = currentRole != 'OWNER';

            return Column(
              children: [
                Expanded(
                  child: TabBarView(
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
                            enabled: !isOwner && !_isSaving,
                            onChanged: (isOwner || _isSaving)
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
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.spacingMd),
                    child: SizedBox(
                      width: double.infinity,
                      height: AppConstants.buttonHeight,
                      child: ElevatedButton(
                        key: const Key('roles_save_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                          ),
                        ),
                        onPressed: (!canSaveCurrentRole || _isSaving)
                            ? null
                            : _onSave,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                l10n.save,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
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
