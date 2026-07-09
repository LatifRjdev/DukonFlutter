import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../blocs/loyalty/loyalty_settings_bloc.dart';
import '../../blocs/loyalty/loyalty_settings_event.dart';
import '../../blocs/loyalty/loyalty_settings_state.dart';
import '../../widgets/common/app_snackbar.dart';

class LoyaltySettingsPage extends StatefulWidget {
  final String storeId;
  const LoyaltySettingsPage({super.key, required this.storeId});

  @override
  State<LoyaltySettingsPage> createState() => _LoyaltySettingsPageState();
}

class _LoyaltySettingsPageState extends State<LoyaltySettingsPage> {
  bool _isEnabled = false;
  final _amountCtrl = TextEditingController();
  final _pointsPerAmountCtrl = TextEditingController();
  final _pointValueCtrl = TextEditingController();
  final _welcomePointsCtrl = TextEditingController();
  final _birthdayDiscountCtrl = TextEditingController();
  final _pointsExpireDaysCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<LoyaltySettingsBloc>().add(
          LoyaltySettingsLoadRequested(widget.storeId),
        );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _pointsPerAmountCtrl.dispose();
    _pointValueCtrl.dispose();
    _welcomePointsCtrl.dispose();
    _birthdayDiscountCtrl.dispose();
    _pointsExpireDaysCtrl.dispose();
    super.dispose();
  }

  void _populate(Map<String, dynamic> settings) {
    _isEnabled = settings['isEnabled'] as bool? ?? false;
    _amountCtrl.text = settings['amountForPoints']?.toString() ?? '';
    _pointsPerAmountCtrl.text = settings['pointsPerAmount']?.toString() ?? '';
    _pointValueCtrl.text = settings['pointValue']?.toString() ?? '';
    _welcomePointsCtrl.text = settings['welcomePoints']?.toString() ?? '';
    _birthdayDiscountCtrl.text =
        settings['birthdayDiscount']?.toString() ?? '';
    _pointsExpireDaysCtrl.text =
        settings['pointsExpireDays']?.toString() ?? '';
    setState(() {});
  }

  void _onSave() {
    context.read<LoyaltySettingsBloc>().add(
          LoyaltySettingsSaveRequested(
            widget.storeId,
            {
              'isEnabled': _isEnabled,
              'amountForPoints':
                  double.tryParse(_amountCtrl.text.trim()),
              'pointsPerAmount':
                  double.tryParse(_pointsPerAmountCtrl.text.trim()),
              'pointValue':
                  double.tryParse(_pointValueCtrl.text.trim()),
              'welcomePoints':
                  int.tryParse(_welcomePointsCtrl.text.trim()),
              'birthdayDiscount': _birthdayDiscountCtrl.text.trim().isEmpty
                  ? null
                  : double.tryParse(_birthdayDiscountCtrl.text.trim()),
              'pointsExpireDays': _pointsExpireDaysCtrl.text.trim().isEmpty
                  ? null
                  : int.tryParse(_pointsExpireDaysCtrl.text.trim()),
            },
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoyaltySettingsBloc, LoyaltySettingsState>(
      listener: (context, state) {
        if (state is LoyaltySettingsLoaded) {
          _populate(state.settings);
        }
        if (state is LoyaltySettingsSaved) {
          _populate(state.settings);
          AppSnackbar.success(context, 'Настройки сохранены');
        }
        if (state is LoyaltySettingsError) {
          AppSnackbar.error(context, state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is LoyaltySettingsLoading;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Программа лояльности'),
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.bar_chart_outlined),
                label: const Text('Аналитика'),
                onPressed: () => context.push(
                  RouteNames.loyaltyAnalytics,
                  extra: widget.storeId,
                ),
              ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enable toggle
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusLg),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Активна',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            Switch(
                              value: _isEnabled,
                              onChanged: (v) =>
                                  setState(() => _isEnabled = v),
                              activeThumbColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Accrual settings card
                      _buildSectionLabel('Начисление баллов'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusLg),
                        ),
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _amountCtrl,
                              label: 'За каждые __ сом',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _pointsPerAmountCtrl,
                              label: 'Начислять __ баллов',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _pointValueCtrl,
                              label: '1 балл = __ сом',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bonus settings card
                      _buildSectionLabel('Бонусы'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusLg),
                        ),
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _welcomePointsCtrl,
                              label: 'Приветственные баллы',
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _birthdayDiscountCtrl,
                              label: 'Скидка в день рождения, %',
                              hint: 'Оставьте пустым, если не нужно',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _pointsExpireDaysCtrl,
                              label: 'Срок действия баллов, дней',
                              hint: 'Оставьте пустым — баллы не сгорают',
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: AppConstants.buttonHeight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusLg),
                            ),
                          ),
                          onPressed: isLoading ? null : _onSave,
                          child: const Text(
                            'Сохранить',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
