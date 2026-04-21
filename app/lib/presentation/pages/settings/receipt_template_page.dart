import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../injection.dart';

class ReceiptTemplatePage extends StatefulWidget {
  final String storeId;
  const ReceiptTemplatePage({super.key, required this.storeId});

  @override
  State<ReceiptTemplatePage> createState() => _ReceiptTemplatePageState();
}

class _ReceiptTemplatePageState extends State<ReceiptTemplatePage> {
  final _dioClient = sl<DioClient>();
  bool _loading = true;
  bool _saving = false;

  final _headerCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  String _fontSize = 'medium';
  String _paperWidth = '80mm';
  bool _showQr = true;
  bool _showDate = true;
  bool _showCashier = true;
  bool _showDiscount = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try {
      final res = await _dioClient.get('/stores/${widget.storeId}/receipt-template');
      final data = res.data as Map<String, dynamic>? ?? {};
      setState(() {
        _headerCtrl.text = data['headerText'] as String? ?? '';
        _footerCtrl.text = data['footerText'] as String? ?? '';
        _fontSize = data['fontSize'] as String? ?? 'medium';
        _paperWidth = data['paperWidth'] as String? ?? '80mm';
        _showQr = data['showQr'] as bool? ?? true;
        _showDate = data['showDate'] as bool? ?? true;
        _showCashier = data['showCashier'] as bool? ?? true;
        _showDiscount = data['showDiscount'] as bool? ?? true;
      });
    } catch (e) {
      // Use defaults if template doesn't exist yet
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _dioClient.put('/stores/${widget.storeId}/receipt-template', data: {
        'headerText': _headerCtrl.text.trim(),
        'footerText': _footerCtrl.text.trim(),
        'fontSize': _fontSize,
        'paperWidth': _paperWidth,
        'showQr': _showQr,
        'showDate': _showDate,
        'showCashier': _showCashier,
        'showDiscount': _showDiscount,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Шаблон сохранён'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildReceiptPreview() {
    final headerText = _headerCtrl.text.isEmpty ? 'Ваш магазин' : _headerCtrl.text;
    final footerText = _footerCtrl.text.isEmpty ? 'Спасибо за покупку!' : _footerCtrl.text;
    final double fSize = _fontSize == 'small' ? 10 : _fontSize == 'large' ? 14 : 12;
    final double width = _paperWidth == '58mm' ? 180 : 240;

    return Center(
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: context.elevationMd,
        ),
        child: Column(
          children: [
            Text(headerText,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: fSize + 2,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),
            const Divider(color: Colors.black26),
            Text('Товар 1                 50.00 TJS',
                style: TextStyle(fontSize: fSize, color: Colors.black87, fontFamily: 'monospace')),
            Text('Товар 2                 30.00 TJS',
                style: TextStyle(fontSize: fSize, color: Colors.black87, fontFamily: 'monospace')),
            if (_showDiscount)
              Text('Скидка                  -5.00 TJS',
                  style: TextStyle(fontSize: fSize, color: Colors.red, fontFamily: 'monospace')),
            const Divider(color: Colors.black26),
            Text('ИТОГО                   75.00 TJS',
                style: TextStyle(
                    fontSize: fSize + 1,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    fontFamily: 'monospace')),
            if (_showDate) ...[
              const SizedBox(height: 4),
              Text('12.04.2026 14:30',
                  style: TextStyle(fontSize: fSize - 1, color: Colors.black54)),
            ],
            if (_showCashier) ...[
              Text('Кассир: Иванов И.',
                  style: TextStyle(fontSize: fSize - 1, color: Colors.black54)),
            ],
            if (_showQr) ...[
              const SizedBox(height: 8),
              Icon(Icons.qr_code_2, size: 48, color: Colors.black87),
            ],
            const Divider(color: Colors.black26),
            Text(footerText,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: fSize - 1, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Шаблон чека'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Сохранить',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                    ),
                    child: Column(
                      children: [
                        Text('Предпросмотр',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondary)),
                        const SizedBox(height: 12),
                        _buildReceiptPreview(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header/Footer
                  Text('Текст',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          controller: _headerCtrl,
                          onChanged: (v) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Заголовок чека',
                            border: OutlineInputBorder(),
                            hintText: 'Название магазина или приветствие',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _footerCtrl,
                          onChanged: (v) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Подвал чека',
                            border: OutlineInputBorder(),
                            hintText: 'Спасибо за покупку!',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Font size
                  Text('Размер шрифта',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'small', label: Text('Мал.')),
                              ButtonSegment(value: 'medium', label: Text('Ср.')),
                              ButtonSegment(value: 'large', label: Text('Бол.')),
                            ],
                            selected: {_fontSize},
                            onSelectionChanged: (s) =>
                                setState(() => _fontSize = s.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Paper width
                  Text('Ширина бумаги',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: '58mm', label: Text('58 мм')),
                              ButtonSegment(value: '80mm', label: Text('80 мм')),
                            ],
                            selected: {_paperWidth},
                            onSelectionChanged: (s) =>
                                setState(() => _paperWidth = s.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Toggles
                  Text('Показывать на чеке',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                    ),
                    child: Column(
                      children: [
                        _buildToggle(Icons.qr_code_outlined, 'QR-код', _showQr,
                            (v) => setState(() => _showQr = v)),
                        const Divider(height: 1, indent: 52),
                        _buildToggle(Icons.calendar_today_outlined, 'Дата и время',
                            _showDate, (v) => setState(() => _showDate = v)),
                        const Divider(height: 1, indent: 52),
                        _buildToggle(Icons.person_outline, 'Кассир', _showCashier,
                            (v) => setState(() => _showCashier = v)),
                        const Divider(height: 1, indent: 52),
                        _buildToggle(Icons.discount_outlined, 'Скидка', _showDiscount,
                            (v) => setState(() => _showDiscount = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppConstants.buttonRadius)),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Сохранить шаблон',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildToggle(
      IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary),
        ],
      ),
    );
  }
}
