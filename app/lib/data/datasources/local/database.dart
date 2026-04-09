import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;

  AppDatabase._internal();

  factory AppDatabase() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/dokonpro.db';

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // --- Users table ---
    batch.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        phone TEXT NOT NULL,
        name TEXT NOT NULL,
        email TEXT,
        avatar TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // --- Stores table ---
    batch.execute('''
      CREATE TABLE stores (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'TJS',
        address TEXT,
        phone TEXT,
        logo_url TEXT,
        settings TEXT NOT NULL DEFAULT '{}',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_stores_owner_id ON stores (owner_id)',
    );

    // --- Categories table ---
    batch.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        store_id TEXT NOT NULL,
        name TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        parent_id TEXT,
        product_count INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (store_id) REFERENCES stores (id) ON DELETE CASCADE
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_categories_store_id ON categories (store_id)',
    );
    batch.execute(
      'CREATE INDEX idx_categories_parent_id ON categories (parent_id)',
    );

    // --- Products table ---
    batch.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        store_id TEXT NOT NULL,
        category_id TEXT,
        category_name TEXT,
        supplier_id TEXT,
        name TEXT NOT NULL,
        sku TEXT,
        barcode TEXT,
        description TEXT,
        cost_price REAL,
        sell_price REAL NOT NULL,
        wholesale_price REAL,
        quantity INTEGER NOT NULL DEFAULT 0,
        min_quantity INTEGER NOT NULL DEFAULT 0,
        unit TEXT NOT NULL DEFAULT 'PCS',
        image_url TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (store_id) REFERENCES stores (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE SET NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_products_store_id ON products (store_id)',
    );
    batch.execute(
      'CREATE INDEX idx_products_category_id ON products (category_id)',
    );
    batch.execute(
      'CREATE INDEX idx_products_supplier_id ON products (supplier_id)',
    );
    batch.execute(
      'CREATE INDEX idx_products_barcode ON products (barcode)',
    );
    batch.execute(
      'CREATE INDEX idx_products_sku ON products (sku)',
    );

    // --- Customers table ---
    batch.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        store_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        birthday TEXT,
        notes TEXT,
        loyalty_points INTEGER NOT NULL DEFAULT 0,
        total_spent REAL NOT NULL DEFAULT 0,
        debt REAL NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (store_id) REFERENCES stores (id) ON DELETE CASCADE
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_customers_store_id ON customers (store_id)',
    );
    batch.execute(
      'CREATE INDEX idx_customers_phone ON customers (phone)',
    );

    // --- Suppliers table ---
    batch.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        store_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        debt REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (store_id) REFERENCES stores (id) ON DELETE CASCADE
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_suppliers_store_id ON suppliers (store_id)',
    );

    // --- Sales table ---
    batch.execute('''
      CREATE TABLE sales (
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
        FOREIGN KEY (store_id) REFERENCES stores (id) ON DELETE CASCADE,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_sales_store_id ON sales (store_id)',
    );
    batch.execute(
      'CREATE INDEX idx_sales_customer_id ON sales (customer_id)',
    );
    batch.execute(
      'CREATE INDEX idx_sales_created_at ON sales (created_at)',
    );
    batch.execute(
      'CREATE INDEX idx_sales_receipt_no ON sales (receipt_no)',
    );
    batch.execute(
      'CREATE INDEX idx_sales_status ON sales (status)',
    );

    // --- Sale Items table ---
    batch.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        cost_price REAL,
        discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_sale_items_sale_id ON sale_items (sale_id)',
    );
    batch.execute(
      'CREATE INDEX idx_sale_items_product_id ON sale_items (product_id)',
    );

    // --- Stock Movements table ---
    batch.execute('''
      CREATE TABLE stock_movements (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_cost REAL,
        total_cost REAL,
        supplier_id TEXT,
        reference TEXT,
        notes TEXT,
        created_by TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE SET NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_stock_movements_product_id ON stock_movements (product_id)',
    );
    batch.execute(
      'CREATE INDEX idx_stock_movements_type ON stock_movements (type)',
    );
    batch.execute(
      'CREATE INDEX idx_stock_movements_created_at ON stock_movements (created_at)',
    );

    // --- Auth Tokens table ---
    batch.execute('''
      CREATE TABLE auth_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        access_token TEXT NOT NULL,
        refresh_token TEXT NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
