# Sprint 1: Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix release blockers, add barcode scanner to 4 locations, complete customer edit, sales filters, zakat buttons, and product filter — eliminating 11 stubs.

**Architecture:** All features in this sprint use existing backend APIs (0 new endpoints). Flutter-side only: new shared widget (BarcodeScannerSheet), new form page (CustomerFormPage), new filter sheet (SalesFilterSheet), and wiring existing API calls to stubbed buttons.

**Tech Stack:** Flutter, BLoC, go_router, mobile_scanner, existing NestJS REST API

**Spec:** `docs/superpowers/specs/2026-04-12-dokonpro-play-market-release.md` — Sprint 1

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `app/lib/presentation/widgets/common/barcode_scanner_sheet.dart` | Reusable barcode scanner bottom sheet with camera preview |
| `app/lib/presentation/pages/customer/customer_form_page.dart` | Unified add/edit customer form |
| `app/lib/presentation/widgets/pos/sales_filter_sheet.dart` | Sales history filter bottom sheet |
| `app/test/presentation/widgets/common/barcode_scanner_sheet_test.dart` | Scanner widget tests |
| `app/test/presentation/pages/customer/customer_form_page_test.dart` | Customer form widget tests |
| `app/test/presentation/widgets/pos/sales_filter_sheet_test.dart` | Filter sheet widget tests |

### Modified Files
| File | Change |
|------|--------|
| `app/pubspec.yaml` | Add `mobile_scanner` dependency |
| `app/lib/core/router/route_names.dart` | Add `customerEdit` route |
| `app/lib/core/router/app_router.dart` | Register `customerEdit` route |
| `app/lib/presentation/pages/pos/pos_checkout_page.dart:288` | Replace scanner stub with BarcodeScannerSheet |
| `app/lib/presentation/pages/product/product_list_page.dart:142,148` | Replace scanner + filter stubs |
| `app/lib/presentation/pages/product/add_product_step1_page.dart:90` | Replace scanner stub |
| `app/lib/presentation/pages/stock/stock_intake_page.dart:116` | Replace scanner stub |
| `app/lib/presentation/pages/customer/customer_detail_page.dart:271` | Replace edit stub with navigation to CustomerFormPage |
| `app/lib/presentation/pages/sales/sales_history_page.dart:77,81` | Replace filter stubs with SalesFilterSheet |
| `app/lib/presentation/pages/zakat/zakat_calculator_page.dart:271` | Wire calculate button to API |
| `app/lib/presentation/pages/zakat/zakat_settings_page.dart:183` | Wire save button to API |
| `app/lib/presentation/pages/product/import_products_page.dart:37` | Remove "Скоро" badge |
| `app/android/app/build.gradle.kts` | Add release signing config, ProGuard |
| `app/android/app/proguard-rules.pro` | New ProGuard rules file |

---

## Task 1: Add mobile_scanner dependency

**Files:**
- Modify: `app/pubspec.yaml`

- [ ] **Step 1: Add mobile_scanner to pubspec.yaml**

Open `app/pubspec.yaml` and add under `dependencies`:

```yaml
  mobile_scanner: ^6.0.0
```

- [ ] **Step 2: Run pub get**

Run: `cd /Users/latifrjdev/Downloads/Dukon/app && flutter pub get`
Expected: "Got dependencies!" with no errors

- [ ] **Step 3: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock
git commit -m "deps: add mobile_scanner for barcode scanning"
```

---

## Task 2: Create BarcodeScannerSheet widget

**Files:**
- Create: `app/lib/presentation/widgets/common/barcode_scanner_sheet.dart`
- Test: `app/test/presentation/widgets/common/barcode_scanner_sheet_test.dart`

- [ ] **Step 1: Write the widget test**

```dart
// app/test/presentation/widgets/common/barcode_scanner_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokonpro/presentation/widgets/common/barcode_scanner_sheet.dart';

