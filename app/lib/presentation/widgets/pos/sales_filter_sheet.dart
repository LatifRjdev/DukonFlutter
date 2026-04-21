import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum SalesFilterPeriod { today, week, month, custom }

enum SalesFilterPayment { all, cash, card, debt }

enum SalesFilterStatus { all, completed, returned, cancelled }

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class SalesFilter {
  final SalesFilterPeriod period;
  final SalesFilterPayment payment;
  final SalesFilterStatus status;
  final DateTime? from;
  final DateTime? to;

  const SalesFilter({
    this.period = SalesFilterPeriod.today,
    this.payment = SalesFilterPayment.all,
    this.status = SalesFilterStatus.all,
    this.from,
    this.to,
  });

  SalesFilter copyWith({
    SalesFilterPeriod? period,
    SalesFilterPayment? payment,
    SalesFilterStatus? status,
    DateTime? from,
    DateTime? to,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return SalesFilter(
      period: period ?? this.period,
      payment: payment ?? this.payment,
      status: status ?? this.status,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }

  /// Convert period enum to date range [from, to] relative to now.
  static (DateTime? from, DateTime? to) periodToDates(SalesFilterPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case SalesFilterPeriod.today:
        final start = DateTime(now.year, now.month, now.day);
        return (start, now);
      case SalesFilterPeriod.week:
        return (now.subtract(const Duration(days: 7)), now);
      case SalesFilterPeriod.month:
        return (now.subtract(const Duration(days: 30)), now);
      case SalesFilterPeriod.custom:
        return (null, null);
    }
  }

  /// Convert payment enum to API string (null means "all").
  String? get paymentTypeValue {
    switch (payment) {
      case SalesFilterPayment.all:
        return null;
      case SalesFilterPayment.cash:
        return 'CASH';
      case SalesFilterPayment.card:
        return 'CARD';
      case SalesFilterPayment.debt:
        return 'DEBT';
    }
  }
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class SalesFilterSheet extends StatefulWidget {
  final ValueChanged<SalesFilter> onApply;
  final SalesFilter? initial;

  const SalesFilterSheet({
    super.key,
    required this.onApply,
    this.initial,
  });

  /// Open the filter sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required ValueChanged<SalesFilter> onApply,
    SalesFilter? initial,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SalesFilterSheet(
        onApply: onApply,
        initial: initial,
      ),
    );
  }

  @override
  State<SalesFilterSheet> createState() => _SalesFilterSheetState();
}

