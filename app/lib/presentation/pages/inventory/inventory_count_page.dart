import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/error_messages.dart';
import '../../../injection.dart';
import '../../widgets/common/barcode_scanner_sheet.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class _CountProduct {
  final String id;
  final String name;
  final double expected;
  double actual;

  _CountProduct({
    required this.id,
    required this.name,
    required this.expected,
    required this.actual,
  });

  double get diff => actual - expected;

  factory _CountProduct.fromJson(Map<String, dynamic> j) {
    final expected = (j['expectedQty'] ?? j['quantity'] ?? 0 as num).toDouble();
    return _CountProduct(
      id: j['id'] as String? ?? j['productId'] as String? ?? '',
      name: j['name'] as String? ?? j['productName'] as String? ?? '',
      expected: expected,
      actual: expected,
    );
  }
}

// ─── Cubit ───────────────────────────────────────────────────────────────────

abstract class _InvState {}

class _InvInitial extends _InvState {}

class _InvLoading extends _InvState {}

class _InvCounting extends _InvState {
  final String countId;
  final List<_CountProduct> products;
  _InvCounting({required this.countId, required this.products});
}

class _InvSaving extends _InvState {
  final String countId;
  final List<_CountProduct> products;
  _InvSaving({required this.countId, required this.products});
}

class _InvDiff extends _InvState {
  final String countId;
  final List<_CountProduct> products;
  _InvDiff({required this.countId, required this.products});
}

class _InvApplying extends _InvState {
  final String countId;
  final List<_CountProduct> products;
  _InvApplying({required this.countId, required this.products});
}

class _InvDone extends _InvState {}

class _InvError extends _InvState {
  final String message;
  final _InvState? previous;
  _InvError(this.message, {this.previous});
}

class _InvCubit extends Cubit<_InvState> {
  final DioClient _client;
  final String storeId;

  _InvCubit(this._client, this.storeId) : super(_InvInitial());

  Future<void> start() async {
    emit(_InvLoading());
    try {
      final resp = await _client.post('/stores/$storeId/inventory-counts');
      final data = resp.data as Map<String, dynamic>;
      final countId = data['id'] as String;

      // Fetch products for this count
      final detailResp =
          await _client.get('/stores/$storeId/inventory-counts/$countId');
      final detail = detailResp.data as Map<String, dynamic>;
      final rawItems = (detail['items'] as List?) ?? [];
      final products =
          rawItems.map((e) => _CountProduct.fromJson(e as Map<String, dynamic>)).toList();

      emit(_InvCounting(countId: countId, products: products));
    } catch (e) {
      emit(_InvError(mapErrorToUserMessage(e), previous: _InvInitial()));
    }
  }

  Future<void> save(String countId, List<_CountProduct> products) async {
    emit(_InvSaving(countId: countId, products: products));
    try {
      await _client.put(
        '/stores/$storeId/inventory-counts/$countId',
        data: {
          'items': products
              .map((p) => {'productId': p.id, 'actualQty': p.actual})
              .toList(),
        },
      );
      emit(_InvDiff(countId: countId, products: products));
    } catch (e) {
      emit(_InvError(mapErrorToUserMessage(e),
          previous: _InvCounting(countId: countId, products: products)));
    }
  }

  Future<void> apply(String countId, List<_CountProduct> products) async {
    emit(_InvApplying(countId: countId, products: products));
    try {
      await _client.post('/stores/$storeId/inventory-counts/$countId/apply');
      emit(_InvDone());
    } catch (e) {
      emit(_InvError(mapErrorToUserMessage(e),
          previous: _InvDiff(countId: countId, products: products)));
    }
  }

  void retry(_InvState? prev) {
    if (prev != null) emit(prev);
  }
}

// ─── Page ────────────────────────────────────────────────────────────────────

class InventoryCountPage extends StatelessWidget {
  final String storeId;

