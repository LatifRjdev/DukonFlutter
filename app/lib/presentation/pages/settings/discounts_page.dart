import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/error_messages.dart';
import '../../l10n/app_message_l10n.dart';
import '../../../injection.dart';
import '../../widgets/common/app_snackbar.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

class DiscountsPage extends StatefulWidget {
  final String storeId;
  const DiscountsPage({super.key, required this.storeId});

  @override
  State<DiscountsPage> createState() => _DiscountsPageState();
}

class _DiscountsPageState extends State<DiscountsPage> {
  final _dioClient = sl<DioClient>();
  List<Map<String, dynamic>> _discounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _dioClient.get('/stores/${widget.storeId}/discounts');
      final data = res.data;
      if (data is List) {
        setState(() => _discounts = List<Map<String, dynamic>>.from(data));
      } else if (data is Map && data['data'] is List) {
        setState(() => _discounts = List<Map<String, dynamic>>.from(data['data'] as List));
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _error = mapErrorToAppMessage(e).resolve(l10n));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(String id, bool current) async {
    try {
      await _dioClient.put('/stores/${widget.storeId}/discounts/$id',
          data: {'isActive': !current});
      await _load();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppSnackbar.error(context, mapErrorToAppMessage(e).resolve(l10n));
      }
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _dioClient.delete('/stores/${widget.storeId}/discounts/$id');
      await _load();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppSnackbar.error(context, mapErrorToAppMessage(e).resolve(l10n));
      }
    }
  }

  // Matches the confirmation-dialog shape already used for category
  // deletion (categories_page.dart) and product deletion
  // (product_detail_page.dart): title, body, "Отмена"/destructive-action
  // button pair (SPEC.md #31).
  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.discountsDeleteTitle),
        content: Text(AppLocalizations.of(ctx)!.deleteConfirmBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _delete(id);
            },
            child: Text(AppLocalizations.of(ctx)!.delete, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showForm({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final valueCtrl = TextEditingController(
        text: existing?['value']?.toString() ?? '');
    final conditionCtrl = TextEditingController(
        text: existing?['condition']?.toString() ?? '');
    String type = existing?['type'] ?? 'percent';
    final isEdit = existing != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: context.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(isEdit ? AppLocalizations.of(context)!.discountsEditTitle : AppLocalizations.of(context)!.discountsNewTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.itemName, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'percent', label: Text(AppLocalizations.of(context)!.discountsTypePercent)),
                        ButtonSegment(value: 'fixed', label: Text(AppLocalizations.of(context)!.discountsTypeFixed)),
                      ],
                      selected: {type},
                      onSelectionChanged: (s) => setLocal(() => type = s.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: type == 'percent' ? AppLocalizations.of(context)!.discountsValuePercentLabel : AppLocalizations.of(context)!.discountsValueFixedLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: conditionCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.discountsMinOrderLabel,
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: AppConstants.buttonHeight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _save(
                      id: existing?['id'] as String?,
                      name: nameCtrl.text.trim(),
                      type: type,
                      value: double.tryParse(valueCtrl.text) ?? 0,
                      minTotal: double.tryParse(conditionCtrl.text),
                    );
                  },
                  child: Text(isEdit ? AppLocalizations.of(context)!.save : AppLocalizations.of(context)!.create,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save({
    String? id,
    required String name,
    required String type,
    required double value,
    double? minTotal,
  }) async {
    try {
      final payload = {
        'name': name,
        'type': type == 'percent' ? 'PERCENTAGE' : 'FIXED',
        'value': value,
        'condition': 'CART',
        'startDate': DateTime.now().toUtc().toIso8601String(),
        'minTotal': ?minTotal,
      };
      if (id != null) {
        await _dioClient.put('/stores/${widget.storeId}/discounts/$id', data: payload);
      } else {
        await _dioClient.post('/stores/${widget.storeId}/discounts', data: payload);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppSnackbar.error(context, mapErrorToAppMessage(e).resolve(l10n));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: Text(l10n.discountsPageTitle),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: Text(l10n.retry)),
                    ],
                  ),
                )
              : _discounts.isEmpty
                  ? Center(
                      child: Text(l10n.discountsEmptyState,
                          style: TextStyle(color: context.textSecondary)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _discounts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final d = _discounts[index];
                        final id = d['id'] as String? ?? '';
                        final name = d['name'] as String? ?? '';
                        final type = d['type'] as String? ?? 'percent';
                        final value = d['value'];
                        final isActive = d['isActive'] as bool? ?? true;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusLg),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: type == 'percent'
                                      ? AppColors.primary.withValues(alpha: 0.12)
                                      : AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                ),
                                child: Text(
                                  type == 'percent'
                                      ? '${value ?? 0}%'
                                      : '${value ?? 0} TJS',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: type == 'percent'
                                        ? AppColors.primary
                                        : AppColors.success,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(name,
                                    style: const TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w500)),
                              ),
                              Switch(
                                value: isActive,
                                onChanged: (v) => _toggleActive(id, isActive),
                                activeThumbColor: AppColors.primary,
                              ),
                              IconButton(
                                tooltip: l10n.a11yEditDiscount,
                                icon: Icon(Icons.edit_outlined,
                                    size: 18, color: context.textSecondary),
                                onPressed: () => _showForm(existing: d),
                              ),
                              IconButton(
                                tooltip: l10n.a11yDeleteDiscount,
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: AppColors.error),
                                onPressed: () => _confirmDelete(id, name),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
