import 'package:sqflite/sqflite.dart';
import '../../../core/errors/exceptions.dart';
import '../../../domain/entities/sale.dart';
import '../../../domain/entities/sale_item.dart';

abstract class SaleLocalDatasource {
  Future<List<Sale>> getSales(String storeId);
  Future<Sale?> getSale(String id);
  Future<void> saveSale(Sale sale);
  Future<void> saveSales(List<Sale> sales);
  Future<void> deleteSale(String id);
  Future<void> clearSales(String storeId);
}

class SaleLocalDatasourceImpl implements SaleLocalDatasource {
  final Database _db;

  static const _tableName = 'sales';
  static const _itemsTableName = 'sale_items';

  SaleLocalDatasourceImpl({required Database database}) : _db = database;

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id TEXT PRIMARY KEY,
        store_id TEXT NOT NULL,
        customer_id TEXT,
        customer_name TEXT,
        staff_id TEXT,
        shift_id TEXT,
        receipt_no TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        discount_type TEXT,
        total REAL NOT NULL,
        payment_type TEXT NOT NULL,
        paid_amount REAL NOT NULL,
        change_amount REAL NOT NULL DEFAULT 0,
        debt_amount REAL NOT NULL DEFAULT 0,
        due_date TEXT,
        status TEXT NOT NULL DEFAULT 'COMPLETED',
        notes TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_store_id ON $_tableName (store_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_itemsTableName (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        cost_price REAL,
        discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES $_tableName (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON $_itemsTableName (sale_id)',
    );
  }

  @override
  Future<List<Sale>> getSales(String storeId) async {
    try {
      final rows = await _db.query(
        _tableName,
        where: 'store_id = ?',
        whereArgs: [storeId],
        orderBy: 'created_at DESC',
      );

      final sales = <Sale>[];
      for (final row in rows) {
        final items = await _getSaleItems(row['id'] as String);
        sales.add(_mapRowToSale(row, items));
      }
      return sales;
    } catch (e) {
      throw CacheException('Failed to get local sales: $e');
    }
  }

  @override
  Future<Sale?> getSale(String id) async {
    try {
      final rows = await _db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final items = await _getSaleItems(id);
      return _mapRowToSale(rows.first, items);
    } catch (e) {
      throw CacheException('Failed to get local sale: $e');
    }
  }

  @override
  Future<void> saveSale(Sale sale) async {
    try {
      await _db.transaction((txn) async {
        await txn.insert(
          _tableName,
          _saleToRow(sale),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Delete existing items and re-insert
        await txn.delete(
          _itemsTableName,
          where: 'sale_id = ?',
          whereArgs: [sale.id],
        );

        for (final item in sale.items) {
          await txn.insert(
            _itemsTableName,
            _saleItemToRow(item),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      throw CacheException('Failed to save sale locally: $e');
    }
  }

  @override
  Future<void> saveSales(List<Sale> sales) async {
    try {
      await _db.transaction((txn) async {
        for (final sale in sales) {
          await txn.insert(
            _tableName,
            _saleToRow(sale),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          await txn.delete(
            _itemsTableName,
            where: 'sale_id = ?',
            whereArgs: [sale.id],
          );

          for (final item in sale.items) {
            await txn.insert(
              _itemsTableName,
              _saleItemToRow(item),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });
    } catch (e) {
      throw CacheException('Failed to save sales locally: $e');
    }
  }

  @override
  Future<void> deleteSale(String id) async {
    try {
      await _db.transaction((txn) async {
        await txn.delete(_itemsTableName, where: 'sale_id = ?', whereArgs: [id]);
        await txn.delete(_tableName, where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      throw CacheException('Failed to delete local sale: $e');
    }
  }

  @override
  Future<void> clearSales(String storeId) async {
    try {
      final saleIds = await _db.query(
        _tableName,
        columns: ['id'],
        where: 'store_id = ?',
        whereArgs: [storeId],
      );
      await _db.transaction((txn) async {
        for (final row in saleIds) {
          await txn.delete(
            _itemsTableName,
            where: 'sale_id = ?',
            whereArgs: [row['id']],
          );
        }
        await txn.delete(_tableName, where: 'store_id = ?', whereArgs: [storeId]);
      });
    } catch (e) {
      throw CacheException('Failed to clear local sales: $e');
    }
  }

  Future<List<SaleItem>> _getSaleItems(String saleId) async {
    final rows = await _db.query(
      _itemsTableName,
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return rows.map(_mapRowToSaleItem).toList();
  }

  Map<String, dynamic> _saleToRow(Sale sale) {
    return {
      'id': sale.id,
      'store_id': sale.storeId,
      'customer_id': sale.customerId,
      'customer_name': sale.customerName,
      'staff_id': sale.staffId,
      'shift_id': sale.shiftId,
      'receipt_no': sale.receiptNo,
      'subtotal': sale.subtotal,
      'discount': sale.discount,
      'discount_type': sale.discountType,
      'total': sale.total,
      'payment_type': sale.paymentType,
      'paid_amount': sale.paidAmount,
      'change_amount': sale.change,
      'debt_amount': sale.debtAmount,
      'due_date': sale.dueDate?.toIso8601String(),
      'status': sale.status,
      'notes': sale.notes,
      'created_at': sale.createdAt.toIso8601String(),
      'synced': 0,
    };
  }

  Map<String, dynamic> _saleItemToRow(SaleItem item) {
    return {
      'id': item.id,
      'sale_id': item.saleId,
      'product_id': item.productId,
      'product_name': item.productName,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
      'cost_price': item.costPrice,
      'discount': item.discount,
      'total': item.total,
    };
  }

  Sale _mapRowToSale(Map<String, dynamic> row, List<SaleItem> items) {
    return Sale(
      id: row['id'] as String,
      storeId: row['store_id'] as String,
      customerId: row['customer_id'] as String?,
      customerName: row['customer_name'] as String?,
      staffId: row['staff_id'] as String?,
      shiftId: row['shift_id'] as String?,
      receiptNo: row['receipt_no'] as String,
      subtotal: row['subtotal'] as double,
      discount: (row['discount'] as num?)?.toDouble() ?? 0,
      discountType: row['discount_type'] as String?,
      total: row['total'] as double,
      paymentType: row['payment_type'] as String,
      paidAmount: row['paid_amount'] as double,
      change: (row['change_amount'] as num?)?.toDouble() ?? 0,
      debtAmount: (row['debt_amount'] as num?)?.toDouble() ?? 0,
      dueDate: row['due_date'] != null
          ? DateTime.parse(row['due_date'] as String)
          : null,
      status: row['status'] as String? ?? 'COMPLETED',
      notes: row['notes'] as String?,
      items: items,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  SaleItem _mapRowToSaleItem(Map<String, dynamic> row) {
    return SaleItem(
      id: row['id'] as String,
      saleId: row['sale_id'] as String,
      productId: row['product_id'] as String,
      productName: row['product_name'] as String,
      quantity: row['quantity'] as int,
      unitPrice: row['unit_price'] as double,
      costPrice: row['cost_price'] as double?,
      discount: (row['discount'] as num?)?.toDouble() ?? 0,
      total: row['total'] as double,
    );
  }
}