  const InventoryCountPage({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _InvCubit(sl<DioClient>(), storeId),
      child: const _InventoryView(),
    );
  }
}

class _InventoryView extends StatelessWidget {
  const _InventoryView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<_InvCubit, _InvState>(
      listener: (context, state) {
        if (state is _InvError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        Widget body;
        String title;

        if (state is _InvInitial || state is _InvLoading) {
          title = l10n.inventoryTitle;
          body = _StartScreen(isLoading: state is _InvLoading);
        } else if (state is _InvCounting || state is _InvSaving) {
          title = l10n.inventoryCountingTitle;
          final countId =
              state is _InvCounting ? state.countId : (state as _InvSaving).countId;
          final products =
              state is _InvCounting ? state.products : (state as _InvSaving).products;
          body = _CountScreen(
            countId: countId,
            products: products,
            isSaving: state is _InvSaving,
          );
        } else if (state is _InvDiff || state is _InvApplying) {
          title = l10n.inventoryResultsTitle;
          final countId =
              state is _InvDiff ? state.countId : (state as _InvApplying).countId;
          final products =
              state is _InvDiff ? state.products : (state as _InvApplying).products;
          body = _DiffScreen(
            countId: countId,
            products: products,
            isApplying: state is _InvApplying,
          );
        } else if (state is _InvDone) {
          title = l10n.done;
          body = const _DoneScreen();
        } else if (state is _InvError) {
          title = l10n.error;
          body = Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.message, style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.read<_InvCubit>().retry(state.previous),
                  child: Text(l10n.back),
                ),
              ],
            ),
          );
        } else {
          title = l10n.inventoryTitle;
          body = const SizedBox.shrink();
        }

        return Scaffold(
          backgroundColor: context.bg,
          appBar: AppBar(
            title: Text(title,
                style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
            backgroundColor: Colors.white,
            foregroundColor: context.textPrimary,
            elevation: 0,
          ),
          body: body,
        );
      },
    );
  }
}

// ─── Step 1: Start ────────────────────────────────────────────────────────────

