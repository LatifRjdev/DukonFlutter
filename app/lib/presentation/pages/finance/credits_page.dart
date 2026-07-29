import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/error_messages.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import '../../widgets/common/glass_card.dart';
import '../../../injection.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class _CreditItem {
  final String id;
  final String name;
  final String phone;
  final double debt;
  final String? lastPayment;
  const _CreditItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.debt,
    this.lastPayment,
  });

  factory _CreditItem.fromJson(Map<String, dynamic> j) => _CreditItem(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        debt: (j['debt'] as num?)?.toDouble() ?? 0,
        lastPayment: j['lastPayment'] as String?,
      );
}

class _CreditGroup {
  final double total;
  final int count;
  final List<_CreditItem> items;
  const _CreditGroup({required this.total, required this.count, required this.items});

  factory _CreditGroup.fromJson(Map<String, dynamic> j) => _CreditGroup(
        total: (j['total'] as num?)?.toDouble() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
        items: ((j['items'] as List?) ?? [])
            .map((e) => _CreditItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class _CreditsSummary {
  final _CreditGroup receivables;
  final _CreditGroup payables;
  const _CreditsSummary({required this.receivables, required this.payables});

  factory _CreditsSummary.fromJson(Map<String, dynamic> j) => _CreditsSummary(
        receivables: _CreditGroup.fromJson(j['receivables'] as Map<String, dynamic>? ?? {}),
        payables: _CreditGroup.fromJson(j['payables'] as Map<String, dynamic>? ?? {}),
      );
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class CreditsPage extends StatefulWidget {
  final String storeId;
  const CreditsPage({super.key, required this.storeId});

  @override
  State<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends State<CreditsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _CreditsSummary? _data;
  bool _loading = false;
  String? _error;

  String get _storeId {
    if (widget.storeId.isNotEmpty) return widget.storeId;
    final storeState = context.read<StoreBloc>().state;
    return storeState is StoreLoaded ? (storeState.selectedStore?.id ?? '') : '';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _storeId;
    if (id.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = sl<DioClient>();
      final response = await dio.get('/stores/$id/finances/credits-summary');
      final json = response.data as Map<String, dynamic>;
      setState(() {
        _data = _CreditsSummary.fromJson(json);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = mapErrorToUserMessage(e);
        _loading = false;
      });
    }
  }

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      return DateFormat('dd.MM.yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Кредиты'),
        backgroundColor: context.surface,
        foregroundColor: context.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Нам должны'),
            Tab(text: 'Мы должны'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _data == null
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTab(_data!.receivables, isReceivable: true),
                        _buildTab(_data!.payables, isReceivable: false),
                      ],
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: context.danger),
          const SizedBox(height: AppConstants.spacingMd),
          Text(_error!, style: TextStyle(color: context.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: AppConstants.spacingMd),
          TextButton(onPressed: _load, child: const Text('Повторить')),
        ],
      ),
    );
  }

  Widget _buildTab(_CreditGroup group, {required bool isReceivable}) {
    return RefreshIndicator(
      onRefresh: _load,
      child: group.items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.credit_card_off_outlined, size: 56, color: AppColors.disabled),
                      const SizedBox(height: AppConstants.spacingMd),
                      Text('Записей нет', style: TextStyle(color: context.textSecondary, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              children: [
                // Total summary card
                _buildTotalCard(group, isReceivable: isReceivable),
                const SizedBox(height: AppConstants.spacingMd),
                // Item cards
                for (final item in group.items) ...[
                  _CreditCard(
                    item: item,
                    isReceivable: isReceivable,
                    storeId: _storeId,
                    formatPrice: _formatPrice,
                    formatDate: _formatDate,
                    onPaymentDone: _load,
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                ],
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Widget _buildTotalCard(_CreditGroup group, {required bool isReceivable}) {
    final color = isReceivable ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isReceivable ? 'Общий долг нам' : 'Общий долг поставщикам',
                style: TextStyle(fontSize: 13, color: context.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                _formatPrice(group.total),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppConstants.radiusRound),
            ),
            child: Text(
              '${group.count} чел.',
              style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Credit card widget with expand + payment dialog
// ---------------------------------------------------------------------------

class _CreditCard extends StatefulWidget {
  final _CreditItem item;
  final bool isReceivable;
  final String storeId;
  final String Function(double) formatPrice;
  final String Function(String?) formatDate;
  final VoidCallback onPaymentDone;

  const _CreditCard({
    required this.item,
    required this.isReceivable,
    required this.storeId,
    required this.formatPrice,
    required this.formatDate,
    required this.onPaymentDone,
  });

  @override
  State<_CreditCard> createState() => _CreditCardState();
}

class _CreditCardState extends State<_CreditCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isReceivable ? AppColors.success : AppColors.error;
    final item = widget.item;

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                    style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.phone,
                        style: TextStyle(fontSize: 13, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      widget.formatPrice(item.debt),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'посл. ${widget.formatDate(item.lastPayment)}',
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: context.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(
                    widget.isReceivable ? Icons.payments_outlined : Icons.payment_outlined,
                    size: 18,
                  ),
                  label: Text(widget.isReceivable ? 'Принять платёж' : 'Внести платёж'),
                  onPressed: () => _showPaymentDialog(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showPaymentDialog(BuildContext context) async {
    final amountCtrl = TextEditingController();
    String selectedMethod = 'cash';
    bool submitting = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            ),
            title: Text(
              widget.isReceivable ? 'Принять платёж' : 'Внести платёж',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.name,
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: InputDecoration(
                    labelText: 'Сумма (TJS)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    ),
                    suffixText: 'TJS',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedMethod,
                  decoration: InputDecoration(
                    labelText: 'Метод оплаты',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Наличные')),
                    DropdownMenuItem(value: 'card', child: Text('Карта')),
                    DropdownMenuItem(value: 'transfer', child: Text('Перевод')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedMethod = v ?? 'cash'),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(dialogError!, style: TextStyle(color: context.danger, fontSize: 13)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                ),
                onPressed: submitting
                    ? null
                    : () async {
                        final raw = amountCtrl.text.trim();
                        final amount = double.tryParse(raw);
                        if (amount == null || amount <= 0) {
                          setDialogState(() => dialogError = 'Введите корректную сумму');
                          return;
                        }
                        setDialogState(() {
                          submitting = true;
                          dialogError = null;
                        });
                        try {
                          final dio = sl<DioClient>();
                          final endpoint = widget.isReceivable
                              ? '/stores/${widget.storeId}/customers/${widget.item.id}/payments'
                              : '/stores/${widget.storeId}/suppliers/${widget.item.id}/payments';
                          // E.3: attach a stable localId so a network
                          // retry of the same payment doesn't double-
                          // decrement the debt — the API now dedupes
                          // by localId and returns the existing row.
                          await dio.post(endpoint, data: {
                            'amount': amount,
                            'method': selectedMethod,
                            'localId': const Uuid().v4(),
                          });
                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                          widget.onPaymentDone();
                        } catch (e) {
                          setDialogState(() {
                            submitting = false;
                            dialogError = mapErrorToUserMessage(e);
                          });
                        }
                      },
                child: submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Подтвердить'),
              ),
            ],
          );
        },
      ),
    );
  }
}
