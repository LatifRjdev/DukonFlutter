import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/zakat/zakat_bloc.dart';
import '../../blocs/zakat/zakat_event.dart';
import '../../blocs/zakat/zakat_state.dart';
import '../../widgets/common/app_snackbar.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

class ZakatSettingsPage extends StatefulWidget {
  final String storeId;
  const ZakatSettingsPage({super.key, required this.storeId});
  @override
  State<ZakatSettingsPage> createState() => _ZakatSettingsPageState();
}

class _ZakatSettingsPageState extends State<ZakatSettingsPage> {
  final _goldPriceController = TextEditingController();
  DateTime? _haulStartDate;
  String _nisabStandard = 'gold';
  bool _includeStock = true;
  bool _includeCash = true;
  bool _includeDebts = true;
  bool _includeSupplierDebts = true;
  bool _reminderEnabled = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    context.read<ZakatBloc>().add(ZakatSettingsRequested(storeId: widget.storeId));
  }

  @override
  void dispose() {
    _goldPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _haulStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _haulStartDate = picked);
    }
  }

  void _save() {
    final goldPrice = double.tryParse(_goldPriceController.text);
    final nisabAmount = _nisabStandard == 'gold' ? (goldPrice ?? 920) * 85 : (goldPrice ?? 920) * 595 / 85;

    context.read<ZakatBloc>().add(ZakatSettingsUpdated(
      storeId: widget.storeId,
      data: {
        'nisabAmount': nisabAmount,
        'zakatRate': 2.5,
        if (_haulStartDate != null) 'haulStartDate': _haulStartDate!.toIso8601String(),
        'includeStock': _includeStock,
        'includeCash': _includeCash,
        'includeDebts': _includeDebts,
      },
    ));
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
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.back,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                  const Text('Настройки закята',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            Expanded(
              child: BlocConsumer<ZakatBloc, ZakatState>(
                listener: (context, state) {
                  if (state is ZakatSettingsLoaded && !_initialized) {
                    _initialized = true;
                    final s = state.settings;
                    _goldPriceController.text = (s.nisabAmount / 85).toStringAsFixed(2);
                    _haulStartDate = s.haulStartDate;
                    _includeStock = s.includeStock;
                    _includeCash = s.includeCash;
                    _includeDebts = s.includeDebts;
                    setState(() {});
                  }
                  if (state is ZakatActionSuccess) {
                    AppSnackbar.success(context, state.message);
                    context.pop();
                  }
                  if (state is ZakatError) {
                    AppSnackbar.error(context, state.message);
                  }
                },
                builder: (context, state) {
                  if (state is ZakatLoading && !_initialized) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Method section
                      _buildSectionLabel('МЕТОД РАСЧЁТА'),
                      const SizedBox(height: 8),
                      RadioGroup<String>(
                        groupValue: _nisabStandard,
                        onChanged: (v) => setState(() => _nisabStandard = v!),
                        child: _buildCard([
                          const Padding(
                            padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
                            child: Text('Стандарт нисаба',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                          RadioListTile<String>(
                            title: Text('По золоту (85g)', style: TextStyle(fontSize: 14)),
                            subtitle: Text('~ 78,200 TJS', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                            value: 'gold',
                            activeColor: AppColors.primary,
                            dense: true,
                          ),
                          RadioListTile<String>(
                            title: Text('По серебру (595g)', style: TextStyle(fontSize: 14)),
                            subtitle: Text('~ 5,400 TJS', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                            value: 'silver',
                            activeColor: AppColors.primary,
                            dense: true,
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      _buildCard([
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Курс золота (за 1g)',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _goldPriceController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        suffixText: 'TJS',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                                ),
                                child: IconButton(
                                  tooltip: l10n.a11yRefresh,
                                  icon: const Icon(Icons.refresh, color: AppColors.primary, size: 20),
                                  onPressed: () {
                                    context.read<ZakatBloc>().add(ZakatSettingsRequested(storeId: widget.storeId));
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 20),

                      // Haul section
                      _buildSectionLabel('ЛУННЫЙ ГОД (ХАВЛЬ)'),
                      const SizedBox(height: 8),
                      _buildCard([
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                                  ),
                                  child: const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Дата начала хавля',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Text(
                                        _haulStartDate != null
                                            ? '${_haulStartDate!.day.toString().padLeft(2, '0')}.${_haulStartDate!.month.toString().padLeft(2, '0')}.${_haulStartDate!.year}'
                                            : 'Не выбрана',
                                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: context.textSecondary, size: 18),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 52, endIndent: 14),
                        Padding(
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
                                child: const Icon(Icons.notifications_outlined, color: AppColors.primary, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Напоминание',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    Text('За 30 дней до окончания хавля',
                                      style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _reminderEnabled,
                                onChanged: (v) => setState(() => _reminderEnabled = v),
                                activeThumbColor: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 20),

                      // Auto data section
                      _buildSectionLabel('АВТОМАТИЧЕСКИЕ ДАННЫЕ'),
                      const SizedBox(height: 8),
                      _buildCard([
                        _buildToggleRow('Товарные остатки магазина', 'Авто из каталога',
                          value: _includeStock,
                          onChanged: (v) => setState(() => _includeStock = v)),
                        const Divider(height: 1, indent: 14, endIndent: 14),
                        _buildToggleRow('Наличные в кассе', null,
                          value: _includeCash,
                          onChanged: (v) => setState(() => _includeCash = v)),
                        const Divider(height: 1, indent: 14, endIndent: 14),
                        _buildToggleRow('Дебиторская задолженность', 'Долги клиентов',
                          value: _includeDebts,
                          onChanged: (v) => setState(() => _includeDebts = v)),
                        const Divider(height: 1, indent: 14, endIndent: 14),
                        _buildToggleRow('Долги поставщикам (вычет)', 'Авто из модуля поставщиков',
                          value: _includeSupplierDebts,
                          onChanged: (v) => setState(() => _includeSupplierDebts = v)),
                      ]),
                      const SizedBox(height: 24),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: state is ZakatLoading ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
                          ),
                          child: Text(
                            state is ZakatLoading ? 'Сохранение...' : 'Сохранить',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
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
      style: TextStyle(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w600));
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleRow(String title, String? subtitle, {
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ],
            ),
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
