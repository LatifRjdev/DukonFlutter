import 'package:flutter/material.dart';
import 'package:thermal_printer/thermal_printer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/common/app_snackbar.dart';

class KkmSettingsPage extends StatefulWidget {
  const KkmSettingsPage({super.key});

  @override
  State<KkmSettingsPage> createState() => _KkmSettingsPageState();
}

class _KkmSettingsPageState extends State<KkmSettingsPage> {
  final _printerManager = PrinterManager.instance;
  List<PrinterDevice> _devices = [];
  PrinterDevice? _connectedDevice;
  bool _isScanning = false;
  bool _autoPrint = false;
  bool _isPrinting = false;

  Future<void> _scan() async {
    setState(() { _isScanning = true; _devices = []; });
    try {
      _printerManager.discovery(type: PrinterType.bluetooth).listen((device) {
        if (mounted) setState(() => _devices.add(device));
      });
      await Future.delayed(const Duration(seconds: 5));
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connect(PrinterDevice device) async {
    try {
      await _printerManager.connect(
        type: PrinterType.bluetooth,
        model: BluetoothPrinterInput(
          name: device.name,
          address: device.address ?? '',
          isBle: false,
        ),
      );
      if (mounted) setState(() => _connectedDevice = device);
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Ошибка подключения: $e');
      }
    }
  }

  Future<void> _disconnect() async {
    await _printerManager.disconnect(type: PrinterType.bluetooth);
    if (mounted) setState(() => _connectedDevice = null);
  }

  Future<void> _testPrint() async {
    if (_connectedDevice == null) return;
    setState(() => _isPrinting = true);
    try {
      final ticket = await _buildTestTicket();
      await _printerManager.send(
        type: PrinterType.bluetooth,
        bytes: ticket,
      );
      if (mounted) {
        AppSnackbar.success(context, 'Тестовая печать выполнена');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Ошибка печати: $e');
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<List<int>> _buildTestTicket() async {
    // Simple raw ESC/POS bytes for test print
    final List<int> bytes = [];
    // Initialize printer
    bytes.addAll([0x1B, 0x40]);
    // Center align
    bytes.addAll([0x1B, 0x61, 0x01]);
    // Bold on
    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll('DukonPro\n'.codeUnits);
    // Bold off
    bytes.addAll([0x1B, 0x45, 0x00]);
    bytes.addAll('Тестовая печать\n'.codeUnits);
    bytes.addAll('ККМ/Фискализация\n'.codeUnits);
    bytes.addAll([0x0A, 0x0A, 0x0A]);
    // Cut
    bytes.addAll([0x1D, 0x56, 0x41, 0x10]);
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('ККМ / Фискализация'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fiscal note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.infoBg,
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Фискализация чеков через подключённый ККМ-принтер. '
                      'Убедитесь, что устройство зарегистрировано в налоговой.',
                      style: TextStyle(fontSize: 13, color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Connection status
            Text('Bluetooth принтер',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                border: Border.all(
                  color: _connectedDevice != null
                      ? AppColors.success
                      : context.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _connectedDevice != null
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: _connectedDevice != null
                        ? AppColors.success
                        : context.textSecondary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _connectedDevice != null ? 'Подключён' : 'Не подключён',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _connectedDevice != null
                                ? AppColors.success
                                : context.textSecondary,
                          ),
                        ),
                        if (_connectedDevice != null)
                          Text(_connectedDevice!.name,
                              style: TextStyle(
                                  fontSize: 13, color: context.textSecondary)),
                      ],
                    ),
                  ),
                  if (_connectedDevice != null)
                    TextButton(
                      onPressed: _disconnect,
                      child: const Text('Отключить',
                          style: TextStyle(color: AppColors.error)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scan button
            SizedBox(
              width: double.infinity,
              height: AppConstants.buttonHeight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
                ),
                onPressed: _isScanning ? null : _scan,
                icon: _isScanning
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: AppColors.primary))
                    : const Icon(Icons.search),
                label: Text(_isScanning ? 'Поиск...' : 'Найти принтеры'),
              ),
            ),
            const SizedBox(height: 16),

            // Found devices
            if (_devices.isNotEmpty) ...[
              Text('Найденные устройства',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary)),
              const SizedBox(height: 8),
              ..._devices.map((device) {
                final isConnected = _connectedDevice?.address == device.address;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? AppColors.success.withValues(alpha: 0.05)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(
                        color: isConnected ? AppColors.success : context.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                        color: isConnected ? AppColors.success : AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(device.name,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            if (device.address != null)
                              Text(device.address!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: context.textSecondary)),
                          ],
                        ),
                      ),
                      if (!isConnected)
                        TextButton(
                          onPressed: () => _connect(device),
                          child: const Text('Подключить'),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],

            // Auto-print toggle
            Text('Настройки',
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                      ),
                      child: const Icon(Icons.print_outlined,
                          color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Автопечать при продаже',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                    Switch(
                      value: _autoPrint,
                      onChanged: (v) => setState(() => _autoPrint = v),
                      activeThumbColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Test print
            if (_connectedDevice != null) ...[
              SizedBox(
                width: double.infinity,
                height: AppConstants.buttonHeight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusLg)),
                  ),
                  onPressed: _isPrinting ? null : _testPrint,
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.print),
                  label: Text(_isPrinting ? 'Печать...' : 'Тестовая печать'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