class _StartScreen extends StatelessWidget {
  final bool isLoading;
  const _StartScreen({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              l10n.inventoryTitle,
              style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              l10n.inventoryCountIntro,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: context.textSecondary),
            ),
            const SizedBox(height: AppConstants.spacingXl),
            SizedBox(
              width: double.infinity,
              height: AppConstants.buttonHeight,
              child: ElevatedButton(
                onPressed:
                    isLoading ? null : () => context.read<_InvCubit>().start(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLg)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onPrimary))
                    : Text(
                        l10n.inventoryCountStart,
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 2: Count ────────────────────────────────────────────────────────────

class _CountScreen extends StatefulWidget {
  final String countId;
  final List<_CountProduct> products;
  final bool isSaving;

  const _CountScreen({
    required this.countId,
    required this.products,
    required this.isSaving,
  });

  @override
  State<_CountScreen> createState() => _CountScreenState();
}

class _CountScreenState extends State<_CountScreen> {
  late final List<TextEditingController> _controllers;
  final _scrollCtrl = ScrollController();
  @override
  void initState() {
    super.initState();
    _controllers = widget.products
        .map((p) => TextEditingController(text: p.actual.toStringAsFixed(0)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onBarcodeScanned(String barcode, AppLocalizations l10n) {
    final idx = widget.products.indexWhere((p) => p.id == barcode || p.name == barcode);
    if (idx == -1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.productNotFound)));
      return;
    }
    _scrollCtrl.animateTo(
      idx * 72.0,
      duration: AppConstants.animationNormal,
      curve: Curves.easeInOut,
    );
    _controllers[idx].selection = TextSelection(
        baseOffset: 0, extentOffset: _controllers[idx].text.length);
  }

  void _save() {
    for (int i = 0; i < widget.products.length; i++) {
      widget.products[i].actual =
          double.tryParse(_controllers[i].text) ?? widget.products[i].expected;
    }
    context.read<_InvCubit>().save(widget.countId, widget.products);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = NumberFormat('#,##0.##', 'ru');

    return Column(
      children: [
        // Scan bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd, vertical: AppConstants.spacingSm),
          child: Row(
            children: [
              Expanded(
                child: Text(l10n.inventoryCountEditHint,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: context.textSecondary)),
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                tooltip: l10n.scanBarcode,
                onPressed: () => BarcodeScannerSheet.show(context,
                    onScanned: (code) => _onBarcodeScanned(code, l10n)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Product list
        Expanded(
          child: ListView.separated(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            itemCount: widget.products.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppConstants.spacingXs),
            itemBuilder: (ctx, i) {
              final product = widget.products[i];
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingMd, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name,
                              style: const TextStyle(
                                  fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(l10n.inventoryExpectedLine(fmt.format(product.expected)),
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: context.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: _controllers[i],
                        enabled: !widget.isSaving,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: 'Inter', fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusSm),
                            borderSide:
                                BorderSide(color: context.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusSm),
                            borderSide:
                                BorderSide(color: context.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusSm),
                            borderSide:
                                const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Save button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: SizedBox(
              width: double.infinity,
              height: AppConstants.buttonHeight,
              child: ElevatedButton(
                onPressed: widget.isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLg)),
                ),
                child: widget.isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onPrimary))
                    : Text(l10n.save,
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 16)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Step 3: Diff ─────────────────────────────────────────────────────────────

class _DiffScreen extends StatelessWidget {
  final String countId;
  final List<_CountProduct> products;
  final bool isApplying;

  const _DiffScreen({
    required this.countId,
    required this.products,
    required this.isApplying,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = NumberFormat('#,##0.##', 'ru');

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingMd, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.surfaceMuted,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(AppConstants.radiusLg),
                        topRight: Radius.circular(AppConstants.radiusLg),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(l10n.product,
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: context.textSecondary)),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(l10n.inventoryExpectedColumn,
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: context.textSecondary),
                              textAlign: TextAlign.center),
                        ),
                        SizedBox(
                          width: 50,
                          child: Text(l10n.inventoryActualColumn,
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: context.textSecondary),
                              textAlign: TextAlign.center),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(l10n.difference,
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: context.textSecondary),
                              textAlign: TextAlign.center),
                        ),
                      ],
                    ),
                  ),

                  // Rows
                  for (int i = 0; i < products.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                    _DiffRow(product: products[i], fmt: fmt),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Apply button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: SizedBox(
              width: double.infinity,
              height: AppConstants.buttonHeight,
              child: ElevatedButton(
                onPressed: isApplying
                    ? null
                    : () =>
                        context.read<_InvCubit>().apply(countId, products),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLg)),
                ),
                child: isApplying
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onPrimary))
                    : Text(l10n.apply,
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 16)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DiffRow extends StatelessWidget {
  final _CountProduct product;
  final NumberFormat fmt;

  const _DiffRow({required this.product, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final diff = product.diff;
    Color diffColor;
    if (diff < 0) {
      diffColor = AppColors.error;
    } else if (diff > 0) {
      diffColor = AppColors.warning;
    } else {
      diffColor = context.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(product.name,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 60,
            child: Text(fmt.format(product.expected),
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: context.textSecondary),
                textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 50,
            child: Text(fmt.format(product.actual),
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '${diff >= 0 ? '+' : ''}${fmt.format(diff)}',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: diffColor),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 4: Done ─────────────────────────────────────────────────────────────

class _DoneScreen extends StatelessWidget {
  const _DoneScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  size: 56, color: AppColors.success),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              l10n.inventoryCountCompleted,
              style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              l10n.inventoryCountUpdated,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingXl),
            SizedBox(
              width: double.infinity,
              height: AppConstants.buttonHeight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLg)),
                ),
                child: Text(l10n.done,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