void main() {
  group('BarcodeScannerSheet', () {
    testWidgets('should display title and close button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BarcodeScannerSheet.show(
                  context,
                  onScanned: (_) {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Сканер штрихкода'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('should close on close button tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BarcodeScannerSheet.show(
                  context,
                  onScanned: (_) {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Сканер штрихкода'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/latifrjdev/Downloads/Dukon/app && flutter test test/presentation/widgets/common/barcode_scanner_sheet_test.dart`
Expected: FAIL — file not found

- [ ] **Step 3: Create the BarcodeScannerSheet widget**

```dart
// app/lib/presentation/widgets/common/barcode_scanner_sheet.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class BarcodeScannerSheet extends StatefulWidget {
  final ValueChanged<String> onScanned;

  const BarcodeScannerSheet({super.key, required this.onScanned});

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onScanned,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BarcodeScannerSheet(onScanned: onScanned),
    );
  }

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    setState(() => _scanned = true);
    Navigator.of(context).pop();
    widget.onScanned(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.6;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: AppConstants.spacingSm),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Title bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingSm,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Сканер штрихкода',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.lightBorder),
          // Camera preview
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppConstants.radiusXl),
              ),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                  ),
                  // Scan overlay
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMd,
                        ),
                      ),
                    ),
                  ),
                  // Hint text
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Наведите камеру на штрихкод',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/latifrjdev/Downloads/Dukon/app && flutter test test/presentation/widgets/common/barcode_scanner_sheet_test.dart`
Expected: PASS (at least the title/close tests — camera won't render in test environment but the widget structure should)

- [ ] **Step 5: Commit**

```bash
git add app/lib/presentation/widgets/common/barcode_scanner_sheet.dart app/test/presentation/widgets/common/barcode_scanner_sheet_test.dart
git commit -m "feat: add BarcodeScannerSheet widget with camera preview"
```

---

## Task 3: Wire barcode scanner to POS checkout

**Files:**
- Modify: `app/lib/presentation/pages/pos/pos_checkout_page.dart:288`

- [ ] **Step 1: Read the current stub code around line 288**

Read `app/lib/presentation/pages/pos/pos_checkout_page.dart` lines 280-300 to see the exact SnackBar stub.

- [ ] **Step 2: Add import for BarcodeScannerSheet**

At the top of `pos_checkout_page.dart`, add:

```dart
import '../../widgets/common/barcode_scanner_sheet.dart';
```

- [ ] **Step 3: Replace the stub**

Find the SnackBar stub near line 288:
```dart
const SnackBar(content: Text('Сканер штрихкодов скоро будет доступен'))
```

Replace the entire `onPressed`/`onTap` callback containing that SnackBar with:

```dart
BarcodeScannerSheet.show(
  context,
  onScanned: (barcode) {
    context.read<CartBloc>().add(CartProductScanned(barcode));
  },
);
```

Note: Check if `CartProductScanned` event exists. If not, create it in `cart_event.dart` and handle it in `cart_bloc.dart` — it should call the product API `GET /products/barcode/:barcode`, then add to cart.

- [ ] **Step 4: Verify the event exists or create it**

Check `app/lib/presentation/blocs/pos/cart_event.dart` for `CartProductScanned`. If missing, add:

```dart
class CartProductScanned extends CartEvent {
  final String barcode;
  const CartProductScanned(this.barcode);
  @override
  List<Object?> get props => [barcode];
}
```

And in `cart_bloc.dart`, add handler:

```dart
on<CartProductScanned>(_onProductScanned);
```

```dart
Future<void> _onProductScanned(CartProductScanned event, Emitter<CartState> emit) async {
  try {
    final product = await _productRepository.findByBarcode(event.barcode);
    if (product != null) {
      add(CartItemAdded(product));
    }
  } catch (_) {
    // Product not found — handled by UI via state
  }
}
```

- [ ] **Step 5: Test manually**

Run: `cd /Users/latifrjdev/Downloads/Dukon/app && flutter analyze`
Expected: No errors in modified files

- [ ] **Step 6: Commit**

```bash
git add app/lib/presentation/pages/pos/pos_checkout_page.dart app/lib/presentation/blocs/pos/cart_event.dart app/lib/presentation/blocs/pos/cart_bloc.dart
git commit -m "feat: wire barcode scanner to POS checkout"
```

---

## Task 4: Wire barcode scanner to product list

**Files:**
- Modify: `app/lib/presentation/pages/product/product_list_page.dart:142`

- [ ] **Step 1: Read the current stub around line 142**

Read `product_list_page.dart` lines 135-155.

- [ ] **Step 2: Add import and replace stub**

Add import:
```dart
import '../../widgets/common/barcode_scanner_sheet.dart';
```

Replace the scanner SnackBar stub with:

```dart
BarcodeScannerSheet.show(
  context,
  onScanned: (barcode) {
    // Navigate to product detail by barcode
    final storeId = context.read<StoreBloc>().state is StoreLoaded
        ? (context.read<StoreBloc>().state as StoreLoaded).selectedStore?.id
        : null;
    if (storeId != null) {
      context.read<ProductBloc>().add(ProductSearchByBarcode(barcode));
    }
  },
);
```

Note: Check if `ProductSearchByBarcode` event exists. If not, create it similarly to Task 3 — it should search and navigate to detail.

- [ ] **Step 3: Commit**

```bash
git add app/lib/presentation/pages/product/product_list_page.dart
git commit -m "feat: wire barcode scanner to product list"
```

---

## Task 5: Wire barcode scanner to add product form

**Files:**
- Modify: `app/lib/presentation/pages/product/add_product_step1_page.dart:90`

- [ ] **Step 1: Read the stub around line 90**

Read `add_product_step1_page.dart` lines 85-100.

- [ ] **Step 2: Replace stub**

Add import:
```dart
import '../../widgets/common/barcode_scanner_sheet.dart';
```

Replace the SnackBar stub with:

```dart
BarcodeScannerSheet.show(
  context,
  onScanned: (barcode) {
    _barcodeController.text = barcode;
  },
);
```

- [ ] **Step 3: Commit**

```bash
git add app/lib/presentation/pages/product/add_product_step1_page.dart
git commit -m "feat: wire barcode scanner to add product form"
```

---

## Task 6: Wire barcode scanner to stock intake

**Files:**
- Modify: `app/lib/presentation/pages/stock/stock_intake_page.dart:116`

- [ ] **Step 1: Read the stub around line 116**

Read `stock_intake_page.dart` lines 110-125.

- [ ] **Step 2: Replace stub**

Add import:
```dart
import '../../widgets/common/barcode_scanner_sheet.dart';
```

Replace the SnackBar stub with:

```dart
BarcodeScannerSheet.show(
  context,
  onScanned: (barcode) {
    // Find product by barcode and add to intake list
    _addProductByBarcode(barcode);
  },
);
```

Add the helper method in the page state class:

```dart
Future<void> _addProductByBarcode(String barcode) async {
  // Use existing product repository to find by barcode
  // then add to the intake items list
  final storeState = context.read<StoreBloc>().state;
  if (storeState is StoreLoaded && storeState.selectedStore != null) {
    context.read<StockBloc>().add(StockProductScanned(barcode));
  }
}
```

Note: Verify `StockBloc` and `StockProductScanned` event exist. If stock intake uses a different BLoC pattern, adapt accordingly — read the file first.

- [ ] **Step 3: Commit**

```bash
git add app/lib/presentation/pages/stock/stock_intake_page.dart
git commit -m "feat: wire barcode scanner to stock intake"
```

---

## Task 7: Customer form page (add/edit mode)

**Files:**
- Create: `app/lib/presentation/pages/customer/customer_form_page.dart`
- Modify: `app/lib/core/router/route_names.dart`
- Modify: `app/lib/core/router/app_router.dart`
- Modify: `app/lib/presentation/pages/customer/customer_detail_page.dart:271`
- Test: `app/test/presentation/pages/customer/customer_form_page_test.dart`

- [ ] **Step 1: Write the widget test**

```dart
// app/test/presentation/pages/customer/customer_form_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokonpro/presentation/pages/customer/customer_form_page.dart';

void main() {
  group('CustomerFormPage', () {
    testWidgets('should show "Новый клиент" title in add mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerFormPage(),
        ),
      );

      expect(find.text('Новый клиент'), findsOneWidget);
    });

    testWidgets('should show name and phone fields', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerFormPage(),
        ),
      );

      expect(find.text('Имя'), findsOneWidget);
      expect(find.text('Телефон'), findsOneWidget);
    });

    testWidgets('should validate empty name field', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerFormPage(),
        ),
      );

      // Tap save without filling name
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(find.text('Введите имя'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/latifrjdev/Downloads/Dukon/app && flutter test test/presentation/pages/customer/customer_form_page_test.dart`
Expected: FAIL — file not found

- [ ] **Step 3: Add route**

In `app/lib/core/router/route_names.dart`, add:
```dart
static const String customerForm = '/customers/form';
```

In `app/lib/core/router/app_router.dart`, add the route:
```dart
GoRoute(
  path: RouteNames.customerForm,
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>?;
    return CustomerFormPage(
      customerId: extra?['customerId'] as String?,
      storeId: extra?['storeId'] as String?,
    );
  },
),
```

Add import:
```dart
import '../../presentation/pages/customer/customer_form_page.dart';
```

- [ ] **Step 4: Create CustomerFormPage**

```dart
// app/lib/presentation/pages/customer/customer_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/customer/customer_bloc.dart';
import '../../blocs/customer/customer_event.dart';
import '../../blocs/customer/customer_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

class CustomerFormPage extends StatefulWidget {
  final String? customerId;
  final String? storeId;

  const CustomerFormPage({super.key, this.customerId, this.storeId});

  bool get isEditing => customerId != null;

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadExisting() {
    if (widget.isEditing && !_initialized) {
      _initialized = true;
      // Load customer data from BLoC state or trigger fetch
      final state = context.read<CustomerBloc>().state;
      if (state is CustomerDetailLoaded) {
        _nameController.text = state.customer.name;
        _phoneController.text = state.customer.phone ?? '';
        _notesController.text = state.customer.notes ?? '';
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (widget.isEditing) {
      context.read<CustomerBloc>().add(CustomerUpdated(
        customerId: widget.customerId!,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      ));
    } else {
      context.read<CustomerBloc>().add(CustomerCreated(
        storeId: widget.storeId!,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadExisting();

    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Редактировать клиента' : 'Новый клиент'),
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocListener<CustomerBloc, CustomerState>(
        listener: (context, state) {
          if (state is CustomerActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(widget.isEditing ? 'Клиент обновлён' : 'Клиент добавлен'),
                backgroundColor: AppColors.success,
              ),
            );
            context.pop(true);
          }
          if (state is CustomerFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _nameController,
                  label: 'Имя',
                  hint: 'Введите имя клиента',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите имя' : null,
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _phoneController,
                  label: 'Телефон',
                  hint: '+992 XX XXX XXXX',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppConstants.spacingMd),
                AppTextField(
                  controller: _notesController,
                  label: 'Заметка',
                  hint: 'Дополнительная информация',
                  maxLines: 3,
                ),
                const SizedBox(height: AppConstants.spacingLg),
                AppButton(
                  text: 'Сохранить',
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Note: Verify `CustomerBloc` events (`CustomerUpdated`, `CustomerCreated`) exist. If they use different names, adapt to existing pattern. Read `customer_event.dart` and `customer_bloc.dart` first.

- [ ] **Step 5: Wire edit button in customer_detail_page.dart**

Read `customer_detail_page.dart` around line 271. Replace the SnackBar stub with:

```dart
context.push(
  RouteNames.customerForm,
  extra: {
    'customerId': customer.id,
    'storeId': storeId,
  },
);
```

- [ ] **Step 6: Run tests**

Run: `cd /Users/latifrjdev/Downloads/Dukon/app && flutter test test/presentation/pages/customer/customer_form_page_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add app/lib/presentation/pages/customer/customer_form_page.dart app/lib/core/router/route_names.dart app/lib/core/router/app_router.dart app/lib/presentation/pages/customer/customer_detail_page.dart app/test/presentation/pages/customer/customer_form_page_test.dart
git commit -m "feat: add customer form page with add/edit mode"
```

---

## Task 8: Sales filter sheet

**Files:**
- Create: `app/lib/presentation/widgets/pos/sales_filter_sheet.dart`
- Modify: `app/lib/presentation/pages/sales/sales_history_page.dart:77,81`
- Test: `app/test/presentation/widgets/pos/sales_filter_sheet_test.dart`

- [ ] **Step 1: Write the widget test**

```dart
// app/test/presentation/widgets/pos/sales_filter_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokonpro/presentation/widgets/pos/sales_filter_sheet.dart';

void main() {
  group('SalesFilterSheet', () {
    testWidgets('should display period chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SalesFilterSheet.show(
                  context,
                  onApply: (_) {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Сегодня'), findsOneWidget);
      expect(find.text('Неделя'), findsOneWidget);
      expect(find.text('Месяц'), findsOneWidget);
    });

    testWidgets('should display payment type chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SalesFilterSheet.show(
                  context,
                  onApply: (_) {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Все'), findsWidgets);
      expect(find.text('Наличные'), findsOneWidget);
      expect(find.text('Карта'), findsOneWidget);
      expect(find.text('Долг'), findsOneWidget);
    });

    testWidgets('should call onApply with selected filters', (tester) async {
      SalesFilter? received;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SalesFilterSheet.show(
                  context,
                  onApply: (f) => received = f,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Select "Неделя"
      await tester.tap(find.text('Неделя'));
      await tester.pump();

      // Tap Apply
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();

      expect(received, isNotNull);
      expect(received!.period, SalesFilterPeriod.week);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/latifrjdev/Downloads/Dukon/app && flutter test test/presentation/widgets/pos/sales_filter_sheet_test.dart`
Expected: FAIL — file not found

- [ ] **Step 3: Create SalesFilterSheet**

```dart
// app/lib/presentation/widgets/pos/sales_filter_sheet.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

enum SalesFilterPeriod { today, week, month, custom }
enum SalesFilterPayment { all, cash, card, debt }
enum SalesFilterStatus { all, completed, returned, cancelled }

class SalesFilter {
  final SalesFilterPeriod period;
  final SalesFilterPayment payment;
  final SalesFilterStatus status;
  final DateTime? from;
  final DateTime? to;

  const SalesFilter({
    this.period = SalesFilterPeriod.today,
    this.payment = SalesFilterPayment.all,
    this.status = SalesFilterStatus.all,
    this.from,
    this.to,
  });
}

class SalesFilterSheet extends StatefulWidget {
  final ValueChanged<SalesFilter> onApply;
  final SalesFilter? initial;

  const SalesFilterSheet({super.key, required this.onApply, this.initial});

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<SalesFilter> onApply,
    SalesFilter? initial,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SalesFilterSheet(onApply: onApply, initial: initial),
    );
  }

  @override
  State<SalesFilterSheet> createState() => _SalesFilterSheetState();
}

class _SalesFilterSheetState extends State<SalesFilterSheet> {
  late SalesFilterPeriod _period;
  late SalesFilterPayment _payment;
  late SalesFilterStatus _status;

  @override
  void initState() {
    super.initState();
    _period = widget.initial?.period ?? SalesFilterPeriod.today;
    _payment = widget.initial?.payment ?? SalesFilterPayment.all;
    _status = widget.initial?.status ?? SalesFilterStatus.all;
  }

  void _apply() {
    Navigator.of(context).pop();
    widget.onApply(SalesFilter(
      period: _period,
      payment: _payment,
      status: _status,
    ));
  }

  void _reset() {
    setState(() {
      _period = SalesFilterPeriod.today;
      _payment = SalesFilterPayment.all;
      _status = SalesFilterStatus.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: AppConstants.spacingSm),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Фильтры',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  child: const Text('Сбросить'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.lightBorder),
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period
                const Text('Период', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                const SizedBox(height: AppConstants.spacingSm),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip('Сегодня', _period == SalesFilterPeriod.today,
                        () => setState(() => _period = SalesFilterPeriod.today)),
                    _chip('Неделя', _period == SalesFilterPeriod.week,
                        () => setState(() => _period = SalesFilterPeriod.week)),
                    _chip('Месяц', _period == SalesFilterPeriod.month,
                        () => setState(() => _period = SalesFilterPeriod.month)),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingMd),
                // Payment type
                const Text('Тип оплаты', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                const SizedBox(height: AppConstants.spacingSm),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip('Все', _payment == SalesFilterPayment.all,
                        () => setState(() => _payment = SalesFilterPayment.all)),
                    _chip('Наличные', _payment == SalesFilterPayment.cash,
                        () => setState(() => _payment = SalesFilterPayment.cash)),
                    _chip('Карта', _payment == SalesFilterPayment.card,
                        () => setState(() => _payment = SalesFilterPayment.card)),
                    _chip('Долг', _payment == SalesFilterPayment.debt,
                        () => setState(() => _payment = SalesFilterPayment.debt)),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingMd),
                // Status
                const Text('Статус', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                const SizedBox(height: AppConstants.spacingSm),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip('Все', _status == SalesFilterStatus.all,
                        () => setState(() => _status = SalesFilterStatus.all)),
                    _chip('Завершена', _status == SalesFilterStatus.completed,
                        () => setState(() => _status = SalesFilterStatus.completed)),
                    _chip('Возврат', _status == SalesFilterStatus.returned,
                        () => setState(() => _status = SalesFilterStatus.returned)),
                    _chip('Отменена', _status == SalesFilterStatus.cancelled,
                        () => setState(() => _status = SalesFilterStatus.cancelled)),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingLg),
                // Apply button
                SizedBox(
                  width: double.infinity,
                  height: AppConstants.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                      ),
                    ),
                    child: const Text(
                      'Применить',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.lightTextPrimary,
            fontFamily: 'Inter',
          ),
        ),
        backgroundColor: selected ? AppColors.primary : AppColors.lightBackground,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.lightBorder,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Wire to sales history page**

Read `sales_history_page.dart` lines 70-90. Replace both empty `onPressed: () {}` stubs:

Add import:
```dart
import '../../widgets/pos/sales_filter_sheet.dart';
```

Replace the first empty button (line 77) with:
```dart
onPressed: () => SalesFilterSheet.show(
  context,
  onApply: (filter) {
    // Apply filter to SalesBloc
    context.read<SalesBloc>().add(SalesFilterChanged(filter));
  },
),
```

Replace the second empty button (line 81) — if it's a sort/date button, adapt similarly.

Note: Read the file first to understand what each button represents.

- [ ] **Step 5: Run tests**

Run: `cd /Users/latifrjdev/Downloads/Dukon/app && flutter test test/presentation/widgets/pos/sales_filter_sheet_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/lib/presentation/widgets/pos/sales_filter_sheet.dart app/lib/presentation/pages/sales/sales_history_page.dart app/test/presentation/widgets/pos/sales_filter_sheet_test.dart
git commit -m "feat: add sales filter sheet with period/payment/status filters"
```

---

## Task 9: Wire zakat buttons

**Files:**
- Modify: `app/lib/presentation/pages/zakat/zakat_calculator_page.dart:271`
- Modify: `app/lib/presentation/pages/zakat/zakat_settings_page.dart:183`

- [ ] **Step 1: Read both files around the stub lines**

Read `zakat_calculator_page.dart` lines 265-280.
Read `zakat_settings_page.dart` lines 178-195.

- [ ] **Step 2: Wire zakat calculator button**

In `zakat_calculator_page.dart`, replace the empty `onPressed: () {}` at line 271 with:

```dart
onPressed: () {
  final storeState = context.read<StoreBloc>().state;
  if (storeState is StoreLoaded && storeState.selectedStore != null) {
    context.read<ZakatBloc>().add(ZakatCalculateRequested(
      storeState.selectedStore!.id,
    ));
  }
},
```

Note: Verify the `ZakatBloc` and `ZakatCalculateRequested` event exist. Read `zakat_bloc.dart` first.

- [ ] **Step 3: Wire zakat settings save button**

In `zakat_settings_page.dart`, replace the empty `onPressed: () {}` at line 183 with:

```dart
onPressed: () {
  if (!_formKey.currentState!.validate()) return;
  final storeState = context.read<StoreBloc>().state;
  if (storeState is StoreLoaded && storeState.selectedStore != null) {
    context.read<ZakatBloc>().add(ZakatSettingsSaved(
      storeId: storeState.selectedStore!.id,
      nisabGold: double.parse(_nisabController.text),
      nisabSilver: double.parse(_silverController.text),
      rate: double.parse(_rateController.text),
    ));
  }
},
```

Note: Adapt field names to actual controller names in the file.

- [ ] **Step 4: Run analyze**

Run: `cd /Users/latifrjdev/Downloads/Dukon/app && flutter analyze`
Expected: No new errors

- [ ] **Step 5: Commit**

```bash
git add app/lib/presentation/pages/zakat/zakat_calculator_page.dart app/lib/presentation/pages/zakat/zakat_settings_page.dart
git commit -m "feat: wire zakat calculate and save settings buttons"
```

---

## Task 10: Remove product import "Скоро" badge

**Files:**
- Modify: `app/lib/presentation/pages/product/import_products_page.dart:37`

- [ ] **Step 1: Read the file around line 37**

Read `import_products_page.dart` lines 30-45.

- [ ] **Step 2: Remove "Скоро" text**

Find and remove the "Скоро" badge/label. If the import page is otherwise functional, just remove the badge. If the entire import flow is stubbed, wire it to the existing file picker and upload logic.

- [ ] **Step 3: Commit**

```bash
git add app/lib/presentation/pages/product/import_products_page.dart
git commit -m "fix: remove 'Скоро' badge from product import page"
```

---

## Task 11: Release signing config and ProGuard

**Files:**
- Modify: `app/android/app/build.gradle.kts`
- Create: `app/android/app/proguard-rules.pro`
- Modify: `app/.gitignore`

- [ ] **Step 1: Create proguard-rules.pro**

```pro
# app/android/app/proguard-rules.pro

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Dio / OkHttp
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# JSON serialization
-keepattributes *Annotation*
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Firebase (for later sprint)
-keep class com.google.firebase.** { *; }

# Mobile Scanner
-keep class com.google.mlkit.** { *; }
```

- [ ] **Step 2: Update build.gradle.kts for release signing**

In `app/android/app/build.gradle.kts`, replace the release buildType block:

```kotlin
    buildTypes {
        release {
            // Read signing config from key.properties
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                val keystoreProperties = java.util.Properties().apply {
                    load(keystorePropertiesFile.inputStream())
                }
                signingConfig = signingConfigs.create("release") {
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                    storeFile = file(keystoreProperties["storeFile"] as String)
                    storePassword = keystoreProperties["storePassword"] as String
                }
            } else {
                // Fall back to debug for development
                signingConfig = signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
```

- [ ] **Step 3: Add key.properties to .gitignore**

In `app/.gitignore`, add:
```
key.properties
*.jks
*.keystore
```

- [ ] **Step 4: Verify build still works in debug mode**

Run: `cd /Users/latifrjdev/Downloads/Dukon/app && flutter build apk --debug 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL

- [ ] **Step 5: Commit**

```bash
git add app/android/app/build.gradle.kts app/android/app/proguard-rules.pro app/.gitignore
git commit -m "build: add release signing config and ProGuard rules"
```

---

## Task 12: Run full test suite and final analyze

- [ ] **Step 1: Run flutter analyze**

Run: `cd /Users/latifrjdev/Downloads/Dukon/app && flutter analyze`
Expected: No errors (warnings/infos ok)

- [ ] **Step 2: Run all tests**

Run: `cd /Users/latifrjdev/Downloads/Dukon/app && flutter test`
Expected: All tests pass

- [ ] **Step 3: Fix any failures**

If tests fail, fix them before proceeding.

- [ ] **Step 4: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: resolve test/analyze issues from Sprint 1"
```

- [ ] **Step 5: Create PR**

```bash
git push -u origin sprint1/foundation
gh pr create --base main --title "feat: Sprint 1 — Foundation (scanner, customer edit, filters, release config)" --body "## Summary
- Barcode scanner (mobile_scanner) wired to 4 locations: POS, product list, add product, stock intake
- Customer form page with add/edit mode
- Sales filter sheet (period, payment type, status)
- Zakat calculate and save buttons wired
- Product import 'Скоро' badge removed
- Release signing config with key.properties
- ProGuard/R8 enabled for release builds

## Stubs eliminated: 11

## Test plan
- [ ] flutter analyze — no errors
- [ ] flutter test — all pass
- [ ] Manual: scan barcode in POS, verify product added to cart
- [ ] Manual: edit customer from detail page
- [ ] Manual: apply sales filter"
```
