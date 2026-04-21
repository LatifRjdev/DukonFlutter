import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../injection.dart';
import '../../blocs/import/import_bloc.dart';
import '../../blocs/import/import_event.dart';
import '../../blocs/import/import_state.dart';

class ImportProductsPage extends StatelessWidget {
  final String storeId;

  const ImportProductsPage({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ImportBloc>(),
      child: _ImportProductsView(storeId: storeId),
    );
  }
}

class _ImportProductsView extends StatelessWidget {
  final String storeId;

  const _ImportProductsView({required this.storeId});

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv', 'xls'],
    );
    if (result != null && result.files.single.path != null) {
      if (!context.mounted) return;
      context.read<ImportBloc>().add(
            ImportFileSelected(
              storeId: storeId,
              filePath: result.files.single.path!,
            ),
          );
    }
  }

  void _downloadTemplate(BuildContext context) {
    context.read<ImportBloc>().add(ImportTemplateRequested(storeId: storeId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Импорт товаров'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: BlocConsumer<ImportBloc, ImportState>(
          listener: (context, state) {
            if (state is ImportSuccess) {
              _showSuccessDialog(context, state);
            } else if (state is ImportError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error,
                ),
              );
            } else if (state is ImportTemplateDownloaded) {
              OpenFile.open(state.filePath);
            }
          },
          builder: (context, state) {
            if (state is ImportLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ImportPreviewLoaded) {
              return _PreviewView(
                state: state,
                storeId: storeId,
              );
            }
            return _InitialView(
              onPickFile: () => _pickFile(context),
              onDownloadTemplate: () => _downloadTemplate(context),
            );
          },
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, ImportSuccess state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Импорт завершён'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultRow(
              icon: Icons.check_circle,
              color: AppColors.success,
              text: 'Создано: ${state.created}',
            ),
            if (state.skipped > 0)
              _ResultRow(
                icon: Icons.skip_next,
                color: AppColors.warning,
                text: 'Пропущено: ${state.skipped}',
              ),
            if (state.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Ошибки: ${state.errors.length}',
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              ...state.errors.take(5).map(
                    (e) => Text(
                      'Строка ${e['row']}: ${e['message']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
              if (state.errors.length > 5)
                Text(
                  '...и ещё ${state.errors.length - 5}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.pop();
            },
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _ResultRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

class _InitialView extends StatelessWidget {
  final VoidCallback onPickFile;
  final VoidCallback onDownloadTemplate;

  const _InitialView({
    required this.onPickFile,
    required this.onDownloadTemplate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.upload_file, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            'Импорт товаров',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'Загрузите список товаров из Excel или CSV файла.\n'
            'Скачайте шаблон для правильного формата.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: context.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPickFile,
              icon: const Icon(Icons.file_upload),
              label: const Text('Выбрать файл'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: context.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDownloadTemplate,
              icon: const Icon(Icons.download),
              label: const Text('Скачать шаблон'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewView extends StatelessWidget {
  final ImportPreviewLoaded state;
  final String storeId;

  const _PreviewView({required this.state, required this.storeId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Summary bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppColors.primary.withValues(alpha: 0.05),
          child: Row(
            children: [
              const Icon(Icons.table_chart, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                '${state.totalRows} товаров найдено',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (state.errors.isNotEmpty) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: Text(
                    '${state.errors.length} ошибок',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Errors list
        if (state.errors.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.error.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: state.errors.take(5).map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'Строка ${e['row']}: ${e['message']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        // Data table
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AppColors.primary.withValues(alpha: 0.05),
                ),
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Название', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Штрихкод', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Категория', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Цена', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                  DataColumn(label: Text('Кол-во', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                ],
                rows: state.rows.map((row) {
                  return DataRow(cells: [
                    DataCell(Text(row['name']?.toString() ?? '')),
                    DataCell(Text(row['barcode']?.toString() ?? '-')),
                    DataCell(Text(row['category']?.toString() ?? '-')),
                    DataCell(Text(row['salePrice']?.toString() ?? '0')),
                    DataCell(Text(row['quantity']?.toString() ?? '0')),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),

        // Import button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surface,
            boxShadow: context.elevationMd,
          ),
          child: ElevatedButton(
            onPressed: state.totalRows > 0
                ? () {
                    context.read<ImportBloc>().add(
                          ImportConfirmed(
                            storeId: storeId,
                            filePath: state.filePath,
                          ),
                        );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: context.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
            ),
            child: Text('Импортировать ${state.totalRows} товаров'),
          ),
        ),
      ],
    );
  }
}
