import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/services/thermal_printer_service.dart';
import 'printer_event.dart';
import 'printer_state.dart';

class PrinterBloc extends Bloc<PrinterEvent, PrinterState> {
  final ThermalPrinterService _printerService;

  PrinterBloc({required ThermalPrinterService printerService})
      : _printerService = printerService,
        super(const PrinterState()) {
    on<PrinterScanRequested>(_onScan);
    on<PrinterConnectRequested>(_onConnect);
    on<PrinterDisconnectRequested>(_onDisconnect);
    on<PrinterTestPrintRequested>(_onTestPrint);
    on<PrinterSetDefaultRequested>(_onSetDefault);
    on<PrinterLoadDefaultRequested>(_onLoadDefault);
  }

  Future<void> _onScan(PrinterScanRequested event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(isScanning: true, clearError: true, clearSuccessMessage: true));
    try {
      final devices = await _printerService.scanDevices();
      emit(state.copyWith(devices: devices, isScanning: false));
    } catch (e) {
      emit(state.copyWith(isScanning: false, error: 'Ошибка поиска: ${mapErrorToUserMessage(e)}'));
    }
  }

  Future<void> _onConnect(PrinterConnectRequested event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(clearError: true, clearSuccessMessage: true));
    try {
      final success = await _printerService.connect(event.device);
      if (success) {
        emit(state.copyWith(
          connectedDevice: event.device,
          successMessage: 'Подключено к ${event.device.name}',
        ));
      } else {
        emit(state.copyWith(error: 'Не удалось подключиться'));
      }
    } catch (e) {
      emit(state.copyWith(error: 'Ошибка подключения: ${mapErrorToUserMessage(e)}'));
    }
  }

  Future<void> _onDisconnect(PrinterDisconnectRequested event, Emitter<PrinterState> emit) async {
    await _printerService.disconnect();
    emit(state.copyWith(clearConnectedDevice: true, successMessage: 'Принтер отключён'));
  }

  Future<void> _onTestPrint(PrinterTestPrintRequested event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(isPrinting: true, clearError: true, clearSuccessMessage: true));
    try {
      final success = await _printerService.testPrint();
      emit(state.copyWith(
        isPrinting: false,
        successMessage: success ? 'Тестовая печать выполнена' : null,
        error: success ? null : 'Не удалось напечатать',
      ));
    } catch (e) {
      emit(state.copyWith(isPrinting: false, error: 'Ошибка печати: ${mapErrorToUserMessage(e)}'));
    }
  }

  Future<void> _onSetDefault(PrinterSetDefaultRequested event, Emitter<PrinterState> emit) async {
    await _printerService.setDefaultPrinter(event.name, event.address);
    emit(state.copyWith(
      defaultPrinterName: event.name,
      defaultPrinterAddress: event.address,
      successMessage: 'Принтер по умолчанию: ${event.name}',
    ));
  }

  Future<void> _onLoadDefault(PrinterLoadDefaultRequested event, Emitter<PrinterState> emit) async {
    final name = await _printerService.getDefaultPrinterName();
    final address = await _printerService.getDefaultPrinterAddress();
    if (name != null && address != null) {
      emit(state.copyWith(defaultPrinterName: name, defaultPrinterAddress: address));
    }
  }
}
