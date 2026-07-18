import 'package:bloc_test/bloc_test.dart';
import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/services/thermal_printer_service.dart';
import 'package:dukonpro/presentation/blocs/printer/printer_bloc.dart';
import 'package:dukonpro/presentation/blocs/printer/printer_event.dart';
import 'package:dukonpro/presentation/blocs/printer/printer_state.dart';

class MockThermalPrinterService extends Mock implements ThermalPrinterService {}

void main() {
  late MockThermalPrinterService printerService;

  final deviceA = BluetoothDevice('Printer A', '00:11:22:33:44:55');
  final deviceB = BluetoothDevice('Printer B', 'AA:BB:CC:DD:EE:FF');

  setUp(() {
    printerService = MockThermalPrinterService();
  });

  group('PrinterBloc', () {
    test('initial state is the default PrinterState', () {
      final bloc = PrinterBloc(printerService: printerService);
      expect(bloc.state, const PrinterState());
      expect(bloc.state.devices, isEmpty);
      expect(bloc.state.connectedDevice, isNull);
      expect(bloc.state.isScanning, isFalse);
      expect(bloc.state.isPrinting, isFalse);
      expect(bloc.state.error, isNull);
      expect(bloc.state.successMessage, isNull);
    });

    group('PrinterScanRequested', () {
      blocTest<PrinterBloc, PrinterState>(
        'emits isScanning=true then devices + isScanning=false on success',
        setUp: () {
          when(() => printerService.scanDevices())
              .thenAnswer((_) async => [deviceA, deviceB]);
        },
        build: () => PrinterBloc(printerService: printerService),
        act: (bloc) => bloc.add(PrinterScanRequested()),
        expect: () => [
          predicate<PrinterState>((s) => s.isScanning && s.error == null && s.successMessage == null),
          predicate<PrinterState>((s) =>
              !s.isScanning && s.devices.length == 2 && s.devices[0] == deviceA && s.devices[1] == deviceB),
        ],
      );

      blocTest<PrinterBloc, PrinterState>(
        'clears previous error/success message when a new scan starts',
        setUp: () {
          when(() => printerService.scanDevices()).thenAnswer((_) async => [deviceA]);
        },
        build: () => PrinterBloc(printerService: printerService),
        seed: () => const PrinterState(error: 'old error', successMessage: 'old success'),
        act: (bloc) => bloc.add(PrinterScanRequested()),
        expect: () => [
          predicate<PrinterState>((s) => s.isScanning && s.error == null && s.successMessage == null),
          predicate<PrinterState>((s) => !s.isScanning && s.devices.length == 1),
        ],
      );

      blocTest<PrinterBloc, PrinterState>(
        'emits mapped network error message when scanDevices throws NetworkException',
        setUp: () {
          when(() => printerService.scanDevices()).thenThrow(const NetworkException());
        },
        build: () => PrinterBloc(printerService: printerService),
        act: (bloc) => bloc.add(PrinterScanRequested()),
        expect: () => [
          predicate<PrinterState>((s) => s.isScanning),
          predicate<PrinterState>((s) =>
              !s.isScanning && s.error == 'Ошибка поиска: Нет подключения к интернету' && s.devices.isEmpty),
        ],
      );

      blocTest<PrinterBloc, PrinterState>(
        'never leaks raw exception text into the scan error message',
        setUp: () {
          when(() => printerService.scanDevices())
              .thenThrow(Exception('PlatformException(bluetooth_off, ...)'));
        },
        build: () => PrinterBloc(printerService: printerService),
        act: (bloc) => bloc.add(PrinterScanRequested()),
        expect: () => [
          predicate<PrinterState>((s) => s.isScanning),
          predicate<PrinterState>((s) {
            if (s.isScanning) return false;
            final err = s.error ?? '';
            return err.isNotEmpty && !err.contains('PlatformException') && !err.contains('bluetooth_off');
          }, 'error set but no leaky internal text'),
        ],
      );
    });

    group('PrinterConnectRequested', () {
      blocTest<PrinterBloc, PrinterState>(
        'sets connectedDevice and success message when connect succeeds',
        setUp: () {
          when(() => printerService.connect(deviceA)).thenAnswer((_) async => true);
        },
        build: () => PrinterBloc(printerService: printerService),
        act: (bloc) => bloc.add(PrinterConnectRequested(deviceA)),
        expect: () => [
          predicate<PrinterState>((s) => s.connectedDevice == null && s.error == null && s.successMessage == null),
          predicate<PrinterState>((s) =>
              s.connectedDevice == deviceA && s.successMessage == 'Подключено к ${deviceA.name}' && s.error == null),
        ],
        verify: (_) {
          verify(() => printerService.connect(deviceA)).called(1);
        },
      );

      blocTest<PrinterBloc, PrinterState>(
        'emits a generic error and no connectedDevice when connect returns false',
        setUp: () {
          when(() => printerService.connect(deviceA)).thenAnswer((_) async => false);
        },
        build: () => PrinterBloc(printerService: printerService),
        act: (bloc) => bloc.add(PrinterConnectRequested(deviceA)),
        expect: () => [
          predicate<PrinterState>((s) => s.connectedDevice == null && s.error == null && s.successMessage == null),
          predicate<PrinterState>((s) => s.connectedDevice == null && s.error == 'Не удалось подключиться'),
        ],
      );

      blocTest<PrinterBloc, PrinterState>(
        'maps a thrown exception to a connection error message when printer is unreachable',
        setUp: () {
          when(() => printerService.connect(deviceA)).thenThrow(const NetworkException());
        },
        build: () => PrinterBloc(printerService: printerService),
        act: (bloc) => bloc.add(PrinterConnectRequested(deviceA)),
        expect: () => [
          predicate<PrinterState>((s) => s.connectedDevice == null && s.error == null && s.successMessage == null),
          predicate<PrinterState>((s) =>
              s.connectedDevice == null && s.error == 'Ошибка подключения: Нет подключения к интернету'),
        ],
      );

      blocTest<PrinterBloc, PrinterState>(
        'clears previous error/success before attempting to connect',
        setUp: () {
          when(() => printerService.connect(deviceA)).thenAnswer((_) async => true);
        },
        build: () => PrinterBloc(printerService: printerService),
        seed: () => const PrinterState(error: 'old error', successMessage: 'old success'),
        act: (bloc) => bloc.add(PrinterConnectRequested(deviceA)),
        expect: () => [
          predicate<PrinterState>((s) => s.error == null && s.successMessage == null && s.connectedDevice == null),
          predicate<PrinterState>((s) => s.connectedDevice == deviceA && s.error == null),
        ],
      );
    });

    group('PrinterDisconnectRequested', () {
      blocTest<PrinterBloc, PrinterState>(
        'calls service.disconnect and clears connectedDevice with a success message',
        setUp: () {
          when(() => printerService.disconnect()).thenAnswer((_) async {});
        },
        build: () => PrinterBloc(printerService: printerService),
        seed: () => PrinterState(connectedDevice: deviceA),
        act: (bloc) => bloc.add(PrinterDisconnectRequested()),
        expect: () => [
          predicate<PrinterState>((s) => s.connectedDevice == null && s.successMessage == 'Принтер отключён'),
        ],
        verify: (_) {
          verify(() => printerService.disconnect()).called(1);
        },
      );
    });

    group('PrinterTestPrintRequested', () {
      blocTest<PrinterBloc, PrinterState>(
        'emits isPrinting=true then success message when testPrint succeeds',
        setUp: () {
          when(() => printerService.testPrint()).thenAnswer((_) async => true);
        },
        build: () => PrinterBloc(printerService: printerService),
        act: (bloc) => bloc.add(PrinterTestPrintRequested()),
        expect: () => [
          predicate<PrinterState>((s) => s.isPrinting && s.error == null && s.successMessage == null),
          predicate<PrinterState>((s) =>
              !s.isPrinting && s.successMessage == 'Тестовая печать выполнена' && s.error == null),
        ],
      );

      blocTest<PrinterBloc, PrinterState>(
        'emits a failure error when testPrint returns false (e.g. printer disconnected mid-print)',
        setUp: () {
          when(() => printerService.testPrint()).thenAnswer((_) async => false);
        },
        build: () => PrinterBloc(printerService: printerService),
        act: (bloc) => bloc.add(PrinterTestPrintRequested()),
        expect: () => [
          predicate<PrinterState>((s) => s.isPrinting),
          predicate<PrinterState>((s) => !s.isPrinting && s.error == 'Не удалось напечатать' && s.successMessage == null),
        ],
      );

      blocTest<PrinterBloc, PrinterState>(
        'maps a thrown exception during print to an error message and resets isPrinting',
        setUp: () {
          when(() => printerService.testPrint()).thenThrow(const NetworkException());
        },
        build: () => PrinterBloc(printerService: printerService),
        act: (bloc) => bloc.add(PrinterTestPrintRequested()),
        expect: () => [
          predicate<PrinterState>((s) => s.isPrinting),
          predicate<PrinterState>((s) =>
              !s.isPrinting && s.error == 'Ошибка печати: Нет подключения к интернету' && s.successMessage == null),
        ],
      );

      blocTest<PrinterBloc, PrinterState>(
        'clears a previous success message before starting a new print attempt',
        setUp: () {
          when(() => printerService.testPrint()).thenAnswer((_) async => true);
        },
        build: () => PrinterBloc(printerService: printerService),
        seed: () => const PrinterState(successMessage: 'old success', error: 'old error'),
        act: (bloc) => bloc.add(PrinterTestPrintRequested()),
        expect: () => [
          predicate<PrinterState>((s) => s.isPrinting && s.error == null && s.successMessage == null),
          predicate<PrinterState>((s) => !s.isPrinting && s.successMessage == 'Тестовая печать выполнена'),
        ],
      );
    });

    group('PrinterSetDefaultRequested', () {
      blocTest<PrinterBloc, PrinterState>(
        'persists the default printer and updates state with a success message',
        setUp: () {
          when(() => printerService.setDefaultPrinter(any(), any())).thenAnswer((_) async {});
        },
        build: () => PrinterBloc(printerService: printerService),
        act: (bloc) => bloc.add(const PrinterSetDefaultRequested(name: 'Printer A', address: '00:11:22:33:44:55')),
        expect: () => [
          predicate<PrinterState>((s) =>
              s.defaultPrinterName == 'Printer A' &&
              s.defaultPrinterAddress == '00:11:22:33:44:55' &&
              s.successMessage == 'Принтер по умолчанию: Printer A'),
        ],
        verify: (_) {
          verify(() => printerService.setDefaultPrinter('Printer A', '00:11:22:33:44:55')).called(1);
        },
      );
    });

    group('PrinterLoadDefaultRequested', () {
      blocTest<PrinterBloc, PrinterState>(
        'loads and emits the persisted default printer name/address when both are set',
        setUp: () {
          when(() => printerService.getDefaultPrinterName()).thenAnswer((_) async => 'Printer A');
          when(() => printerService.getDefaultPrinterAddress()).thenAnswer((_) async => '00:11:22:33:44:55');
        },
        build: () => PrinterBloc(printerService: printerService),
        act: (bloc) => bloc.add(PrinterLoadDefaultRequested()),
        expect: () => [
          predicate<PrinterState>((s) =>
              s.defaultPrinterName == 'Printer A' && s.defaultPrinterAddress == '00:11:22:33:44:55'),
        ],
      );

      blocTest<PrinterBloc, PrinterState>(
        'emits nothing when no default printer name is persisted',
        setUp: () {
          when(() => printerService.getDefaultPrinterName()).thenAnswer((_) async => null);
          when(() => printerService.getDefaultPrinterAddress()).thenAnswer((_) async => null);
        },
        build: () => PrinterBloc(printerService: printerService),
        act: (bloc) => bloc.add(PrinterLoadDefaultRequested()),
        expect: () => [],
      );

      blocTest<PrinterBloc, PrinterState>(
        'emits nothing when only the address is persisted but the name is missing',
        setUp: () {
          when(() => printerService.getDefaultPrinterName()).thenAnswer((_) async => null);
          when(() => printerService.getDefaultPrinterAddress()).thenAnswer((_) async => '00:11:22:33:44:55');
        },
        build: () => PrinterBloc(printerService: printerService),
        act: (bloc) => bloc.add(PrinterLoadDefaultRequested()),
        expect: () => [],
      );
    });
  });
}
