// ignore_for_file: depend_on_referenced_packages
//
// path_provider_platform_interface and share_plus_platform_interface are
// transitive dependencies (pulled in by path_provider / share_plus, both of
// which ARE direct deps). We import them directly to install fakes through
// the plugins' own testing seam rather than adding new pubspec dependencies
// or platform-channel mocking infrastructure — see the class docs below.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import 'package:dukonpro/core/services/receipt_pdf_service.dart';
import 'package:dukonpro/core/services/receipt_share_service.dart';
import 'package:dukonpro/domain/entities/sale.dart';
import 'package:dukonpro/domain/entities/sale_item.dart';

class MockReceiptPdfService extends Mock implements ReceiptPdfService {}

/// Returns a real temp directory so `File.writeAsBytes` in the service
/// under test actually succeeds — this is the same `PlatformInterface`
/// extension seam the path_provider package documents for its own tests.
class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

/// Captures the arguments `Share.shareXFiles` is invoked with instead of
/// touching a real platform channel.
class FakeSharePlatform extends SharePlatform {
  List<XFile>? lastFiles;
  String? lastSubject;
  int callCount = 0;
  Object? throwOnShare;

  @override
  Future<ShareResult> shareXFiles(
    List<XFile> files, {
    List<String>? fileNameOverrides,
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
  }) async {
    callCount++;
    if (throwOnShare != null) {
      throw throwOnShare!;
    }
    lastFiles = files;
    lastSubject = subject;
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

void main() {
  late MockReceiptPdfService pdfService;
  late FakeSharePlatform fakeShare;
  late Directory tempDir;
  late ReceiptShareService service;

  final samplePdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]); // "%PDF-"

  Sale buildSale({String receiptNo = 'R-000042'}) {
    return Sale(
      id: 'sale-1',
      storeId: 'store-1',
      receiptNo: receiptNo,
      subtotal: 10,
      total: 10,
      paymentType: 'CASH',
      paidAmount: 10,
      status: 'COMPLETED',
      items: const [
        SaleItem(
          id: 'i1',
          saleId: 'sale-1',
          productId: 'p1',
          productName: 'Хлеб',
          quantity: 1,
          unitPrice: 10,
          total: 10,
        ),
      ],
      createdAt: DateTime.utc(2026, 5, 11, 12, 0),
    );
  }

  setUpAll(() {
    registerFallbackValue(buildSale());
  });

  setUp(() async {
    pdfService = MockReceiptPdfService();
    fakeShare = FakeSharePlatform();
    tempDir = await Directory.systemTemp.createTemp('receipt_share_test_');

    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
    SharePlatform.instance = fakeShare;

    when(() => pdfService.generateReceipt(
          sale: any(named: 'sale'),
          storeName: any(named: 'storeName'),
          storeAddress: any(named: 'storeAddress'),
          storePhone: any(named: 'storePhone'),
        )).thenAnswer((_) async => samplePdfBytes);

    service = ReceiptShareService(pdfService: pdfService);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ReceiptShareService.shareReceipt', () {
    test('generates the PDF via ReceiptPdfService with the given sale and store info',
        () async {
      final sale = buildSale();

      await service.shareReceipt(
        sale: sale,
        storeName: 'Дукон',
        storeAddress: 'ул. Рудаки 1',
        storePhone: '+992901234567',
      );

      verify(() => pdfService.generateReceipt(
            sale: sale,
            storeName: 'Дукон',
            storeAddress: 'ул. Рудаки 1',
            storePhone: '+992901234567',
          )).called(1);
    });

    test('passes null storeAddress/storePhone through unchanged when omitted',
        () async {
      final sale = buildSale();

      await service.shareReceipt(sale: sale, storeName: 'Дукон');

      verify(() => pdfService.generateReceipt(
            sale: sale,
            storeName: 'Дукон',
            storeAddress: null,
            storePhone: null,
          )).called(1);
    });

    test('writes the generated PDF bytes to a temp file named after the receipt number',
        () async {
      final sale = buildSale(receiptNo: 'R-000777');

      await service.shareReceipt(sale: sale, storeName: 'Дукон');

      final expectedFile = File('${tempDir.path}/receipt_R-000777.pdf');
      expect(await expectedFile.exists(), isTrue);
      expect(await expectedFile.readAsBytes(), samplePdfBytes);
    });

    test('invokes the platform share sheet with the written file and a receipt subject',
        () async {
      final sale = buildSale(receiptNo: 'R-000042');

      await service.shareReceipt(sale: sale, storeName: 'Дукон');

      expect(fakeShare.callCount, 1);
      expect(fakeShare.lastSubject, 'Чек R-000042');
      expect(fakeShare.lastFiles, hasLength(1));
      expect(fakeShare.lastFiles!.single.path, '${tempDir.path}/receipt_R-000042.pdf');
      expect(fakeShare.lastFiles!.single.mimeType, 'application/pdf');
    });

    test('propagates an exception from ReceiptPdfService without invoking share',
        () async {
      when(() => pdfService.generateReceipt(
            sale: any(named: 'sale'),
            storeName: any(named: 'storeName'),
            storeAddress: any(named: 'storeAddress'),
            storePhone: any(named: 'storePhone'),
          )).thenThrow(Exception('pdf generation failed'));

      await expectLater(
        service.shareReceipt(sale: buildSale(), storeName: 'Дукон'),
        throwsA(isA<Exception>()),
      );
      expect(fakeShare.callCount, 0);
    });

    test('propagates an exception raised by the platform share sheet', () async {
      fakeShare.throwOnShare = Exception('share sheet unavailable');

      await expectLater(
        service.shareReceipt(sale: buildSale(), storeName: 'Дукон'),
        throwsA(isA<Exception>()),
      );
    });

    test('produces distinct file names for different receipts, avoiding collisions',
        () async {
      await service.shareReceipt(sale: buildSale(receiptNo: 'R-1'), storeName: 'A');
      await service.shareReceipt(sale: buildSale(receiptNo: 'R-2'), storeName: 'A');

      expect(await File('${tempDir.path}/receipt_R-1.pdf').exists(), isTrue);
      expect(await File('${tempDir.path}/receipt_R-2.pdf').exists(), isTrue);
    });
  });
}
