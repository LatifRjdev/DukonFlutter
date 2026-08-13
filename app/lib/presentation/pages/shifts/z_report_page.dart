import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/z_report.dart';
import '../../blocs/shift/shift_bloc.dart';
import '../../blocs/shift/shift_event.dart';
import '../../blocs/shift/shift_state.dart';

class ZReportPage extends StatefulWidget {
  final String storeId;
  final String shiftId;
  const ZReportPage({super.key, required this.storeId, required this.shiftId});
  @override
  State<ZReportPage> createState() => _ZReportPageState();
}

class _ZReportPageState extends State<ZReportPage> {
  @override
  void initState() {
    super.initState();
    context.read<ShiftBloc>().add(LoadZReport(
      storeId: widget.storeId,
      shiftId: widget.shiftId,
    ));
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.zReport)),
      body: BlocBuilder<ShiftBloc, ShiftState>(
        builder: (context, state) {
          if (state is ShiftLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ShiftError) {
            return Center(child: Text(state.message));
          }
          if (state is ZReportLoaded) {
            return _buildReport(state.report, l10n);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildReport(ZReport report, AppLocalizations l10n) {
    final diffColor = report.difference >= 0 ? AppColors.success : AppColors.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _SectionCard(
            child: Column(
              children: [
                const Icon(Icons.receipt_long, size: 40, color: AppColors.primary),
                const SizedBox(height: AppConstants.spacingSm),
                Text(l10n.zReportHeaderTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: AppConstants.spacingSm),
                Text(report.staffName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  '${_formatDateTime(report.openedAt)} — ${_formatDateTime(report.closedAt)}',
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.duration}: ${report.duration}',
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Sales section
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(title: l10n.sales, icon: Icons.shopping_cart),
                const SizedBox(height: AppConstants.spacingSm),
                _ReportRow(label: l10n.zReportSalesCount, value: '${report.salesCount}'),
                _ReportRow(label: l10n.cash, value: '${report.cashTotal.toStringAsFixed(2)} TJS'),
                _ReportRow(label: l10n.card, value: '${report.cardTotal.toStringAsFixed(2)} TJS'),
                _ReportRow(label: l10n.debt, value: '${report.debtTotal.toStringAsFixed(2)} TJS'),
                Divider(color: context.border),
                _ReportRow(
                  label: l10n.zReportTotalSales,
                  value: '${report.salesTotal.toStringAsFixed(2)} TJS',
                  isBold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Returns section
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(title: l10n.returns, icon: Icons.undo),
                const SizedBox(height: AppConstants.spacingSm),
                _ReportRow(label: l10n.zReportReturnsCount, value: '${report.returnsCount}'),
                _ReportRow(
                  label: l10n.zReportReturnsAmount,
                  value: '${report.returnsTotal.toStringAsFixed(2)} TJS',
                  isBold: true,
                  valueColor: AppColors.error,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Cash drawer section
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(title: l10n.pos, icon: Icons.point_of_sale),
                const SizedBox(height: AppConstants.spacingSm),
                _ReportRow(label: l10n.zReportOpeningAmount, value: '${report.openingCash.toStringAsFixed(2)} TJS'),
                _ReportRow(label: l10n.zReportCashSalesLabel, value: '+${report.cashSalesAmount.toStringAsFixed(2)} TJS', valueColor: AppColors.success),
                _ReportRow(label: l10n.zReportCashReturnsLabel, value: '-${report.cashReturns.toStringAsFixed(2)} TJS', valueColor: AppColors.error),
                _ReportRow(label: l10n.withdrawals, value: '-${report.withdrawals.toStringAsFixed(2)} TJS', valueColor: AppColors.error),
                Divider(color: context.border),
                _ReportRow(label: l10n.zReportExpectedAmount, value: '${report.expectedCash.toStringAsFixed(2)} TJS', isBold: true),
                _ReportRow(label: l10n.zReportActualAmount, value: '${report.actualCash.toStringAsFixed(2)} TJS', isBold: true),
                Divider(color: context.border),
                _ReportRow(
                  label: l10n.cashDifference,
                  value: '${report.difference >= 0 ? '+' : ''}${report.difference.toStringAsFixed(2)} TJS',
                  isBold: true,
                  valueColor: diffColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Top products section
          if (report.topProducts.isNotEmpty)
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(title: l10n.topProducts, icon: Icons.star),
                  const SizedBox(height: AppConstants.spacingSm),
                  ...report.topProducts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final product = entry.value;
                    final name = product['name'] as String? ?? '';
                    final qty = product['quantity'] ?? 0;
                    final total = product['total'] ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${index + 1}.',
                              style: TextStyle(fontWeight: FontWeight.w600, color: context.textSecondary),
                            ),
                          ),
                          Expanded(
                            child: Text(name, style: const TextStyle(fontSize: 14)),
                          ),
                          Text(
                            'x$qty',
                            style: TextStyle(fontSize: 13, color: context.textSecondary),
                          ),
                          const SizedBox(width: AppConstants.spacingMd),
                          Text(
                            '${(total as num).toStringAsFixed(0)} TJS',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: AppConstants.spacingLg),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _printReport(report, l10n),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    ),
                  ),
                  icon: const Icon(Icons.print_outlined, size: 20),
                  label: Text(l10n.zReportPrintButton,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareReport(report, l10n),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textPrimary,
                    side: BorderSide(color: context.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    ),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 20),
                  label: Text(l10n.share,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(l10n.done,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
        ],
      ),
    );
  }

  void _printReport(ZReport report, AppLocalizations l10n) {
    Printing.layoutPdf(onLayout: (format) async {
      return _buildZReportPdf(report, l10n);
    });
  }

  void _shareReport(ZReport report, AppLocalizations l10n) async {
    final bytes = await _buildZReportPdf(report, l10n);
    await Printing.sharePdf(bytes: bytes, filename: 'z-report.pdf');
  }

  Future<Uint8List> _buildZReportPdf(ZReport report, AppLocalizations l10n) {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(l10n.zReportHeaderTitle,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('${l10n.cashier}: ${report.staffName}'),
          pw.SizedBox(height: 8),
          pw.Text(l10n.zReportPdfSalesReturnsLine('${report.salesCount}', '${report.returnsCount}')),
          pw.Text('${l10n.cash}: ${report.cashTotal.toStringAsFixed(2)}'),
          pw.Text('${l10n.card}: ${report.cardTotal.toStringAsFixed(2)}'),
          pw.Text(l10n.zReportPdfDebtLine(report.debtTotal.toStringAsFixed(2))),
          pw.Divider(),
          pw.Text(l10n.zReportPdfTotalLine(report.salesTotal.toStringAsFixed(2)),
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ));
    return doc.save();
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        boxShadow: context.elevationSm,
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: AppConstants.spacingSm),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _ReportRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isBold ? context.textPrimary : context.textSecondary,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
