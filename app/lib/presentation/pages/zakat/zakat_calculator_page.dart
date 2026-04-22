import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/zakat/zakat_bloc.dart';
import '../../blocs/zakat/zakat_event.dart';
import '../../blocs/zakat/zakat_state.dart';
import '../../widgets/common/app_snackbar.dart';
import 'package:dokonpro/l10n/app_localizations.dart';

class ZakatCalculatorPage extends StatefulWidget {
  final String storeId;
  const ZakatCalculatorPage({super.key, required this.storeId});
  @override
  State<ZakatCalculatorPage> createState() => _ZakatCalculatorPageState();
}

class _ZakatCalculatorPageState extends State<ZakatCalculatorPage> {
  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  @override
  void initState() {
    super.initState();
    context.read<ZakatBloc>().add(ZakatCalculateRequested(storeId: widget.storeId));
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
                  IconButton(
                    tooltip: l10n.back,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                  Text('Калькулятор закята',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.zakatSettings,
                    icon: Icon(Icons.settings_outlined, color: context.textSecondary),
                    onPressed: () => context.push('/zakat/settings', extra: widget.storeId),
                  ),
                  IconButton(
                    tooltip: l10n.a11yCalculationHistory,
                    icon: Icon(Icons.list_alt_outlined, color: context.textSecondary),
                    onPressed: () => context.push('/zakat/history', extra: widget.storeId),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: BlocConsumer<ZakatBloc, ZakatState>(
                listener: (context, state) {
                  if (state is ZakatActionSuccess) {
                    AppSnackbar.success(context, state.message);
                    context.read<ZakatBloc>().add(ZakatCalculateRequested(storeId: widget.storeId));
                  }
                  if (state is ZakatError) {
                    AppSnackbar.error(context, state.message);
                  }
                },
                builder: (context, state) {
                  if (state is ZakatLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is ZakatCalculated) {
                    final calc = state.calculation;
                    final totalAssets = calc.stockValue + calc.receivables;

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Info banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.infoBg,
                            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                            border: Border(left: BorderSide(color: AppColors.info, width: 3)),
                          ),
                          child: const Text(
                            'Закят — 2.5% от имущества, хранящегося 1 лунный год',
                            style: TextStyle(fontSize: 12, color: AppColors.info),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Assets section
                        Row(
                          children: [
                            Text('АКТИВЫ МАГАЗИНА',
                              style: TextStyle(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text(_formatPrice(totalAssets),
                              style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Stock value card
                        _buildAssetCard(
                          icon: Icons.inventory_2_outlined,
                          title: 'Товарные остатки',
                          amount: calc.stockValue,
                          subtitle: 'Автоматически из каталога',
                          badge: 'Авто',
                        ),
                        const SizedBox(height: 8),

                        // Receivables card
                        _buildAssetCard(
                          icon: Icons.people_outlined,
                          title: 'Дебиторская задолженность',
                          amount: calc.receivables,
                          subtitle: 'Долги клиентов',
                          badge: 'Авто',
                        ),
                        const SizedBox(height: 20),

                        // Deductions section
                        Row(
                          children: [
                            Text('ВЫЧЕТЫ',
                              style: TextStyle(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text('-${_formatPrice(calc.payables)}',
                              style: const TextStyle(fontSize: 14, color: AppColors.error, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),

                        _buildAssetCard(
                          icon: Icons.remove_circle_outline,
                          iconColor: AppColors.error,
                          title: 'Долги поставщикам',
                          amount: calc.payables,
                          amountColor: AppColors.error,
                          amountPrefix: '-',
                          subtitle: 'Автоматически из модуля',
                          badge: 'Авто',
                        ),
                        const SizedBox(height: 20),

                        // Dashed divider
                        CustomPaint(
                          painter: _DashedLinePainter(context.border),
                          size: const Size(double.infinity, 1),
                        ),
                        const SizedBox(height: 16),

                        // Totals card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.surface,
                            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Облагаемая сумма:',
                                    style: TextStyle(fontSize: 14, color: context.textSecondary)),
                                  Text(_formatPrice(calc.netAssets),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Нисаб (85г золота):',
                                    style: TextStyle(fontSize: 14, color: context.textSecondary)),
                                  Row(
                                    children: [
                                      Text(_formatPrice(calc.nisabAmount),
                                        style: const TextStyle(fontSize: 14)),
                                      if (calc.isAboveNisab) ...[
                                        const SizedBox(width: 6),
                                        const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                                        const SizedBox(width: 2),
                                        const Text('Превышен',
                                          style: TextStyle(fontSize: 12, color: AppColors.success)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('СУММА ЗАКЯТА (2.5%):',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                  Text(_formatPrice(calc.zakatDue),
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        if (!calc.isAboveNisab) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.warningBg,
                              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text('Активы ниже нисаба. Закят не обязателен.',
                                    style: TextStyle(fontSize: 13, color: AppColors.warning)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Pay button
                        if (calc.isAboveNisab && calc.zakatDue > 0)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                context.read<ZakatBloc>().add(ZakatPaymentSubmitted(
                                  storeId: widget.storeId,
                                  data: {
                                    'amount': calc.zakatDue,
                                    'totalAssets': calc.netAssets,
                                    'zakatDue': calc.zakatDue,
                                    'paidAt': DateTime.now().toIso8601String(),
                                  },
                                ));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
                              ),
                              child: const Text('Отметить как оплачено',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Share button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final state = context.read<ZakatBloc>().state;
                              if (state is ZakatCalculated) {
                                final c = state.calculation;
                                final text = 'Закят: ${c.zakatDue.toStringAsFixed(2)} сом.\n'
                                    'Нисаб: ${c.nisabAmount.toStringAsFixed(2)} сом.\n'
                                    'Чистые активы: ${c.netAssets.toStringAsFixed(2)} сом.';
                                Clipboard.setData(ClipboardData(text: text));
                                AppSnackbar.info(context, 'Расчёт скопирован');
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
                            ),
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: const Text('Поделиться расчётом',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(height: 16),
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

  Widget _buildAssetCard({
    required IconData icon,
    required String title,
    required double amount,
    String? subtitle,
    String? badge,
    Color? iconColor,
    Color? amountColor,
    String amountPrefix = '',
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Icon(icon, color: iconColor ?? AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        ),
                        child: Text(badge,
                          style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: context.textSecondary)),
                ],
              ],
            ),
          ),
          Text('$amountPrefix${_formatPrice(amount)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: amountColor)),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
