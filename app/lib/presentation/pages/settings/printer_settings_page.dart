import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:thermal_printer/thermal_printer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/printer/printer_bloc.dart';
import '../../blocs/printer/printer_event.dart';
import '../../blocs/printer/printer_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_snackbar.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  @override
  void initState() {
    super.initState();
    context.read<PrinterBloc>().add(PrinterLoadDefaultRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки принтера')),
      body: BlocConsumer<PrinterBloc, PrinterState>(
        listener: (context, state) {
          if (state.error != null) {
            AppSnackbar.error(context, state.error!);
          }
          if (state.successMessage != null) {
            AppSnackbar.success(context, state.successMessage!);
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.spacingMd),
                  decoration: BoxDecoration(
                    color: state.connectedDevice != null
                        ? AppColors.success.withValues(alpha: 0.1)
                        : context.bg,
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    border: Border.all(
                      color: state.connectedDevice != null ? AppColors.success : context.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        state.connectedDevice != null ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                        color: state.connectedDevice != null ? AppColors.success : context.textSecondary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.connectedDevice != null ? 'Подключён' : 'Не подключён',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: state.connectedDevice != null ? AppColors.success : context.textSecondary,
                              ),
                            ),
                            if (state.connectedDevice != null)
                              Text(
                                state.connectedDevice!.name,
                                style: TextStyle(fontSize: 14, color: context.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      if (state.connectedDevice != null)
                        TextButton(
                          onPressed: () => context.read<PrinterBloc>().add(PrinterDisconnectRequested()),
                          child: const Text('Отключить', style: TextStyle(color: AppColors.error)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Default printer
                if (state.defaultPrinterName != null) ...[
                  Text('Принтер по умолчанию',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.spacingSm),
                    decoration: BoxDecoration(
                      color: context.bg,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    ),
                    child: Text(state.defaultPrinterName!, style: const TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(height: 20),
                ],

                // Scan button
                AppButton(
                  text: state.isScanning ? 'Поиск...' : 'Найти принтеры',
                  icon: Icons.search,
                  type: AppButtonType.outlined,
                  onPressed: state.isScanning
                      ? null
                      : () => context.read<PrinterBloc>().add(PrinterScanRequested()),
                ),
                const SizedBox(height: 16),

                if (state.isScanning)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),

                // Device list
                if (state.devices.isNotEmpty) ...[
                  const Text('Найденные устройства', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...state.devices.map((device) => _DeviceTile(
                        device: device,
                        isConnected: state.connectedDevice?.address == device.address,
                        isDefault: state.defaultPrinterAddress == device.address,
                        onConnect: () => context.read<PrinterBloc>().add(PrinterConnectRequested(device)),
                        onSetDefault: () => context.read<PrinterBloc>().add(
                              PrinterSetDefaultRequested(name: device.name, address: device.address ?? ''),
                            ),
                      )),
                ],

                // Test print
                if (state.connectedDevice != null) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  AppButton(
                    text: state.isPrinting ? 'Печать...' : 'Тестовая печать',
                    icon: Icons.print,
                    onPressed: state.isPrinting
                        ? null
                        : () => context.read<PrinterBloc>().add(PrinterTestPrintRequested()),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final PrinterDevice device;
  final bool isConnected;
  final bool isDefault;
  final VoidCallback onConnect;
  final VoidCallback onSetDefault;

  const _DeviceTile({
    required this.device,
    required this.isConnected,
    required this.isDefault,
    required this.onConnect,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: isConnected ? AppColors.success.withValues(alpha: 0.05) : context.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: isConnected ? AppColors.success : context.border),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
            color: isConnected ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(device.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                        ),
                        child: const Text('По умолчанию',
                            style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                if (device.address != null)
                  Text(device.address!, style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ],
            ),
          ),
          if (!isConnected)
            TextButton(onPressed: onConnect, child: const Text('Подключить')),
          if (isConnected && !isDefault)
            TextButton(onPressed: onSetDefault, child: const Text('По умолч.', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
