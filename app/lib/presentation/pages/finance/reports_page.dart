import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../injection.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models (local to this file)
// ─────────────────────────────────────────────────────────────────────────────

class _SalesRow {
  final String date;
  final int count;
  final double revenue;
  final double avgCheck;
  const _SalesRow({
    required this.date,
    required this.count,
    required this.revenue,
    required this.avgCheck,
  });
  factory _SalesRow.fromJson(Map<String, dynamic> j) => _SalesRow(
        date: j['date'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
        revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
        avgCheck: (j['avgCheck'] as num?)?.toDouble() ?? 0,
      );
}

class _TopProduct {
  final String name;
  final double revenue;
  const _TopProduct({required this.name, required this.revenue});
  factory _TopProduct.fromJson(Map<String, dynamic> j) => _TopProduct(
        name: j['name'] as String? ?? '',
        revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
      );
}

class _SalesData {
  final List<_SalesRow> rows;
  final List<_TopProduct> top5;
  const _SalesData({required this.rows, required this.top5});
}

class _ExpenseCategory {
  final String name;
  final double total;
  const _ExpenseCategory({required this.name, required this.total});
}

class _ProfitMonthItem {
  final String month;
  final double income;
  final double expenses;
  const _ProfitMonthItem({
    required this.month,
    required this.income,
    required this.expenses,
  });
  factory _ProfitMonthItem.fromJson(Map<String, dynamic> j) => _ProfitMonthItem(
        month: j['month'] as String? ?? '',
        income: (j['income'] as num?)?.toDouble() ?? 0,
        expenses: (j['expenses'] as num?)?.toDouble() ?? 0,
      );
}

class _ProfitData {
  final double totalIncome;
  final double totalExpenses;
  final double netProfit;
  final double margin;
  final List<_ProfitMonthItem> monthly;
  const _ProfitData({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netProfit,
    required this.margin,
    required this.monthly,
  });
}

class _ProductItem {
  final String name;
  final int qty;
  final double revenue;
  final bool isDead;
  const _ProductItem({
    required this.name,
    required this.qty,
    required this.revenue,
    required this.isDead,
  });
  factory _ProductItem.fromJson(Map<String, dynamic> j, {bool dead = false}) =>
      _ProductItem(
        name: j['name'] as String? ?? '',
        qty: (j['qty'] as num?)?.toInt() ?? 0,
        revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
        isDead: dead,
      );
}

class _ProductsData {
  final List<_ProductItem> topSellers;
  final List<_ProductItem> deadStock;
  final double stockValue;
  const _ProductsData({
    required this.topSellers,
    required this.deadStock,
    required this.stockValue,
  });
}

class _StaffRow {
  final String name;
  final int salesCount;
  final double totalRevenue;
  final double avgCheck;
  const _StaffRow({
    required this.name,
    required this.salesCount,
    required this.totalRevenue,
    required this.avgCheck,
  });
  factory _StaffRow.fromJson(Map<String, dynamic> j) => _StaffRow(
        name: j['name'] as String? ?? '',
        salesCount: (j['salesCount'] as num?)?.toInt() ?? 0,
        totalRevenue: (j['totalRevenue'] as num?)?.toDouble() ?? 0,
        avgCheck: (j['avgCheck'] as num?)?.toDouble() ?? 0,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Page
// ─────────────────────────────────────────────────────────────────────────────

class ReportsPage extends StatefulWidget {
  final String? storeId;
  const ReportsPage({super.key, this.storeId});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final DioClient _dio = sl<DioClient>();

  late DateTime _from;
  late DateTime _to;

  // Per-tab state
  bool _salesLoading = false;
  bool _expensesLoading = false;
  bool _profitLoading = false;
  bool _productsLoading = false;
  bool _staffLoading = false;

  String? _salesError;
  String? _expensesError;
  String? _profitError;
  String? _productsError;
  String? _staffError;

  _SalesData? _salesData;
  List<_ExpenseCategory> _expenseCategories = [];
  _ProfitData? _profitData;
  _ProductsData? _productsData;
  List<_StaffRow> _staffRows = [];

  String? get _storeId {
    if (widget.storeId != null && widget.storeId!.isNotEmpty) {
      return widget.storeId;
    }
    final s = context.read<StoreBloc>().state;
    return s is StoreLoaded ? s.selectedStore?.id : null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);

    final now = DateTime.now();
    _from = DateTime(now.year, now.month - 1, now.day);
    _to = now;

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentTab());
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) _loadCurrentTab();
  }

