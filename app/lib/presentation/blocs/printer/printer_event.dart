import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:equatable/equatable.dart';

abstract class PrinterEvent extends Equatable {
  const PrinterEvent();
  @override
  List<Object?> get props => [];
}

class PrinterScanRequested extends PrinterEvent {}

class PrinterConnectRequested extends PrinterEvent {
  final BluetoothDevice device;
  const PrinterConnectRequested(this.device);
  @override
  List<Object?> get props => [device];
}

class PrinterDisconnectRequested extends PrinterEvent {}

class PrinterTestPrintRequested extends PrinterEvent {}

class PrinterSetDefaultRequested extends PrinterEvent {
  final String name;
  final String address;
  const PrinterSetDefaultRequested({required this.name, required this.address});
  @override
  List<Object?> get props => [name, address];
}

class PrinterLoadDefaultRequested extends PrinterEvent {}
