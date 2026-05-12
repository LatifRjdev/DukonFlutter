import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import '../../domain/entities/sale.dart';
import '../utils/formatters.dart';
import '../utils/cp1251_codec.dart';

class ThermalPrinterService {
  BluetoothDevice? _connectedDevice;

  bool get isConnected => BluetoothPrintPlus.isConnected;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  Future<List<BluetoothDevice>> scanDevices() async {
    final devices = <BluetoothDevice>[];
    final subscription = BluetoothPrintPlus.scanResults.listen((list) {
      devices
        ..clear()
        ..addAll(list);
    });
    await BluetoothPrintPlus.startScan(timeout: const Duration(seconds: 4));
    await Future.delayed(const Duration(seconds: 4));
    await BluetoothPrintPlus.stopScan();
    await subscription.cancel();
    return List<BluetoothDevice>.from(devices);
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      await BluetoothPrintPlus.connect(device);
      // Wait briefly for connectState to flip.
      await Future.delayed(const Duration(milliseconds: 800));
      _connectedDevice = device;
      return BluetoothPrintPlus.isConnected;
    } catch (e) {
      debugPrint('Bluetooth connect failed: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await BluetoothPrintPlus.disconnect();
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
    if (!BluetoothPrintPlus.isConnected) return false;

    try {
      final bytes = await _buildReceiptBytes(
        sale: sale,
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        paperWidth: paperWidth,
      );

      await BluetoothPrintPlus.write(Uint8List.fromList(bytes));
      return BluetoothPrintPlus.isConnected;
    } catch (e) {
      return false;
    }
  }

  Future<bool> testPrint() async {
    if (!BluetoothPrintPlus.isConnected) return false;

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      generator.setGlobalCodeTable('CP1251');
      var bytes = <int>[];
      bytes += generator.text('DukonPro - Test Print',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('Printer is working!',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(Formatters.dateTime(DateTime.now()),
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(2);
      bytes += generator.cut();

      await BluetoothPrintPlus.write(Uint8List.fromList(bytes));
      return BluetoothPrintPlus.isConnected;
    } catch (e) {
      return false;
    }
  }

  /// Public for tests. The print path itself is BLE-bound and not
  /// hermetically testable without a real printer, but the byte
  /// stream we hand to the printer IS deterministic, so the test
  /// suite (deferred #4) builds bytes for representative sales and
  /// asserts shape — codepage selection, line wrapping, totals are
  /// present. Production code should keep calling printReceipt().
  @visibleForTesting
  Future<List<int>> buildReceiptBytesForTest({
    required Sale sale,
    required String storeName,
    String? storeAddress,
    String? storePhone,
    int paperWidth = 80,
  }) =>
      _buildReceiptBytes(
        sale: sale,
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        paperWidth: paperWidth,
      );

  Future<List<int>> _buildReceiptBytes({
    required Sale sale,
    required String storeName,
    String? storeAddress,
    String? storePhone,
    int paperWidth = 80,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paperSize, profile, codec: cp1251);
    // Tells the printer hardware to use CP1251 character table.
    generator.setGlobalCodeTable('CP1251');
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
