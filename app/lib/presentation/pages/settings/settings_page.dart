import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/router/route_names.dart';
import '../../../domain/entities/staff_member.dart';
import '../../../domain/repositories/staff_repository.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/settings/settings_bloc.dart';
import '../../blocs/settings/settings_event.dart';
import '../../blocs/settings/settings_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_event.dart';
import '../../blocs/store/store_state.dart';
import '../../blocs/subscription/subscription_bloc.dart';
import '../../blocs/subscription/subscription_event.dart';
import '../../blocs/subscription/subscription_state.dart';
import '../../../core/network/dio_client.dart';
import '../../../injection.dart';
import '../../widgets/common/app_snackbar.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;

  // SPEC.md #13 step 1 — role badge. Resolved from already-loaded StoreBloc
  // (store.ownerId) for owners; falls back to a StaffRepository lookup for
  // non-owners. Null while unresolved — the badge is simply hidden rather
  // than ever showing an incorrect role.
  String? _roleCode;
  bool _roleRequested = false;

  // SPEC.md #13 step 2 — Telegram-bot connection status, same
  // GET /stores/:storeId/telegram-bot/status call telegram_bot_settings_page.dart makes.
  bool _telegramStatusLoaded = false;
  bool _telegramConnected = false;

  // SPEC.md #13 step 3 — language display, same SharedPreferences key
  // ('app_language') language_settings_page.dart reads/writes.
  String _languageCode = 'ru';

  // SPEC.md #13 step 4 — offline/sync status, same GET /sync/status call
  // offline_mode_page.dart makes. Defaults to 0 (i.e. "synced"), matching
  // that page's own fallback-on-failure behavior.
  int _pendingSyncOps = 0;

  @override
  void initState() {
    super.initState();
    context.read<SettingsBloc>().add(SettingsProfileRequested());
    final storeId = _getStoreId();
    if (storeId.isNotEmpty) {
      context.read<SubscriptionBloc>().add(SubscriptionLoadRequested(storeId: storeId));
      _loadTelegramStatus(storeId);
    }
    _loadLanguagePreference();
    _loadSyncStatus();
  }

  String _getStoreId() {
    final storeState = context.read<StoreBloc>().state;
    return storeState is StoreLoaded ? storeState.selectedStore?.id ?? '' : '';
  }

  Future<void> _loadRole(String userId) async {
    if (_roleCode != null || _roleRequested) return;
    final storeState = context.read<StoreBloc>().state;
    final store = storeState is StoreLoaded ? storeState.selectedStore : null;
    if (store == null) return; // retried on the next SettingsLoaded emission

    if (store.ownerId == userId) {
      if (mounted) setState(() => _roleCode = 'OWNER');
      return;
    }

    _roleRequested = true;
    try {
      final result = await sl<StaffRepository>().getStaff(store.id);
      StaffMember? mine;
      for (final member in result.data) {
        if (member.userId == userId) {
          mine = member;
          break;
        }
      }
      if (mine != null && mounted) {
        setState(() => _roleCode = mine!.role);
      }
    } catch (_) {
      // Staff lookup unavailable (e.g. offline, or no staff repository in
      // this context) — leave the badge unresolved rather than guess.
    }
  }

  String _roleLabel(String role, AppLocalizations l10n) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return l10n.owner;
      case 'ADMIN':
        return l10n.adminRoleShort;
      case 'CASHIER':
        return l10n.cashier;
      case 'WAREHOUSE':
        return l10n.warehouse;
      default:
        return role;
    }
  }

  Future<void> _loadTelegramStatus(String storeId) async {
    try {
      final res = await sl<DioClient>().get('/stores/$storeId/telegram-bot/status');
      final data = res.data as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _telegramConnected = data['connected'] as bool? ?? false;
          _telegramStatusLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _telegramStatusLoaded = true);
    }
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_language') ?? 'ru';
    if (mounted) setState(() => _languageCode = code);
  }

  String _languageLabel(String code) {
    switch (code) {
      case 'tg':
        return 'Тоҷикӣ';
      case 'uz':
        return 'Ўзбекча';
      case 'ru':
      default:
        return 'Русский';
    }
  }

  Future<void> _loadSyncStatus() async {
    try {
      final res = await sl<DioClient>().get('/sync/status');
      final data = res.data as Map<String, dynamic>? ?? {};
      final pending = data['pendingOperations'] as int? ?? 0;
      if (mounted) setState(() => _pendingSyncOps = pending);
    } catch (_) {
      // Leave the optimistic default — matches offline_mode_page.dart's
      // own fallback for this same endpoint.
    }
  }

  String _planLabel(String plan) {
    switch (plan) {
      case 'START':
        return 'Старт';
      case 'BUSINESS':
        return 'Бизнес';
      case 'PREMIUM':
        return 'Премиум';
      default:
        return plan;
    }
  }

  void _showLogoutDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsLogoutTitle),
        content: Text(l10n.settingsLogoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<StoreBloc>().add(StoreResetRequested());
              context.read<AuthBloc>().add(AuthLogoutRequested());
              context.go('/login');
            },
            child: Text(l10n.logout, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showPremiumUpsellDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsPremiumGateTitle),
        content: Text(l10n.settingsPremiumGateBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.settingsPremiumGateLater),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(RouteNames.subscription);
            },
            child: Text(l10n.settingsPremiumGateUpgrade),
          ),
        ],
      ),
    );
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.settings,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: BlocListener<SettingsBloc, SettingsState>(
                listener: (context, state) {
                  if (state is SettingsLoaded) {
                    _loadRole(state.user.id);
                  }
                },
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
                        Semantics(
                          label: l10n.a11yEditProfile,
                          button: true,
                          child: GestureDetector(
                          onTap: () => context.push(RouteNames.editProfile),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                              boxShadow: context.elevationMd,
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
                                      if (_roleCode != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                                          ),
                                          child: Text(_roleLabel(_roleCode!, l10n),
                                            style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: context.textSecondary, size: 20),
                              ],
                            ),
                          ),
                        ),
                        ),
                        const SizedBox(height: 20),

                        // Магазин section
                        _buildSectionLabel(l10n.moreStoreTitle),
                        const SizedBox(height: 8),
                        _buildSectionCard([
                          _buildTile(Icons.storefront_outlined, l10n.moreMyStores,
                            onTap: () => context.push(RouteNames.myStores)),
                          _buildDivider(),
                          _buildTile(Icons.people_outlined, l10n.settingsTileStaff,
                            onTap: () => context.push(RouteNames.staffList, extra: _getStoreId())),
                          _buildDivider(),
                          _buildTile(Icons.admin_panel_settings_outlined, l10n.settingsTileRoles,
                            onTap: () => context.push(RouteNames.roles, extra: _getStoreId())),
                          _buildDivider(),
                          _buildTile(Icons.discount_outlined, l10n.discountsPageTitle,
                            onTap: () => context.push(RouteNames.discounts, extra: _getStoreId())),
                          _buildDivider(),
                          _buildTile(Icons.card_giftcard_outlined, l10n.loyaltySettingsTitle,
                            onTap: () => context.push(RouteNames.loyaltySettings, extra: _getStoreId())),
                          _buildDivider(),
                          _buildTile(Icons.receipt_long_outlined, l10n.settingsTileReceiptTemplates,
                            onTap: () => context.push(RouteNames.receiptTemplate, extra: _getStoreId())),
                        ]),
                        const SizedBox(height: 20),

                        // Интеграции section
                        _buildSectionLabel(l10n.settingsSectionIntegrations),
                        const SizedBox(height: 8),
                        _buildSectionCard([
                          _buildTile(Icons.send_outlined, l10n.settingsTileTelegramBot,
                            badge: _telegramStatusLoaded
                                ? (_telegramConnected ? l10n.printerSettingsConnected : l10n.printerSettingsNotConnected)
                                : null,
                            badgeColor: _telegramStatusLoaded
                                ? (_telegramConnected ? AppColors.success : AppColors.error)
                                : null,
                            onTap: () => context.push(RouteNames.telegramBot, extra: _getStoreId())),
                          _buildDivider(),
                          _buildTile(Icons.point_of_sale_outlined, l10n.settingsTileKkm,
                            onTap: () => context.push(RouteNames.kkmSettings)),
                          _buildDivider(),
                          _buildTile(Icons.print_outlined, l10n.settingsTilePrinter,
                            onTap: () => context.push(RouteNames.printerSettings)),
                          _buildDivider(),
                          _buildTile(Icons.qr_code_scanner_outlined, l10n.settingsTileScanner,
                            onTap: () => context.push(RouteNames.scannerSettings)),
                          _buildDivider(),
                          BlocBuilder<SubscriptionBloc, SubscriptionState>(
                            builder: (_, sub) {
                              final stillLoading = sub is SubscriptionInitial ||
                                  sub is SubscriptionLoading;
                              final hasEcommerce = sub is SubscriptionLoaded &&
                                  sub.features.hasEcommerceIntegration;
                              final confirmedIneligible = !stillLoading && !hasEcommerce;
                              return _buildTile(
                                Icons.storefront_outlined,
                                l10n.ecommerceSettingsTitle,
                                badge: confirmedIneligible ? 'PREMIUM' : null,
                                badgeColor: confirmedIneligible ? AppColors.warning : null,
                                onTap: stillLoading
                                    ? null
                                    : (hasEcommerce
                                        ? () => context.push(RouteNames.ecommerceSettings, extra: _getStoreId())
                                        : _showPremiumUpsellDialog),
                              );
                            },
                          ),
                        ]),
                        const SizedBox(height: 20),

                        // Приложение section
                        _buildSectionLabel(l10n.settingsSectionApp),
                        const SizedBox(height: 8),
                        _buildSectionCard([
                          _buildToggleTile(Icons.notifications_outlined, l10n.notifications,
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
                                AppSnackbar.info(context, AppLocalizations.of(context)!.snackSettingSaveFailed);
                              }
                            }),
                          _buildDivider(),
                          BlocBuilder<SettingsBloc, SettingsState>(
                            builder: (context, state) {
                              final isDark = state is SettingsLoaded &&
                                  state.themeMode == ThemeMode.dark;
                              return _buildToggleTile(
                                Icons.dark_mode_outlined,
                                l10n.darkMode,
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
                          _buildTile(Icons.language_outlined, l10n.language,
                            trailing: Text(_languageLabel(_languageCode),
                              style: TextStyle(fontSize: 13, color: context.textSecondary)),
                            onTap: () => context.push(RouteNames.languageSettings)),
                          _buildDivider(),
                          _buildTile(Icons.cloud_done_outlined, l10n.settingsTileOfflineMode,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _pendingSyncOps == 0 ? Icons.check : Icons.cloud_upload_outlined,
                                  size: 14,
                                  color: _pendingSyncOps == 0 ? AppColors.success : AppColors.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _pendingSyncOps == 0
                                      ? l10n.settingsSynced
                                      : l10n.settingsPendingSyncOps(_pendingSyncOps.toString()),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _pendingSyncOps == 0 ? AppColors.success : AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => context.push(RouteNames.offlineMode)),
                        ]),
                        const SizedBox(height: 20),

                        // Подписка section
                        _buildSectionLabel(l10n.settingsSectionSubscription),
                        const SizedBox(height: 8),
                        BlocBuilder<SubscriptionBloc, SubscriptionState>(
                          builder: (_, sub) {
                            String planTitle = l10n.settingsPlanFallbackLabel;
                            if (sub is SubscriptionLoaded) {
                              final planLabel = _planLabel(sub.plan);
                              planTitle = sub.expiresAt != null
                                  ? l10n.settingsPlanUntilDate(planLabel, DateFormat('dd.MM.yyyy').format(sub.expiresAt!))
                                  : planLabel;
                            }
                            return _buildSectionCard([
                              _buildTile(Icons.workspace_premium_outlined, planTitle,
                                trailing: Text(l10n.settingsChangePlan,
                                  style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                                onTap: () => context.push(RouteNames.subscription)),
                            ]);
                          },
                        ),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
                            ),
                            child: Text(l10n.settingsLogoutButton,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
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
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
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
                        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: Text(badge,
                        style: TextStyle(fontSize: 12, color: badgeColor ?? AppColors.primary, fontWeight: FontWeight.w500)),
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
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
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