  void _loadCurrentTab() {
    switch (_tabController.index) {
      case 0:
        _loadSales();
      case 1:
        _loadExpenses();
      case 2:
        _loadProfit();
      case 3:
        _loadProducts();
      case 4:
        _loadStaff();
    }
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _fmtPrice(double v) =>
      '${NumberFormat('#,##0', 'ru').format(v)} TJS';
  String _fmtDate(DateTime d) => DateFormat('dd.MM.yyyy').format(d);

  // ── Fetch helpers ──────────────────────────────────────────────────────────

  Future<void> _loadSales() async {
    final id = _storeId;
    if (id == null) return;
    setState(() {
      _salesLoading = true;
      _salesError = null;
    });
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/stores/$id/reports/sales',
        queryParameters: {'from': _fmt(_from), 'to': _fmt(_to)},
      );
      final body = resp.data ?? {};
      final rowsJson = (body['rows'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final topJson = (body['top5'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() {
        _salesData = _SalesData(
          rows: rowsJson.map(_SalesRow.fromJson).toList(),
          top5: topJson.map(_TopProduct.fromJson).toList(),
        );
      });
    } catch (e) {
      setState(() => _salesError = _errMsg(e));
    } finally {
      setState(() => _salesLoading = false);
    }
  }

  Future<void> _loadExpenses() async {
    final id = _storeId;
    if (id == null) return;
    setState(() {
      _expensesLoading = true;
      _expensesError = null;
    });
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.expenses(id),
        queryParameters: {
          'startDate': _fmt(_from),
          'endDate': _fmt(_to),
          'limit': '200',
        },
      );
      final body = resp.data ?? {};
      final items =
          (body['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final grouped = <String, double>{};
      for (final item in items) {
        final cat = item['category'] as String? ?? 'OTHER';
        final amount = (item['amount'] as num?)?.toDouble() ?? 0;
        grouped[cat] = (grouped[cat] ?? 0) + amount;
      }
      final cats = grouped.entries
          .map((e) => _ExpenseCategory(name: _catLabel(e.key), total: e.value))
          .toList()
        ..sort((a, b) => b.total.compareTo(a.total));
      setState(() => _expenseCategories = cats);
    } catch (e) {
      setState(() => _expensesError = _errMsg(e));
    } finally {
      setState(() => _expensesLoading = false);
    }
  }

  Future<void> _loadProfit() async {
    final id = _storeId;
    if (id == null) return;
    setState(() {
      _profitLoading = true;
      _profitError = null;
    });
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/stores/$id/reports/profit',
        queryParameters: {'from': _fmt(_from), 'to': _fmt(_to)},
      );
      final body = resp.data ?? {};
      final monthlyJson =
          (body['monthly'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final income = (body['totalIncome'] as num?)?.toDouble() ?? 0;
      final expenses = (body['totalExpenses'] as num?)?.toDouble() ?? 0;
      final net = income - expenses;
      final margin = income > 0 ? (net / income) * 100 : 0.0;
      setState(() {
        _profitData = _ProfitData(
          totalIncome: income,
          totalExpenses: expenses,
          netProfit: net,
          margin: margin,
          monthly: monthlyJson.map(_ProfitMonthItem.fromJson).toList(),
        );
      });
    } catch (e) {
      setState(() => _profitError = _errMsg(e));
    } finally {
      setState(() => _profitLoading = false);
    }
  }

  Future<void> _loadProducts() async {
    final id = _storeId;
    if (id == null) return;
    setState(() {
      _productsLoading = true;
      _productsError = null;
    });
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/stores/$id/reports/products',
        queryParameters: {'from': _fmt(_from), 'to': _fmt(_to)},
      );
      final body = resp.data ?? {};
      final topJson =
          (body['topSellers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final deadJson =
          (body['deadStock'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final stockValue = (body['stockValue'] as num?)?.toDouble() ?? 0;
      setState(() {
        _productsData = _ProductsData(
          topSellers: topJson.map((j) => _ProductItem.fromJson(j)).toList(),
          deadStock:
              deadJson.map((j) => _ProductItem.fromJson(j, dead: true)).toList(),
          stockValue: stockValue,
        );
      });
    } catch (e) {
      setState(() => _productsError = _errMsg(e));
    } finally {
      setState(() => _productsLoading = false);
    }
  }

  Future<void> _loadStaff() async {
    final id = _storeId;
    if (id == null) return;
    setState(() {
      _staffLoading = true;
      _staffError = null;
    });
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/stores/$id/reports/staff',
        queryParameters: {'from': _fmt(_from), 'to': _fmt(_to)},
      );
      final body = resp.data ?? {};
      final rows =
          (body['staff'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() => _staffRows = rows.map(_StaffRow.fromJson).toList());
    } catch (e) {
      setState(() => _staffError = _errMsg(e));
    } finally {
      setState(() => _staffLoading = false);
    }
  }

  String _errMsg(Object e) => e.toString().replaceFirst('Exception: ', '');

  String _catLabel(String key) => const {
        'PURCHASE': 'Закупка',
        'RENT': 'Аренда',
        'SALARY': 'Зарплата',
        'UTILITIES': 'Коммунальные',
        'TRANSPORT': 'Транспорт',
        'MARKETING': 'Маркетинг',
        'OTHER': 'Другое',
      }[key] ??
      key;

  // ── Date picker helpers ────────────────────────────────────────────────────

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: _to,
    );
    if (d != null) {
      setState(() => _from = d);
      _loadCurrentTab();
    }
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() => _to = d);
      _loadCurrentTab();
    }
  }

  // ── Export ─────────────────────────────────────────────────────────────────

  void _showExportSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXxl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppConstants.spacingMd),
              const Text('Экспорт отчёта',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppConstants.spacingMd),
              _ExportTile(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Скачать PDF',
                onTap: () {
                  Navigator.pop(ctx);
                  _exportPdf();
                },
              ),
              const SizedBox(height: AppConstants.spacingSm),
              _ExportTile(
                icon: Icons.table_chart_outlined,
                label: 'Скачать Excel',
                onTap: () {
                  Navigator.pop(ctx);
                  _exportExcel();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final doc = pw.Document();
    final tabName = _tabName(_tabController.index);
    final period =
        '${_fmtDate(_from)} — ${_fmtDate(_to)}';

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('DukonPro — $tabName',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Период: $period',
                style: const pw.TextStyle(fontSize: 12)),
            pw.Divider(),
            pw.SizedBox(height: 8),
            ..._buildPdfContent(),
          ],
        );
      },
    ));

    final bytes = await doc.save();
    final dir = await getApplicationDocumentsDirectory();
    final file =
        File('${dir.path}/report_${_tabController.index}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)],
        text: 'Отчёт $tabName ($period)');
  }

  List<pw.Widget> _buildPdfContent() {
    switch (_tabController.index) {
      case 0:
        final rows = _salesData?.rows ?? [];
        if (rows.isEmpty) return [pw.Text('Нет данных')];
        return [
          pw.TableHelper.fromTextArray(
            headers: ['Дата', 'Продаж', 'Выручка', 'Средний чек'],
            data: rows
                .map((r) => [
                      r.date,
                      r.count.toString(),
                      _fmtPrice(r.revenue),
                      _fmtPrice(r.avgCheck),
                    ])
                .toList(),
          ),
        ];
      case 1:
        if (_expenseCategories.isEmpty) return [pw.Text('Нет данных')];
        final total =
            _expenseCategories.fold(0.0, (s, e) => s + e.total);
        return [
          pw.TableHelper.fromTextArray(
            headers: ['Категория', 'Сумма', '%'],
            data: _expenseCategories
                .map((e) => [
                      e.name,
                      _fmtPrice(e.total),
                      total > 0
                          ? '${(e.total / total * 100).toStringAsFixed(1)}%'
                          : '0%',
                    ])
                .toList(),
          ),
        ];
      case 2:
        final p = _profitData;
        if (p == null) return [pw.Text('Нет данных')];
        return [
          pw.TableHelper.fromTextArray(
            headers: ['Показатель', 'Значение'],
            data: [
              ['Доход', _fmtPrice(p.totalIncome)],
              ['Расходы', _fmtPrice(p.totalExpenses)],
              ['Чистая прибыль', _fmtPrice(p.netProfit)],
              ['Маржа', '${p.margin.toStringAsFixed(1)}%'],
            ],
          ),
        ];
      case 3:
        final d = _productsData;
        if (d == null) return [pw.Text('Нет данных')];
        return [
          pw.Text('Топ товары',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['Товар', 'Кол-во', 'Выручка'],
            data: d.topSellers
                .map((p) => [p.name, p.qty.toString(), _fmtPrice(p.revenue)])
                .toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Залёжные товары',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['Товар'],
            data: d.deadStock.map((p) => [p.name]).toList(),
          ),
        ];
      case 4:
        if (_staffRows.isEmpty) return [pw.Text('Нет данных')];
        return [
          pw.TableHelper.fromTextArray(
            headers: ['Кассир', 'Продаж', 'Выручка', 'Средний чек'],
            data: _staffRows
                .map((r) => [
                      r.name,
                      r.salesCount.toString(),
                      _fmtPrice(r.totalRevenue),
                      _fmtPrice(r.avgCheck),
                    ])
                .toList(),
          ),
        ];
      default:
        return [pw.Text('Нет данных')];
    }
  }

  Future<void> _exportExcel() async {
    final excel = xl.Excel.createExcel();
    final tabName = _tabName(_tabController.index);
    final sheet = excel[tabName];

    _buildExcelContent(sheet);

    final bytes = excel.save();
    if (bytes == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/report_${_tabController.index}_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)],
        text: 'Отчёт $tabName');
  }

  void _buildExcelContent(xl.Sheet sheet) {
    void addRow(List<String> cells) {
      final row = <xl.CellValue?>[];
      for (final c in cells) {
        row.add(xl.TextCellValue(c));
      }
      sheet.appendRow(row);
    }

    switch (_tabController.index) {
      case 0:
        addRow(['Дата', 'Продаж', 'Выручка', 'Средний чек']);
        for (final r in _salesData?.rows ?? []) {
          addRow([
            r.date,
            r.count.toString(),
            r.revenue.toStringAsFixed(2),
            r.avgCheck.toStringAsFixed(2)
          ]);
        }
      case 1:
        addRow(['Категория', 'Сумма', '%']);
        final total =
            _expenseCategories.fold(0.0, (s, e) => s + e.total);
        for (final e in _expenseCategories) {
          addRow([
            e.name,
            e.total.toStringAsFixed(2),
            total > 0
                ? '${(e.total / total * 100).toStringAsFixed(1)}%'
                : '0%'
          ]);
        }
      case 2:
        final p = _profitData;
        if (p != null) {
          addRow(['Показатель', 'Значение']);
          addRow(['Доход', p.totalIncome.toStringAsFixed(2)]);
          addRow(['Расходы', p.totalExpenses.toStringAsFixed(2)]);
          addRow(['Чистая прибыль', p.netProfit.toStringAsFixed(2)]);
          addRow(['Маржа %', p.margin.toStringAsFixed(1)]);
          if (p.monthly.isNotEmpty) {
            addRow([]);
            addRow(['Месяц', 'Доход', 'Расходы']);
            for (final m in p.monthly) {
              addRow([
                m.month,
                m.income.toStringAsFixed(2),
                m.expenses.toStringAsFixed(2)
              ]);
            }
          }
        }
      case 3:
        final d = _productsData;
        if (d != null) {
          addRow(['=== Топ товары ===']);
          addRow(['Товар', 'Кол-во', 'Выручка']);
          for (final p in d.topSellers) {
            addRow([p.name, p.qty.toString(), p.revenue.toStringAsFixed(2)]);
          }
          addRow([]);
          addRow(['=== Залёжные товары ===']);
          addRow(['Товар', 'Кол-во', 'Выручка']);
          for (final p in d.deadStock) {
            addRow([p.name, p.qty.toString(), p.revenue.toStringAsFixed(2)]);
          }
          addRow([]);
          addRow(['Стоимость склада', d.stockValue.toStringAsFixed(2)]);
        }
      case 4:
        addRow(['Кассир', 'Продаж', 'Выручка', 'Средний чек']);
        for (final r in _staffRows) {
          addRow([
            r.name,
            r.salesCount.toString(),
            r.totalRevenue.toStringAsFixed(2),
            r.avgCheck.toStringAsFixed(2)
          ]);
        }
    }
  }

  String _tabName(int index) => const [
        'Продажи',
        'Расходы',
        'Прибыль',
        'Товары',
        'Сотрудники',
      ][index];

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        elevation: 0,
        title: Text(
          'Отчёты',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
            color: context.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Продажи'),
            Tab(text: 'Расходы'),
            Tab(text: 'Прибыль'),
            Tab(text: 'Товары'),
            Tab(text: 'Сотрудники'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showExportSheet,
        child: const Icon(Icons.download_outlined, color: AppColors.onPrimary),
      ),
      body: Column(
        children: [
          // Period selector
          _buildPeriodBar(),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SalesTab(
                  loading: _salesLoading,
                  error: _salesError,
                  data: _salesData,
                  fmtPrice: _fmtPrice,
                  onRetry: _loadSales,
                ),
                _ExpensesTab(
                  loading: _expensesLoading,
                  error: _expensesError,
                  categories: _expenseCategories,
                  fmtPrice: _fmtPrice,
                  onRetry: _loadExpenses,
                ),
                _ProfitTab(
                  loading: _profitLoading,
                  error: _profitError,
                  data: _profitData,
                  fmtPrice: _fmtPrice,
                  onRetry: _loadProfit,
                ),
                _ProductsTab(
                  loading: _productsLoading,
                  error: _productsError,
                  data: _productsData,
                  fmtPrice: _fmtPrice,
                  onRetry: _loadProducts,
                ),
                _StaffTab(
                  loading: _staffLoading,
                  error: _staffError,
                  rows: _staffRows,
                  fmtPrice: _fmtPrice,
                  onRetry: _loadStaff,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodBar() {
    return Container(
      color: context.surfaceMuted,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 16, color: context.textSecondary),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _pickFrom,
            child: Text(
              DateFormat('dd.MM.yyyy').format(_from),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('—',
                style: TextStyle(color: context.textSecondary)),
          ),
          GestureDetector(
            onTap: _pickTo,
            child: Text(
              DateFormat('dd.MM.yyyy').format(_to),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.refresh_outlined,
                size: 18, color: context.textSecondary),
            onPressed: _loadCurrentTab,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: context.danger, size: 40),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(
                  color: context.textSecondary,
                  fontFamily: 'Inter'),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_outlined,
              size: 48, color: context.textMuted),
          const SizedBox(height: 12),
          Text('Нет данных',
              style: TextStyle(
                  color: context.textSecondary,
                  fontFamily: 'Inter',
                  fontSize: 16)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  color: context.textPrimary)),
          const SizedBox(height: AppConstants.spacingMd),
          child,
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  color: color)),
        ],
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ExportTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(label,
          style: const TextStyle(
              fontFamily: 'Inter', fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right_outlined,
          color: context.textSecondary),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          side: BorderSide(color: context.border)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: Продажи
// ─────────────────────────────────────────────────────────────────────────────

class _SalesTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final _SalesData? data;
  final String Function(double) fmtPrice;
  final VoidCallback onRetry;

  const _SalesTab({
    required this.loading,
    required this.error,
    required this.data,
    required this.fmtPrice,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingView();
    if (error != null) return _ErrorView(message: error!, onRetry: onRetry);
    final d = data;
    if (d == null || d.rows.isEmpty) return const _EmptyView();

    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      children: [
        // Data table
        _SectionCard(
          title: 'Данные по продажам',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                fontFamily: 'Inter',
                color: context.textSecondary,
              ),
              dataTextStyle: TextStyle(
                fontSize: 13,
                fontFamily: 'Inter',
                color: context.textPrimary,
              ),
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('Дата')),
                DataColumn(label: Text('Продаж'), numeric: true),
                DataColumn(label: Text('Выручка'), numeric: true),
                DataColumn(label: Text('Ср. чек'), numeric: true),
              ],
              rows: d.rows
                  .map((r) => DataRow(cells: [
                        DataCell(Text(r.date)),
                        DataCell(Text(r.count.toString())),
                        DataCell(Text(fmtPrice(r.revenue))),
                        DataCell(Text(fmtPrice(r.avgCheck))),
                      ]))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingMd),

        // Bar chart: top 5 by revenue
        if (d.top5.isNotEmpty)
          _SectionCard(
            title: 'Топ-5 товаров по выручке',
            child: SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: d.top5
                          .map((p) => p.revenue)
                          .reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                        fmtPrice(rod.toY),
                        TextStyle(
                            color: context.onPrimary,
                            fontFamily: 'Inter',
                            fontSize: 12),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= d.top5.length) {
                            return const SizedBox.shrink();
                          }
                          final name = d.top5[idx].name;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              name.length > 8
                                  ? '${name.substring(0, 7)}…'
                                  : name,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Inter',
                                  color: context.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: List.generate(
                    d.top5.length,
                    (i) => BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: d.top5[i].revenue,
                          color: AppColors.primary,
                          width: 28,
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Расходы
// ─────────────────────────────────────────────────────────────────────────────

class _ExpensesTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<_ExpenseCategory> categories;
  final String Function(double) fmtPrice;
  final VoidCallback onRetry;

  const _ExpensesTab({
    required this.loading,
    required this.error,
    required this.categories,
    required this.fmtPrice,
    required this.onRetry,
  });

  static const _colors = [
    Color(0xFF667EEA),
    Color(0xFFFF5252),
    Color(0xFF00C853),
    Color(0xFFFFAB00),
    Color(0xFF2979FF),
    Color(0xFFAA00FF),
    Color(0xFF00BCD4),
  ];

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingView();
    if (error != null) return _ErrorView(message: error!, onRetry: onRetry);
    if (categories.isEmpty) return const _EmptyView();

    final total = categories.fold(0.0, (s, e) => s + e.total);

    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      children: [
        _SectionCard(
          title: 'Расходы по категориям',
          child: SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: List.generate(categories.length, (i) {
                  final cat = categories[i];
                  final pct = total > 0 ? cat.total / total * 100 : 0.0;
                  return PieChartSectionData(
                    color: _colors[i % _colors.length],
                    value: cat.total,
                    title: '${pct.toStringAsFixed(1)}%',
                    radius: 60,
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        color: Colors.white),
                  );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        _SectionCard(
          title: 'Детализация',
          child: Column(
            children: List.generate(categories.length, (i) {
              final cat = categories[i];
              final pct = total > 0 ? cat.total / total * 100 : 0.0;
              return Column(
                children: [
                  if (i > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _colors[i % _colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(cat.name,
                              style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500)),
                        ),
                        Text(fmtPrice(cat.total),
                            style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 48,
                          child: Text(
                            '${pct.toStringAsFixed(1)}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: context.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3: Прибыль
// ─────────────────────────────────────────────────────────────────────────────

class _ProfitTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final _ProfitData? data;
  final String Function(double) fmtPrice;
  final VoidCallback onRetry;

  const _ProfitTab({
    required this.loading,
    required this.error,
    required this.data,
    required this.fmtPrice,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingView();
    if (error != null) return _ErrorView(message: error!, onRetry: onRetry);
    final d = data;
    if (d == null) return const _EmptyView();

    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      children: [
        // KPI cards 2x2
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Доход',
                value: fmtPrice(d.totalIncome),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: _KpiCard(
                label: 'Расходы',
                value: fmtPrice(d.totalExpenses),
                color: context.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Чистая прибыль',
                value: fmtPrice(d.netProfit),
                color: context.success,
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: _KpiCard(
                label: 'Маржа',
                value: '${d.margin.toStringAsFixed(1)}%',
                color: context.warning,
              ),
            ),
          ],
        ),

        if (d.monthly.isNotEmpty) ...[
          const SizedBox(height: AppConstants.spacingMd),
          _SectionCard(
            title: 'Доход vs Расходы по месяцам',
            child: SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: d.monthly
                          .expand((m) => [m.income, m.expenses])
                          .reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= d.monthly.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              d.monthly[idx].month,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Inter',
                                  color: context.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: List.generate(
                    d.monthly.length,
                    (i) => BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: d.monthly[i].income,
                          color: AppColors.primary,
                          width: 14,
                          borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                        ),
                        BarChartRodData(
                          toY: d.monthly[i].expenses,
                          color: context.danger,
                          width: 14,
                          borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Row(
            children: [
              _LegendDot(color: AppColors.primary, label: 'Доход'),
              const SizedBox(width: AppConstants.spacingMd),
              _LegendDot(color: context.danger, label: 'Расходы'),
            ],
          ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: context.textSecondary)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 4: Товары
// ─────────────────────────────────────────────────────────────────────────────

class _ProductsTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final _ProductsData? data;
  final String Function(double) fmtPrice;
  final VoidCallback onRetry;

  const _ProductsTab({
    required this.loading,
    required this.error,
    required this.data,
    required this.fmtPrice,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingView();
    if (error != null) return _ErrorView(message: error!, onRetry: onRetry);
    final d = data;
    if (d == null) return const _EmptyView();

    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      children: [
        // Stock value summary
        Container(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  color: Colors.white, size: 32),
              const SizedBox(width: AppConstants.spacingMd),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Стоимость склада',
                      style: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Inter',
                          fontSize: 13)),
                  Text(fmtPrice(d.stockValue),
                      style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spacingMd),

        // Top sellers
        if (d.topSellers.isNotEmpty)
          _SectionCard(
            title: 'Топ продажи',
            child: Column(
              children: List.generate(d.topSellers.length, (i) {
                final p = d.topSellers[i];
                return Column(
                  children: [
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    fontSize: 12)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(p.name,
                                style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500)),
                          ),
                          Text('${p.qty} шт',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: context.textSecondary)),
                          const SizedBox(width: 8),
                          Text(fmtPrice(p.revenue),
                              style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),

        if (d.deadStock.isNotEmpty) ...[
          const SizedBox(height: AppConstants.spacingMd),
          _SectionCard(
            title: 'Залёжные товары (30+ дней)',
            child: Column(
              children: List.generate(d.deadStock.length, (i) {
                final p = d.deadStock[i];
                return Column(
                  children: [
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_outlined,
                              size: 18, color: AppColors.warning),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(p.name,
                                  style: const TextStyle(
                                      fontFamily: 'Inter'))),
                          Text('${p.qty} шт',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: context.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 5: Сотрудники
// ─────────────────────────────────────────────────────────────────────────────

class _StaffTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<_StaffRow> rows;
  final String Function(double) fmtPrice;
  final VoidCallback onRetry;

  const _StaffTab({
    required this.loading,
    required this.error,
    required this.rows,
    required this.fmtPrice,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingView();
    if (error != null) return _ErrorView(message: error!, onRetry: onRetry);
    if (rows.isEmpty) return const _EmptyView();

    final maxSales = rows.map((r) => r.salesCount).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      children: [
        // Bar chart: sales per cashier
        _SectionCard(
          title: 'Продажи по кассирам',
          child: SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxSales * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                      '${rod.toY.toInt()} продаж',
                      TextStyle(
                          color: context.onPrimary,
                          fontFamily: 'Inter',
                          fontSize: 12),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= rows.length) {
                          return const SizedBox.shrink();
                        }
                        final name = rows[idx].name;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            name.length > 8
                                ? '${name.substring(0, 7)}…'
                                : name,
                            style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'Inter',
                                color: context.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: List.generate(
                  rows.length,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: rows[i].salesCount.toDouble(),
                        color: AppColors.primary,
                        width: 28,
                        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingMd),

        // Table
        _SectionCard(
          title: 'Детализация',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                fontFamily: 'Inter',
                color: context.textSecondary,
              ),
              dataTextStyle: TextStyle(
                fontSize: 13,
                fontFamily: 'Inter',
                color: context.textPrimary,
              ),
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('Кассир')),
                DataColumn(label: Text('Продаж'), numeric: true),
                DataColumn(label: Text('Выручка'), numeric: true),
                DataColumn(label: Text('Ср. чек'), numeric: true),
              ],
              rows: rows
                  .map((r) => DataRow(cells: [
                        DataCell(Text(r.name)),
                        DataCell(Text(r.salesCount.toString())),
                        DataCell(Text(fmtPrice(r.totalRevenue))),
                        DataCell(Text(fmtPrice(r.avgCheck))),
                      ]))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
