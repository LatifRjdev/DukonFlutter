import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/router/route_names.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/settings/settings_bloc.dart';
import '../../blocs/settings/settings_event.dart';
import '../../blocs/settings/settings_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_event.dart';
import '../../blocs/store/store_state.dart';
import '../../../core/network/dio_client.dart';
import '../../../injection.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    context.read<SettingsBloc>().add(SettingsProfileRequested());
  }

  String _getStoreId() {
    final storeState = context.read<StoreBloc>().state;
    return storeState is StoreLoaded ? storeState.selectedStore?.id ?? '' : '';
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<StoreBloc>().add(StoreResetRequested());
              context.read<AuthBloc>().add(AuthLogoutRequested());
              context.go('/login');
            },
            child: const Text('Выйти', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Настройки',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: BlocBuilder<SettingsBloc, SettingsState>(
                builder: (context, state) {
                  if (state is SettingsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is SettingsError) {
                    return Center(child: Text(state.message));
                  }
                  if (state is SettingsLoaded) {
                    final user = state.user;
                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Profile card
                        GestureDetector(
                          onTap: () => context.push(RouteNames.editProfile),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text(user.name,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text('Владелец',
                                          style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: context.textSecondary, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Магазин section
                        _buildSectionLabel('Магазин'),
                        const SizedBox(height: 8),
                        _buildSectionCard([
                          _buildTile(Icons.storefront_outlined, 'Мои магазины',
                            onTap: () => context.push(RouteNames.myStores)),
                          _buildDivider(),
                          _buildTile(Icons.people_outlined, 'Продавцы',
                            onTap: () => context.push(RouteNames.staffList, extra: _getStoreId())),
                          _buildDivider(),
                          _buildTile(Icons.admin_panel_settings_outlined, 'Роли и доступы',
                            onTap: () => context.push(RouteNames.roles, extra: _getStoreId())),
                          _buildDivider(),
                          _buildTile(Icons.discount_outlined, 'Скидки',
                            onTap: () => context.push(RouteNames.discounts, extra: _getStoreId())),
                          _buildDivider(),
                          _buildTile(Icons.receipt_long_outlined, 'Шаблоны чеков',
                            onTap: () => context.push(RouteNames.receiptTemplate, extra: _getStoreId())),
                        ]),
                        const SizedBox(height: 20),

                        // Интеграции section
                        _buildSectionLabel('Интеграции'),
                        const SizedBox(height: 8),
                        _buildSectionCard([
                          _buildTile(Icons.send_outlined, 'Telegram-бот',
                            badge: 'Подключён', badgeColor: AppColors.success,
                            onTap: () => context.push(RouteNames.telegramBot, extra: _getStoreId())),
                          _buildDivider(),
                          _buildTile(Icons.point_of_sale_outlined, 'ККМ / Фискализация',
                            onTap: () => context.push(RouteNames.kkmSettings)),
                          _buildDivider(),
                          _buildTile(Icons.print_outlined, 'Принтер чеков',
                            onTap: () => context.push(RouteNames.printerSettings)),
                          _buildDivider(),
                          _buildTile(Icons.qr_code_scanner_outlined, 'Сканер',
                            onTap: () => context.push(RouteNames.scannerSettings)),
                        ]),
                        const SizedBox(height: 20),

                        // Приложение section
                        _buildSectionLabel('Приложение'),
                        const SizedBox(height: 8),
                        _buildSectionCard([
                          _buildToggleTile(Icons.notifications_outlined, 'Уведомления',
                            value: _notificationsEnabled,
                            onChanged: (v) async {
                              setState(() => _notificationsEnabled = v);
                              try {
                                await sl<DioClient>().put(
                                  '/stores/${_getStoreId()}/notification-settings',
                                  data: {'enabled': v},
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                setState(() => _notificationsEnabled = !v);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Не удалось сохранить настройку')),
                                );
                              }
                            }),
                          _buildDivider(),
                          BlocBuilder<SettingsBloc, SettingsState>(
                            builder: (context, state) {
                              final isDark = state is SettingsLoaded &&
                                  state.themeMode == ThemeMode.dark;
                              return _buildToggleTile(
                                Icons.dark_mode_outlined,
                                'Тёмная тема',
                                value: isDark,
                                onChanged: (value) {
                                  context.read<SettingsBloc>().add(
                                    SettingsThemeChanged(
                                        value ? ThemeMode.dark : ThemeMode.light),
                                  );
                                },
                              );
                            },
                          ),
                          _buildDivider(),
                          _buildTile(Icons.language_outlined, 'Язык',
                            trailing: Text('Русский',
                              style: TextStyle(fontSize: 13, color: context.textSecondary)),
                            onTap: () => context.push(RouteNames.languageSettings)),
                          _buildDivider(),
                          _buildTile(Icons.cloud_done_outlined, 'Офлайн-режим',
                            trailing: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, size: 14, color: AppColors.success),
                                SizedBox(width: 4),
                                Text('Синхронизировано',
                                  style: TextStyle(fontSize: 12, color: AppColors.success)),
                              ],
                            ),
                            onTap: () => context.push(RouteNames.offlineMode)),
                        ]),
                        const SizedBox(height: 20),

                        // Подписка section
                        _buildSectionLabel('Подписка'),
                        const SizedBox(height: 8),
                        _buildSectionCard([
                          _buildTile(Icons.workspace_premium_outlined, 'БИЗНЕС до 30.03.2026',
                            trailing: const Text('Сменить тариф',
                              style: TextStyle(fontSize: 12, color: AppColors.primary)),
                            onTap: () => context.push(RouteNames.subscription)),
                        ]),
                        const SizedBox(height: 24),

                        // Logout button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _showLogoutDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Выйти из аккаунта',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
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

  Widget _buildSectionLabel(String title) {
    return Text(title,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary));
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 52, endIndent: 16);
  }

  Widget _buildTile(IconData icon, String title, {
    VoidCallback? onTap,
    String? badge,
    Color? badgeColor,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? AppColors.primary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(badge,
                        style: TextStyle(fontSize: 10, color: badgeColor ?? AppColors.primary, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else
              Icon(Icons.chevron_right, color: context.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile(IconData icon, String title, {
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