class _SalesFilterSheetState extends State<SalesFilterSheet> {
  late SalesFilterPeriod _period;
  late SalesFilterPayment _payment;
  late SalesFilterStatus _status;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _period = init?.period ?? SalesFilterPeriod.today;
    _payment = init?.payment ?? SalesFilterPayment.all;
    _status = init?.status ?? SalesFilterStatus.all;
    _from = init?.from;
    _to = init?.to;
  }

  void _reset() {
    setState(() {
      _period = SalesFilterPeriod.today;
      _payment = SalesFilterPayment.all;
      _status = SalesFilterStatus.all;
      _from = null;
      _to = null;
    });
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (range != null) {
      setState(() {
        _from = range.start;
        _to = range.end;
      });
    }
  }

  void _apply() {
    DateTime? from = _from;
    DateTime? to = _to;

    if (_period != SalesFilterPeriod.custom) {
      final dates = SalesFilter.periodToDates(_period);
      from = dates.$1;
      to = dates.$2;
    }

    widget.onApply(
      SalesFilter(
        period: _period,
        payment: _payment,
        status: _status,
        from: from,
        to: to,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXxl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: AppConstants.spacingSm),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Title row
          Padding(
            padding: const EdgeInsets.only(
              left: AppConstants.spacingMd,
              right: AppConstants.spacingXs,
              top: AppConstants.spacingSm,
              bottom: AppConstants.spacingXs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Фильтры',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      color: context.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  child: const Text(
                    'Сбросить',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.textSecondary,
                  ),
                  splashRadius: 20,
                  tooltip: 'Пӯшидан',
                ),
              ],
            ),
          ),

          Divider(height: 1, color: context.border),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingMd,
                AppConstants.spacingMd,
                AppConstants.spacingMd,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Period section ---
                  _SectionLabel(label: 'Период'),
                  const SizedBox(height: AppConstants.spacingSm),
                  Wrap(
                    spacing: AppConstants.spacingSm,
                    runSpacing: AppConstants.spacingSm,
                    children: [
                      _FilterChip(
                        label: 'Сегодня',
                        isSelected: _period == SalesFilterPeriod.today,
                        onTap: () => setState(() {
                          _period = SalesFilterPeriod.today;
                          _from = null;
                          _to = null;
                        }),
                      ),
                      _FilterChip(
                        label: 'Неделя',
                        isSelected: _period == SalesFilterPeriod.week,
                        onTap: () => setState(() {
                          _period = SalesFilterPeriod.week;
                          _from = null;
                          _to = null;
                        }),
                      ),
                      _FilterChip(
                        label: 'Месяц',
                        isSelected: _period == SalesFilterPeriod.month,
                        onTap: () => setState(() {
                          _period = SalesFilterPeriod.month;
                          _from = null;
                          _to = null;
                        }),
                      ),
                      _FilterChip(
                        label: 'Выбрать даты',
                        isSelected: _period == SalesFilterPeriod.custom,
                        onTap: () async {
                          setState(() => _period = SalesFilterPeriod.custom);
                          await _pickCustomRange();
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: AppConstants.spacingMd),

                  // --- Payment type section ---
                  _SectionLabel(label: 'Тип оплаты'),
                  const SizedBox(height: AppConstants.spacingSm),
                  Wrap(
                    spacing: AppConstants.spacingSm,
                    runSpacing: AppConstants.spacingSm,
                    children: [
                      _FilterChip(
                        label: 'Все',
                        isSelected: _payment == SalesFilterPayment.all,
                        onTap: () => setState(() => _payment = SalesFilterPayment.all),
                      ),
                      _FilterChip(
                        label: 'Наличные',
                        isSelected: _payment == SalesFilterPayment.cash,
                        onTap: () => setState(() => _payment = SalesFilterPayment.cash),
                      ),
                      _FilterChip(
                        label: 'Карта',
                        isSelected: _payment == SalesFilterPayment.card,
                        onTap: () => setState(() => _payment = SalesFilterPayment.card),
                      ),
                      _FilterChip(
                        label: 'Долг',
                        isSelected: _payment == SalesFilterPayment.debt,
                        onTap: () => setState(() => _payment = SalesFilterPayment.debt),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppConstants.spacingMd),

                  // --- Status section ---
                  _SectionLabel(label: 'Статус'),
                  const SizedBox(height: AppConstants.spacingSm),
                  Wrap(
                    spacing: AppConstants.spacingSm,
                    runSpacing: AppConstants.spacingSm,
                    children: [
                      _FilterChip(
                        label: 'Все',
                        isSelected: _status == SalesFilterStatus.all,
                        onTap: () => setState(() => _status = SalesFilterStatus.all),
                      ),
                      _FilterChip(
                        label: 'Выполнен',
                        isSelected: _status == SalesFilterStatus.completed,
                        onTap: () => setState(() => _status = SalesFilterStatus.completed),
                      ),
                      _FilterChip(
                        label: 'Возврат',
                        isSelected: _status == SalesFilterStatus.returned,
                        onTap: () => setState(() => _status = SalesFilterStatus.returned),
                      ),
                      _FilterChip(
                        label: 'Отменён',
                        isSelected: _status == SalesFilterStatus.cancelled,
                        onTap: () => setState(() => _status = SalesFilterStatus.cancelled),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppConstants.spacingLg),
                ],
              ),
            ),
          ),

          // Apply button
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppConstants.spacingMd,
              AppConstants.spacingSm,
              AppConstants.spacingMd,
              AppConstants.spacingMd + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: AppConstants.buttonHeight,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Применить',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animationFast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
