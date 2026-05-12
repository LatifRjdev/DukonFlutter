import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:equatable/equatable.dart';

class PrinterState extends Equatable {
  final List<BluetoothDevice> devices;
  final BluetoothDevice? connectedDevice;
  final String? defaultPrinterName;
  final String? defaultPrinterAddress;
  final bool isScanning;
  final bool isPrinting;
  final String? error;
  final String? successMessage;

  const PrinterState({
    this.devices = const [],
    this.connectedDevice,
    this.defaultPrinterName,
    this.defaultPrinterAddress,
    this.isScanning = false,
    this.isPrinting = false,
    this.error,
    this.successMessage,
  });

  PrinterState copyWith({
    List<BluetoothDevice>? devices,
    BluetoothDevice? connectedDevice,
    bool clearConnectedDevice = false,
    String? defaultPrinterName,
    String? defaultPrinterAddress,
    bool? isScanning,
    bool? isPrinting,
    String? error,
    bool clearError = false,
    String? successMessage,
    bool clearSuccessMessage = false,
  }) {
    return PrinterState(
      devices: devices ?? this.devices,
      connectedDevice: clearConnectedDevice ? null : (connectedDevice ?? this.connectedDevice),
      defaultPrinterName: defaultPrinterName ?? this.defaultPrinterName,
      defaultPrinterAddress: defaultPrinterAddress ?? this.defaultPrinterAddress,
      isScanning: isScanning ?? this.isScanning,
      isPrinting: isPrinting ?? this.isPrinting,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccessMessage ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        devices,
        connectedDevice,
        defaultPrinterName,
        defaultPrinterAddress,
        isScanning,
        isPrinting,
        error,
        successMessage,
      ];
}
