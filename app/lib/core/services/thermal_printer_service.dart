import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_printer/thermal_printer.dart';
import 'package:thermal_printer/esc_pos_utils_platform/esc_pos_utils_platform.dart';
import '../../domain/entities/sale.dart';
import '../utils/formatters.dart';

class ThermalPrinterService {
  PrinterDevice? _connectedDevice;

  bool get isConnected => _connectedDevice != null;
  PrinterDevice? get connectedDevice => _connectedDevice;

  Future<List<PrinterDevice>> scanDevices() async {
    final devices = <PrinterDevice>[];
    final subscription = PrinterManager.instance
        .discovery(type: PrinterType.bluetooth)
        .listen((device) {
      devices.add(device);
    });

    await Future.delayed(const Duration(seconds: 4));
    await subscription.cancel();
    return devices;
  }

  Future<bool> connect(PrinterDevice device) async {
    try {
      await PrinterManager.instance.connect(
        type: PrinterType.bluetooth,
        model: BluetoothPrinterInput(
          name: device.name,
          address: device.address ?? '',
          autoConnect: true,
        ),
      );
      _connectedDevice = device;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await PrinterManager.instance.disconnect(type: PrinterType.bluetooth);
    } catch (_) {}
    _connectedDevice = null;
  }

  Future<bool> printReceipt({
    required Sale sale,
    required String storeName,
    String? storeAddress,
    String? storePhone,
    int paperWidth = 80,
  }) async {
    if (_connectedDevice == null) return false;

    try {
      final bytes = await _buildReceiptBytes(
        sale: sale,
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        paperWidth: paperWidth,
      );

      await PrinterManager.instance.send(type: PrinterType.bluetooth, bytes: bytes);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> testPrint() async {
    if (_connectedDevice == null) return false;

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      var bytes = <int>[];
      bytes += generator.text('DuckonPro - Test Print',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('Printer is working!',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(Formatters.dateTime(DateTime.now()),
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(2);
      bytes += generator.cut();

      await PrinterManager.instance.send(type: PrinterType.bluetooth, bytes: bytes);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<int>> _buildReceiptBytes({
    required Sale sale,
    required String storeName,
    String? storeAddress,
    String? storePhone,
    int paperWidth = 80,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paperSize, profile);
    var bytes = <int>[];

    bytes += generator.text(storeName,
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    if (storeAddress != null) {
      bytes += generator.text(storeAddress, styles: const PosStyles(align: PosAlign.center));
    }
    if (storePhone != null) {
      bytes += generator.text(storePhone, styles: const PosStyles(align: PosAlign.center));
    }
    bytes += generator.feed(1);

    bytes += generator.text('#${sale.receiptNo}', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text(Formatters.dateTime(sale.createdAt), styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr(ch: '-');

    bytes += generator.row([
      PosColumn(text: 'Товар', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Кол', width: 2, styles: const PosStyles(bold: true, align: PosAlign.center)),
      PosColumn(text: 'Сумма', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);

    for (final item in sale.items) {
      final name = item.productName.length > 16 ? item.productName.substring(0, 16) : item.productName;
      bytes += generator.row([
        PosColumn(text: name, width: 6),
        PosColumn(text: '${item.quantity}', width: 2, styles: const PosStyles(align: PosAlign.center)),
        PosColumn(text: item.total.toStringAsFixed(2), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr(ch: '-');
    bytes += generator.row([
      PosColumn(text: 'Подытог', width: 6),
      PosColumn(text: Formatters.price(sale.subtotal), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    if (sale.discount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Скидка', width: 6),
        PosColumn(text: '- ${Formatters.price(sale.discount)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.row([
      PosColumn(text: 'ИТОГО', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(text: Formatters.price(sale.total), width: 6,
          styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2)),
    ]);
    bytes += generator.hr(ch: '-');

    bytes += generator.row([
      PosColumn(text: 'Оплата', width: 6),
      PosColumn(text: _paymentTypeName(sale.paymentType), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Оплачено', width: 6),
      PosColumn(text: Formatters.price(sale.paidAmount), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    if (sale.change > 0) {
      bytes += generator.row([
        PosColumn(text: 'Сдача', width: 6),
        PosColumn(text: Formatters.price(sale.change), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.feed(1);
    bytes += generator.text('Спасибо за покупку!', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  String _paymentTypeName(String type) {
    switch (type) {
      case 'CASH': return 'Наличные';
      case 'CARD': return 'Карта';
      case 'DEBT': return 'В долг';
      case 'MIXED': return 'Смешанная';
      default: return type;
    }
  }

  Future<String?> getDefaultPrinterAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('default_printer_address');
  }

  Future<String?> getDefaultPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('default_printer_name');
  }

  Future<void> setDefaultPrinter(String name, String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_printer_name', name);
    await prefs.setString('default_printer_address', address);
  }
}
