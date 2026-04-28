import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/common/app_snackbar.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

class ScannerSettingsPage extends StatefulWidget {
  const ScannerSettingsPage({super.key});

  @override
  State<ScannerSettingsPage> createState() => _ScannerSettingsPageState();
}

class _ScannerSettingsPageState extends State<ScannerSettingsPage> {
  static const _keyCamera = 'scanner_camera';
  static const _keySound = 'scanner_sound';
  static const _keyVibration = 'scanner_vibration';
  static const _keyAutoAdd = 'scanner_auto_add';
  static const _keyFormats = 'scanner_formats';

  String _camera = 'back';
  bool _sound = true;
  bool _vibration = true;
  bool _autoAdd = false;
  final Set<String> _formats = {'EAN-13', 'EAN-8', 'QR', 'Code128'};
  bool _loading = true;
  bool _saving = false;

  final List<String> _allFormats = ['EAN-13', 'EAN-8', 'QR', 'Code128'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _camera = prefs.getString(_keyCamera) ?? 'back';
      _sound = prefs.getBool(_keySound) ?? true;
      _vibration = prefs.getBool(_keyVibration) ?? true;
      _autoAdd = prefs.getBool(_keyAutoAdd) ?? false;
      final saved = prefs.getStringList(_keyFormats);
      if (saved != null) {
        _formats.clear();
        _formats.addAll(saved);
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCamera, _camera);
    await prefs.setBool(_keySound, _sound);
    await prefs.setBool(_keyVibration, _vibration);
    await prefs.setBool(_keyAutoAdd, _autoAdd);
    await prefs.setStringList(_keyFormats, _formats.toList());
    if (mounted) {
      setState(() => _saving = false);
      AppSnackbar.success(context, AppLocalizations.of(context)!.snackScannerSettingsSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Сканер штрихкодов'),
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
                    style: TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w600)),
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
                  // Camera selection
                  Text('Камера',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary)),
                  const SizedBox(height: 8),
                  RadioGroup<String>(
                    groupValue: _camera,
                    onChanged: (v) => setState(() => _camera = v!),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            value: 'back',
                            title: const Text('Задняя камера',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            subtitle: const Text('Рекомендуется для сканирования',
                                style: TextStyle(fontSize: 12)),
                            secondary: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                              ),
                              child: const Icon(Icons.camera_rear_outlined,
                                  color: AppColors.primary, size: 18),
                            ),
                            activeColor: AppColors.primary,
                          ),
                          const Divider(height: 1, indent: 52),
                          RadioListTile<String>(
                            value: 'front',
                            title: const Text('Передняя камера',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            subtitle: const Text('Фронтальная камера',
                                style: TextStyle(fontSize: 12)),
                            secondary: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                              ),
                              child: const Icon(Icons.camera_front_outlined,
                                  color: AppColors.primary, size: 18),
                            ),
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Behavior toggles
                  Text('Поведение',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    ),
                    child: Column(
                      children: [
                        _buildToggle(
                          Icons.volume_up_outlined,
                          'Звук при сканировании',
                          _sound,
                          (v) => setState(() => _sound = v),
                        ),
                        const Divider(height: 1, indent: 52),
                        _buildToggle(
                          Icons.vibration_outlined,
                          'Вибрация при сканировании',
                          _vibration,
                          (v) => setState(() => _vibration = v),
                        ),
                        const Divider(height: 1, indent: 52),
                        _buildToggle(
                          Icons.add_shopping_cart_outlined,
                          'Авто-добавление в корзину',
                          _autoAdd,
                          (v) => setState(() => _autoAdd = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Barcode formats
                  Text('Форматы штрихкодов',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    ),
                    child: Column(
                      children: _allFormats.asMap().entries.map((entry) {
                        final format = entry.value;
                        final isLast = entry.key == _allFormats.length - 1;
                        return Column(
                          children: [
                            CheckboxListTile(
                              value: _formats.contains(format),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _formats.add(format);
                                  } else {
                                    _formats.remove(format);
                                  }
                                });
                              },
                              title: Text(format,
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w500)),
                              activeColor: AppColors.primary,
                              controlAffinity: ListTileControlAffinity.trailing,
                              secondary: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                                ),
                                child: const Icon(Icons.qr_code_outlined,
                                    color: AppColors.primary, size: 18),
                              ),
                            ),
                            if (!isLast) const Divider(height: 1, indent: 52),
                          ],
                        );
                      }).toList(),
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
                                BorderRadius.circular(AppConstants.radiusLg)),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Сохранить настройки',
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
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
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
