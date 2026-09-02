// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'DukonPro';

  @override
  String get appTagline => 'Управление магазином';

  @override
  String get save => 'Saqlash';

  @override
  String get cancel => 'Bekor qilish';

  @override
  String get delete => 'O\'chirish';

  @override
  String get edit => 'Tahrirlash';

  @override
  String get create => 'Создать';

  @override
  String get search => 'Qidirish';

  @override
  String get back => 'Orqaga';

  @override
  String get next => 'Keyingi';

  @override
  String get done => 'Tayyor';

  @override
  String get share => 'Поделиться';

  @override
  String get close => 'Yopish';

  @override
  String get confirm => 'Tasdiqlash';

  @override
  String get apply => 'Применить';

  @override
  String get retry => 'Qayta urinish';

  @override
  String get clear => 'Очистить';

  @override
  String get restore => 'Восстановить';

  @override
  String get justNow => 'только что';

  @override
  String minutesAgo(String minutes) {
    return '$minutes мин назад';
  }

  @override
  String hoursAgo(String hours) {
    return '$hours ч назад';
  }

  @override
  String daysAgo(String days) {
    return '$days дн назад';
  }

  @override
  String get loading => 'Yuklanmoqda...';

  @override
  String get processing => 'Обработка...';

  @override
  String get error => 'Xatolik';

  @override
  String get success => 'Muvaffaqiyatli';

  @override
  String get saved => 'Сохранено';

  @override
  String get noData => 'Ma\'lumot yo\'q';

  @override
  String get noResults => 'Hech narsa topilmadi';

  @override
  String get emptyList => 'Ro\'yxat bo\'sh';

  @override
  String get product => 'Товар';

  @override
  String get productNotFound => 'Товар не найден';

  @override
  String get difference => 'Разница';

  @override
  String get all => 'Все';

  @override
  String get login => 'Kirish';

  @override
  String get register => 'Ro\'yxatdan o\'tish';

  @override
  String get logout => 'Chiqish';

  @override
  String get phone => 'Telefon raqami';

  @override
  String get phoneLabel => 'Телефон';

  @override
  String get password => 'Parol';

  @override
  String get name => 'Ism';

  @override
  String get email => 'Elektron pochta';

  @override
  String get forgotPassword => 'Parolni unutdingizmi?';

  @override
  String get forgotPasswordSubtitle =>
      'Введите номер телефона, привязанный к вашему аккаунту. Мы отправим код подтверждения.';

  @override
  String get forgotPasswordSendCodeButton => 'Отправить код';

  @override
  String get forgotPasswordBackToLogin => 'Вернуться к входу';

  @override
  String get createPassword => 'Parol yarating';

  @override
  String get createPasswordSubtitle =>
      'Создайте новый пароль для вашего аккаунта';

  @override
  String get createPasswordSaveButton => 'Сохранить пароль';

  @override
  String get enterOtp => 'Tasdiqlash kodini kiriting';

  @override
  String get otpSent => 'Kod raqamingizga yuborildi';

  @override
  String get otpPageTitle => 'Подтверждение';

  @override
  String otpInstructions(String phone) {
    return 'Введите 6-значный код, отправленный на\n$phone';
  }

  @override
  String get otpResendButton => 'Отправить код повторно';

  @override
  String otpResendCountdown(String seconds) {
    return 'Повторная отправка через $seconds сек.';
  }

  @override
  String get phoneHint => '+992XXXXXXXXX';

  @override
  String get loginWelcome => 'Xush kelibsiz!';

  @override
  String get registerWelcome => 'Akkaunt yarating';

  @override
  String get confirmPassword => 'Parolni tasdiqlang';

  @override
  String get noAccount => 'Akkauntingiz yo\'qmi?';

  @override
  String get hasAccount => 'Akkauntingiz bormi?';

  @override
  String get registerTitle => 'Регистрация';

  @override
  String get registerSubtitle => 'Создайте аккаунт для управления магазином';

  @override
  String get onboardingTitle1 => 'Do\'koningizni boshqaring';

  @override
  String get onboardingTitle2 => 'Tezkor savdo';

  @override
  String get onboardingTitle3 => 'Tovarlar hisobi';

  @override
  String get onboardingTitle4 => 'Tahlillar';

  @override
  String get onboardingDesc1 =>
      'Biznesingizni bitta ilovada to\'liq nazorat qiling';

  @override
  String get onboardingDesc2 =>
      'Qulay kassa yordamida savdoni soniyalarda amalga oshiring';

  @override
  String get onboardingDesc3 =>
      'Tovar qoldiqlarini, kirim va chiqimni kuzating';

  @override
  String get onboardingDesc4 =>
      'Daromad, foyda va savdo bo\'yicha batafsil hisobotlar';

  @override
  String get onboardingSalesDesc =>
      'Проводите продажи за секунды через удобный POS-интерфейс';

  @override
  String get onboardingInventoryDesc =>
      'Полный контроль склада: приход, расход, остатки в реальном времени';

  @override
  String get onboardingAnalyticsDesc =>
      'Выручка, прибыль и статистика продаж на одном экране';

  @override
  String get onboardingOfflineTitle => 'Работает офлайн';

  @override
  String get onboardingOfflineDesc =>
      'Продавайте без интернета — данные синхронизируются автоматически';

  @override
  String get skip => 'O\'tkazib yuborish';

  @override
  String get getStarted => 'Boshlash';

  @override
  String get createStore => 'Do\'kon yaratish';

  @override
  String get storeName => 'Do\'kon nomi';

  @override
  String get createStoreNameRequiredError => 'Введите название';

  @override
  String get storeCategory => 'Do\'kon turi';

  @override
  String get storeAddress => 'Do\'kon manzili';

  @override
  String get createStoreAddressLabel => 'Адрес (необязательно)';

  @override
  String get createStorePhoneLabel => 'Телефон магазина (необязательно)';

  @override
  String get grocery => 'Oziq-ovqat';

  @override
  String get clothing => 'Kiyim-kechak';

  @override
  String get electronics => 'Elektronika';

  @override
  String get hardware => 'Qurilish mollari';

  @override
  String get pharmacy => 'Dorixona';

  @override
  String get other => 'Boshqa';

  @override
  String get currency => 'Valyuta';

  @override
  String get products => 'Tovarlar';

  @override
  String get addProduct => 'Tovar qo\'shish';

  @override
  String get editProduct => 'Tovarni tahrirlash';

  @override
  String get newProductTitle => 'Новый товар';

  @override
  String get addProductStepBasic => 'Основное';

  @override
  String get addProductStepPrices => 'Цены';

  @override
  String get addProductStepStock => 'Склад';

  @override
  String get productName => 'Tovar nomi';

  @override
  String get itemName => 'Название';

  @override
  String get barcode => 'Shtrix-kod';

  @override
  String get costPrice => 'Xarid narxi';

  @override
  String get sellPrice => 'Sotuv narxi';

  @override
  String get price => 'Цена';

  @override
  String get wholesalePrice => 'Оптовая цена';

  @override
  String get costPriceRequiredLabel => 'Себестоимость *';

  @override
  String get sellPriceRequiredLabel => 'Цена продажи *';

  @override
  String get costPriceRequiredError => 'Введите себестоимость';

  @override
  String get sellPriceRequiredError => 'Введите цену продажи';

  @override
  String get invalidFormatError => 'Неверный формат';

  @override
  String get enterName => 'Введите имя';

  @override
  String get phoneRequired => 'Введите номер телефона';

  @override
  String get passwordMinLength => 'Минимум 6 символов';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get invalidAmount => 'Некорректная сумма';

  @override
  String amountExceedsMax(String maxAmount) {
    return 'Сумма не может превышать $maxAmount';
  }

  @override
  String get invalidValue => 'Некорректное значение';

  @override
  String get percentRangeError => 'От 0 до 100';

  @override
  String get quantity => 'Miqdor';

  @override
  String get quantityShort => 'Кол-во';

  @override
  String get category => 'Kategoriya';

  @override
  String get categories => 'Kategoriyalar';

  @override
  String get allCategories => 'Barcha kategoriyalar';

  @override
  String get uncategorized => 'Kategoriyasiz';

  @override
  String get unit => 'O\'lchov birligi';

  @override
  String get pcs => 'dona';

  @override
  String get kg => 'kg';

  @override
  String get liter => 'l';

  @override
  String get pack => 'qad';

  @override
  String get unitPiece => 'Штука';

  @override
  String get unitKilogram => 'Килограмм';

  @override
  String get unitLiter => 'Литр';

  @override
  String get unitMeter => 'Метр';

  @override
  String get unitBox => 'Коробка';

  @override
  String get unitPack => 'Упаковка';

  @override
  String get inStock => 'Mavjud';

  @override
  String get outOfStock => 'Mavjud emas';

  @override
  String get lowStock => 'Omborda kam';

  @override
  String get importProducts => 'Tovarlarni import qilish';

  @override
  String get importProductsSubtitle =>
      'Загрузите список товаров из Excel или CSV файла.\nСкачайте шаблон для правильного формата.';

  @override
  String get importProductsSelectFile => 'Выбрать файл';

  @override
  String get importProductsDownloadTemplate => 'Скачать шаблон';

  @override
  String importProductsFoundCount(String count) {
    return '$count товаров найдено';
  }

  @override
  String importProductsErrorsBadge(String count) {
    return '$count ошибок';
  }

  @override
  String importProductsRowError(String row, String message) {
    return 'Строка $row: $message';
  }

  @override
  String importProductsConfirmButton(String count) {
    return 'Импортировать $count товаров';
  }

  @override
  String get importProductsCompleted => 'Импорт завершён';

  @override
  String importProductsCreatedCount(String count) {
    return 'Создано: $count';
  }

  @override
  String importProductsSkippedCount(String count) {
    return 'Пропущено: $count';
  }

  @override
  String importProductsErrorsSummary(String count) {
    return 'Ошибки: $count';
  }

  @override
  String importProductsMoreErrorsCount(String count) {
    return '...и ещё $count';
  }

  @override
  String get scanBarcode => 'Shtrix-kodni skanerlash';

  @override
  String get step1BasicInfo => 'Asosiy ma\'lumot';

  @override
  String get step2PriceStock => 'Narx va qoldiq';

  @override
  String get step3Additional => 'Qo\'shimcha';

  @override
  String get sku => 'Artikul';

  @override
  String get noProducts => 'Tovarlar yo\'q';

  @override
  String get emptyProductsTitle => 'Добавьте свой первый товар';

  @override
  String get emptyProductsSubtitle =>
      'Начните добавлять товары в ваш магазин, чтобы управлять продажами и складом';

  @override
  String get importFromExcel => 'Импорт из Excel';

  @override
  String get pos => 'Kassa';

  @override
  String get checkout => 'Savdoni rasmiylashtirish';

  @override
  String get cart => 'Savat';

  @override
  String get emptyCart => 'Savat bo\'sh';

  @override
  String get subtotal => 'Oraliq jami';

  @override
  String get discount => 'Chegirma';

  @override
  String get total => 'Jami';

  @override
  String get cash => 'Naqd';

  @override
  String get card => 'Karta';

  @override
  String get cardPaymentConfirmTitle => 'Оплата картой?';

  @override
  String cardPaymentConfirmMessage(String total) {
    return 'Сумма к оплате: $total';
  }

  @override
  String get debt => 'Qarzga';

  @override
  String get mixed => 'Aralash to\'lov';

  @override
  String get transfer => 'Перевод';

  @override
  String get paidAmount => 'To\'langan';

  @override
  String get change => 'Qaytim';

  @override
  String get debtAmount => 'Qarz miqdori';

  @override
  String get addToCart => 'Savatga';

  @override
  String get removeFromCart => 'Savatdan olib tashlash';

  @override
  String get clearCart => 'Savatni tozalash';

  @override
  String get cartMaxStockReached => 'Больше нет в наличии';

  @override
  String get cartRestoreDialogTitle => 'Восстановить корзину?';

  @override
  String cartRestoreDialogMessage(String time, String count) {
    return 'Найдена сохранённая корзина ($time, $count товаров).';
  }

  @override
  String get saleSuccess => 'Savdo rasmiylashtirildi';

  @override
  String get receiptNo => 'Chek №';

  @override
  String get printReceipt => 'Chekni chop etish';

  @override
  String get shareReceipt => 'Chekni yuborish';

  @override
  String get newSale => 'Yangi savdo';

  @override
  String get payment => 'To\'lov';

  @override
  String get receipt => 'Chek';

  @override
  String get sales => 'Savdolar';

  @override
  String get salesHistory => 'Savdo tarixi';

  @override
  String get todaySales => 'Bugungi savdolar';

  @override
  String get transactionDetail => 'Amaliyot tafsilotlari';

  @override
  String get refund => 'Qaytarish';

  @override
  String get completed => 'Yakunlangan';

  @override
  String get returned => 'Qaytarilgan';

  @override
  String get partiallyReturned => 'Qisman qaytarilgan';

  @override
  String get cancelled => 'Bekor qilingan';

  @override
  String get noSales => 'Savdolar yo\'q';

  @override
  String get noSalesYet => 'Пока нет продаж';

  @override
  String get emptySalesSubtitle =>
      'Совершите первую продажу через кассу, и она появится здесь';

  @override
  String get emptySalesGoToCheckout => 'Перейти к кассе';

  @override
  String get stockIntake => 'Tovar kirimi';

  @override
  String get stockMovement => 'Tovar harakati';

  @override
  String get purchase => 'Xarid';

  @override
  String get sale => 'Savdo';

  @override
  String get returnType => 'Qaytarish';

  @override
  String get adjustment => 'Tuzatish';

  @override
  String get writeOff => 'Hisobdan chiqarish';

  @override
  String get supplier => 'Yetkazib beruvchi';

  @override
  String get selectSupplier => 'Yetkazib beruvchini tanlang';

  @override
  String get dashboard => 'Bosh sahifa';

  @override
  String get todayRevenue => 'Bugungi daromad';

  @override
  String get todayProfit => 'Bugungi foyda';

  @override
  String get totalProducts => 'Jami tovarlar';

  @override
  String get monthlySales => 'Oylik savdolar';

  @override
  String get quickActions => 'Tezkor amallar';

  @override
  String get profit => 'Foyda';

  @override
  String get more => 'Ko\'proq';

  @override
  String get moreSalesFinanceTitle => 'Продажи и Финансы';

  @override
  String get moreStaffTitle => 'Персонал';

  @override
  String get moreRolesAndPermissions => 'Роли и права';

  @override
  String get moreCounterpartiesTitle => 'Контрагенты';

  @override
  String get moreClients => 'Клиенты';

  @override
  String get moreStoreTitle => 'Магазин';

  @override
  String get moreMyStores => 'Мои магазины';

  @override
  String get offline => 'Internet aloqasi yo\'q. Oflayn rejimda ishlaymiz.';

  @override
  String get offlineResetSyncStatusButton => 'Сбросить статус синхронизации';

  @override
  String get offlineResetSyncStatusTitle => 'Сбросить статус синхронизации?';

  @override
  String get offlineResetSyncStatusBody =>
      'Отметка времени последней синхронизации и счётчик операций в очереди будут сброшены на этом устройстве. Локальные данные не удаляются.';

  @override
  String get offlineResetSyncStatusConfirm => 'Сбросить';

  @override
  String get dashboardGreeting => 'Салом 👋';

  @override
  String get dashboardStoreFallback => 'Магазин';

  @override
  String get dashboardSelectStoreTitle => 'Выберите магазин';

  @override
  String get dashboardCost => 'Себестоимость';

  @override
  String get dashboardOperationsTitle => 'Операции';

  @override
  String get dashboardStockTitle => 'Остатки на складе';

  @override
  String dashboardStockSubtitle(String count) {
    return '$count товаров';
  }

  @override
  String dashboardStockSubtitleLow(String count, String lowCount) {
    return '$count товаров · $lowCount мало';
  }

  @override
  String get dashboardCustomerOwedTitle => 'Вам должны';

  @override
  String get dashboardCustomerOwedSubtitle => 'Долги клиентов по продажам';

  @override
  String get dashboardSupplierOwedTitle => 'Вы должны';

  @override
  String get dashboardSupplierOwedSubtitle => 'Долги поставщикам';

  @override
  String get dashboardInventorySubtitle => 'Проверить фактические остатки';

  @override
  String get dashboardRecentSalesTitle => 'Последние продажи';

  @override
  String get dashboardAllSalesLink => 'Все продажи >';

  @override
  String get dashboardRevenueToday => 'Выручка сегодня';

  @override
  String get dashboardRevenueWeek => 'Выручка за неделю';

  @override
  String get dashboardRevenueMonth => 'Выручка за месяц';

  @override
  String get dashboardRevenuePeriod => 'Выручка за период';

  @override
  String dashboardSalesCountLabel(String count) {
    return '$count продаж';
  }

  @override
  String dashboardAvgCheckLabel(String value) {
    return 'Средний чек $value';
  }

  @override
  String dashboardSaleReceiptLabel(String receiptNo) {
    return 'Чек #$receiptNo';
  }

  @override
  String get inventoryTitle => 'Инвентаризация';

  @override
  String get inventoryCountIntro =>
      'Запустите инвентаризацию, чтобы сверить фактические остатки товаров с ожидаемыми.';

  @override
  String get inventoryCountStart => 'Начать инвентаризацию';

  @override
  String get inventoryCountingTitle => 'Подсчёт';

  @override
  String get inventoryCountEditHint => 'Нажмите на строку для редактирования';

  @override
  String inventoryExpectedLine(String expected) {
    return 'Ожидается: $expected';
  }

  @override
  String get inventoryResultsTitle => 'Результаты';

  @override
  String get inventoryExpectedColumn => 'Ожидалось';

  @override
  String get inventoryActualColumn => 'Факт';

  @override
  String get inventoryCountCompleted => 'Инвентаризация завершена';

  @override
  String get inventoryCountUpdated => 'Остатки товаров успешно обновлены.';

  @override
  String get customers => 'Xaridorlar';

  @override
  String get suppliers => 'Yetkazib beruvchilar';

  @override
  String get addCustomer => 'Xaridor qo\'shish';

  @override
  String get addSupplier => 'Yetkazib beruvchi qo\'shish';

  @override
  String get totalDebt => 'Umumiy qarz';

  @override
  String get totalSpent => 'Jami sarflangan';

  @override
  String get customer => 'Xaridor';

  @override
  String get selectCustomer => 'Выберите клиента';

  @override
  String get newCustomer => 'Новый клиент';

  @override
  String get editCustomer => 'Редактировать клиента';

  @override
  String get customerAdded => 'Клиент добавлен';

  @override
  String get customerUpdated => 'Клиент обновлён';

  @override
  String get customerFormPhoneLabel => 'Телефон (+992)';

  @override
  String get customerFormPhoneCodeError => 'Введите номер с кодом +992';

  @override
  String get newSupplier => 'Новый поставщик';

  @override
  String get editSupplier => 'Редактировать поставщика';

  @override
  String get supplierAdded => 'Поставщик добавлен';

  @override
  String get supplierUpdated => 'Поставщик обновлён';

  @override
  String get address => 'Адрес';

  @override
  String get settings => 'Sozlamalar';

  @override
  String get profile => 'Profil';

  @override
  String get language => 'Til';

  @override
  String get theme => 'Mavzu';

  @override
  String get darkMode => 'Qorong\'u rejim';

  @override
  String get notifications => 'Bildirishnomalar';

  @override
  String get about => 'Ilova haqida';

  @override
  String get finances => 'Moliya';

  @override
  String get financeDashboard => 'Moliyaviy boshqaruv paneli';

  @override
  String get balance => 'Баланс';

  @override
  String get currentBalance => 'Текущий баланс';

  @override
  String get dynamics => 'Динамика';

  @override
  String get transactions => 'Транзакции';

  @override
  String get noTransactions => 'Транзакций нет';

  @override
  String get income => 'Daromad';

  @override
  String get incomes => 'Доходы';

  @override
  String get expenses => 'Xarajatlar';

  @override
  String get expense => 'Расход';

  @override
  String get salesCount => 'Sotuvlar soni';

  @override
  String get avgCheck => 'O\'rtacha chek';

  @override
  String get topProducts => 'Eng yaxshi mahsulotlar';

  @override
  String get period => 'Davr';

  @override
  String get day => 'Kun';

  @override
  String get today => 'Сегодня';

  @override
  String get yesterday => 'Вчера';

  @override
  String get week => 'Hafta';

  @override
  String get month => 'Oy';

  @override
  String get year => 'Yil';

  @override
  String get addExpense => 'Xarajat qo\'shish';

  @override
  String get expenseCategory => 'Xarajat kategoriyasi';

  @override
  String get rent => 'Ijara';

  @override
  String get salary => 'Maosh';

  @override
  String get utilities => 'Kommunal';

  @override
  String get transport => 'Transport';

  @override
  String get marketing => 'Marketing';

  @override
  String get amount => 'Summa';

  @override
  String get amountTjs => 'Сумма (TJS)';

  @override
  String get description => 'Tavsif';

  @override
  String get notes => 'Qaydlar';

  @override
  String get date => 'Sana';

  @override
  String get debts => 'Qarzlar';

  @override
  String get credits => 'Кредиты';

  @override
  String get weOwe => 'Biz qarzdormiz';

  @override
  String get theyOwe => 'Bizga qarzdorlar';

  @override
  String get customerDebts => 'Mijozlar qarzlari';

  @override
  String get supplierDebts => 'Yetkazib beruvchilarga qarzlarimiz';

  @override
  String get noDebts => 'Faol qarzlar yo\'q';

  @override
  String get recordPayment => 'To\'lovni qayd qilish';

  @override
  String get paymentAmount => 'To\'lov summasi';

  @override
  String get paymentMethod => 'To\'lov usuli';

  @override
  String get paymentAccepted => 'To\'lov qabul qilindi';

  @override
  String get paymentRecorded => 'To\'lov qayd qilindi';

  @override
  String get paymentQueuedOfflineMessage =>
      'Платёж сохранён офлайн — отправим при подключении';

  @override
  String get paymentHistory => 'История оплат';

  @override
  String get noPaymentRecords => 'Нет записей об оплате';

  @override
  String get creditsEmptyState => 'Записей нет';

  @override
  String get creditsTotalReceivableLabel => 'Общий долг нам';

  @override
  String get creditsTotalPayableLabel => 'Общий долг поставщикам';

  @override
  String creditsPersonCountLabel(String count) {
    return '$count чел.';
  }

  @override
  String creditsLastPaymentLabel(String date) {
    return 'посл. $date';
  }

  @override
  String get creditsAcceptPayment => 'Принять платёж';

  @override
  String get creditsMakePayment => 'Внести платёж';

  @override
  String get creditsPaymentMethodLabel => 'Метод оплаты';

  @override
  String get creditsInvalidAmountError => 'Введите корректную сумму';

  @override
  String get creditSaleTitle => 'Продажа в долг';

  @override
  String creditSaleAmountLabel(String amount) {
    return '$amount сом.';
  }

  @override
  String get creditSaleCustomerRequiredLabel => 'Клиент *';

  @override
  String get creditSaleDueDateLabel => 'Срок оплаты';

  @override
  String get creditSaleNoteLabel => 'Примечание';

  @override
  String get creditSaleNoteHint => 'Добавьте примечание (необязательно)';

  @override
  String get creditSaleCreateCustomerButton => 'Создать нового клиента';

  @override
  String get creditSaleConfirmButton => 'Оформить в долг';

  @override
  String get creditSaleCustomerListEmpty => 'Список клиентов пуст';

  @override
  String get zakat => 'Zakot';

  @override
  String get zakatCalculator => 'Zakot kalkulyatori';

  @override
  String get zakatSettings => 'Zakot sozlamalari';

  @override
  String get zakatHistory => 'To\'lovlar tarixi';

  @override
  String get stockValue => 'Tovarlar qiymati';

  @override
  String get receivables => 'Debitorlik qarzi';

  @override
  String get payables => 'Kreditorlik qarzi';

  @override
  String get netAssets => 'Sof aktivlar';

  @override
  String get nisabThreshold => 'Nisob chegarasi';

  @override
  String get zakatDue => 'Zakot summasi';

  @override
  String get aboveNisab => 'Nisob ustida';

  @override
  String get belowNisab => 'Nisob ostida';

  @override
  String get recordZakatPayment => 'Zakot to\'lovini qayd qilish';

  @override
  String get nisabAmount => 'Nisob summasi';

  @override
  String get zakatRate => 'Zakot stavkasi';

  @override
  String get haulStartDate => 'Havl boshlanish sanasi';

  @override
  String get includeStock => 'Tovar zahiralarini kiritish';

  @override
  String get includeCash => 'Naqd pulni kiritish';

  @override
  String get includeDebts => 'Qarzlarni kiritish';

  @override
  String get editProfile => 'Profilni tahrirlash';

  @override
  String get changePassword => 'Parolni o\'zgartirish';

  @override
  String get aboutApp => 'Ilova haqida';

  @override
  String get currentPassword => 'Joriy parol';

  @override
  String get newPassword => 'Yangi parol';

  @override
  String get currentPasswordRequired => 'Введите текущий пароль';

  @override
  String get newPasswordRequired => 'Введите новый пароль';

  @override
  String get passwordChanged => 'Parol muvaffaqiyatli o\'zgartirildi';

  @override
  String get profileUpdated => 'Profil yangilandi';

  @override
  String get noExpenses => 'Hozircha xarajatlar yo\'q';

  @override
  String get expenseAdded => 'Xarajat qo\'shildi';

  @override
  String get expenseDeleted => 'Xarajat o\'chirildi';

  @override
  String get expenseListForPeriod => 'За период';

  @override
  String get expenseListEmptySubtitle =>
      'Добавьте первый расход, чтобы видеть финансовую картину';

  @override
  String get noPurchases => 'Xaridlar yo\'q';

  @override
  String get loyaltyPoints => 'Ballar';

  @override
  String get viewDebts => 'Qarzlarni ko\'rish';

  @override
  String get recentPurchases => 'Oxirgi xaridlar';

  @override
  String get call => 'Звонок';

  @override
  String get sms => 'СМС';

  @override
  String get order => 'Заказ';

  @override
  String get ourDebt => 'Bizning qarzimiz';

  @override
  String get suppliedProducts => 'Yetkazib berilgan mahsulotlar';

  @override
  String get noDeliveryData => 'Yetkazib berish haqida ma\'lumot yo\'q';

  @override
  String get deliveryDetailTitle => 'Детали доставки';

  @override
  String get deliveryDetailCustomerLabel => 'Клиент';

  @override
  String get deliveryDetailAddressLabel => 'Адрес';

  @override
  String get deliveryDetailPickedUpButton => 'Забрал';

  @override
  String get deliveryDetailDeliveredButton => 'Доставлено';

  @override
  String get deliveryDetailStepCreated => 'Создан';

  @override
  String get deliveryDetailStepInTransit => 'В пути';

  @override
  String get deliveryDetailStepDelivered => 'Доставлен';

  @override
  String get deliveryListTitle => 'Доставки';

  @override
  String get deliveryListTabNew => 'Новые';

  @override
  String get deliveryListTabDelivered => 'Доставлены';

  @override
  String get deliveryListEmptyState => 'Доставок пока нет';

  @override
  String get deliveryListStatusNew => 'Новый';

  @override
  String get createDeliveryTitle => 'Новая доставка';

  @override
  String get createDeliveryAddressLabel => 'Адрес доставки';

  @override
  String get createDeliveryAddressHint => 'Введите адрес';

  @override
  String get createDeliveryCourierLabel => 'Курьер';

  @override
  String get createDeliveryNotesLabel => 'Примечания';

  @override
  String get createDeliveryNotesHint => 'Необязательно';

  @override
  String get createDeliveryButton => 'Создать доставку';

  @override
  String get loyaltySettingsTitle => 'Программа лояльности';

  @override
  String get loyaltySettingsAnalytics => 'Аналитика';

  @override
  String get loyaltySettingsActive => 'Активна';

  @override
  String get loyaltySettingsAccrualSection => 'Начисление баллов';

  @override
  String get loyaltySettingsAmountForPointsLabel => 'За каждые __ сом';

  @override
  String get loyaltySettingsPointsPerAmountLabel => 'Начислять __ баллов';

  @override
  String get loyaltySettingsPointValueLabel => '1 балл = __ сом';

  @override
  String get loyaltySettingsBonusSection => 'Бонусы';

  @override
  String get loyaltySettingsWelcomePointsLabel => 'Приветственные баллы';

  @override
  String get loyaltySettingsBirthdayDiscountLabel =>
      'Скидка в день рождения, %';

  @override
  String get loyaltySettingsBirthdayDiscountHint =>
      'Оставьте пустым, если не нужно';

  @override
  String get loyaltySettingsPointsExpireDaysLabel =>
      'Срок действия баллов, дней';

  @override
  String get loyaltySettingsPointsExpireDaysHint =>
      'Оставьте пустым — баллы не сгорают';

  @override
  String get loyaltyAnalyticsTitle => 'Аналитика баллов';

  @override
  String get loyaltyAnalyticsEarnedLabel => 'Начислено';

  @override
  String get loyaltyAnalyticsRedeemedLabel => 'Списано';

  @override
  String get loyaltyAnalyticsExpiredLabel => 'Сгорело';

  @override
  String get loyaltyAnalyticsSavingsLabel => 'Экономия';

  @override
  String loyaltyAnalyticsPointsValue(String value) {
    return '$value баллов';
  }

  @override
  String loyaltyAnalyticsSavingsValue(String value) {
    return '$value сом';
  }

  @override
  String loyaltyAnalyticsActiveParticipantsLabel(String value) {
    return 'Активных участников: $value';
  }

  @override
  String get loyaltyAnalyticsTopCustomersTitle => 'Топ клиентов';

  @override
  String get printerSettingsTitle => 'Настройки принтера';

  @override
  String get printerSettingsConnected => 'Подключён';

  @override
  String get printerSettingsNotConnected => 'Не подключён';

  @override
  String get printerSettingsDisconnectButton => 'Отключить';

  @override
  String get printerSettingsDefaultPrinterLabel => 'Принтер по умолчанию';

  @override
  String get printerSettingsScanButton => 'Найти принтеры';

  @override
  String get printerSettingsScanningButton => 'Поиск...';

  @override
  String get printerSettingsFoundDevicesTitle => 'Найденные устройства';

  @override
  String get printerSettingsTestPrintButton => 'Тестовая печать';

  @override
  String get printerSettingsPrintingButton => 'Печать...';

  @override
  String get printerSettingsDefaultBadge => 'По умолчанию';

  @override
  String get printerSettingsConnectButton => 'Подключить';

  @override
  String get printerSettingsSetDefaultButton => 'По умолч.';

  @override
  String get ecommerceSettingsTitle => 'Интернет-магазин';

  @override
  String get ecommerceSettingsInboundUrlLabel => 'URL для входящих заказов';

  @override
  String get ecommerceSettingsApiKeyLabel => 'API-ключ';

  @override
  String get ecommerceSettingsSaveToCreateKey =>
      'Сохраните настройки, чтобы создать ключ';

  @override
  String get ecommerceSettingsKeyLabel => 'Ключ';

  @override
  String get ecommerceSettingsRegenerateKeyButton => 'Перегенерировать ключ';

  @override
  String get ecommerceSettingsOutboundUrlLabel => 'URL вебхука вашего сайта';

  @override
  String get ecommerceSettingsIntegrationActiveLabel => 'Интеграция активна';

  @override
  String get ecommerceSettingsProductMappingButton => 'Сопоставление товаров';

  @override
  String get ecommerceSettingsKeyRegenerated => 'Ключ перегенерирован';

  @override
  String ecommerceSettingsCopiedMessage(String label) {
    return '$label скопирован(о)';
  }

  @override
  String get ecommerceMappingSearchHint => 'Поиск по названию товара';

  @override
  String get ecommerceMappingExternalIdHint => 'Внешний ID';

  @override
  String get employees => 'Xodimlar';

  @override
  String get addEmployee => 'Xodim qo\'shish';

  @override
  String get editEmployee => 'Xodimni tahrirlash';

  @override
  String get employeeDetail => 'Xodim profili';

  @override
  String get staffFormNameLabel => 'Имя сотрудника';

  @override
  String get role => 'Lavozim';

  @override
  String get admin => 'Administrator';

  @override
  String get adminRoleShort => 'Админ';

  @override
  String get cashier => 'Kassir';

  @override
  String get warehouse => 'Omborchi';

  @override
  String get owner => 'Egasi';

  @override
  String get allRoles => 'Barcha lavozimlar';

  @override
  String get commission => 'Komissiya';

  @override
  String get commissionPercent => 'Komissiya %';

  @override
  String get commissionPercentField => 'Комиссия (%)';

  @override
  String get baseSalary => 'Oylik maosh';

  @override
  String get baseSalaryTjs => 'Оклад (TJS)';

  @override
  String get isOnShift => 'Smenada';

  @override
  String get notOnShift => 'Smenada emas';

  @override
  String get shifts => 'Smenalar';

  @override
  String get openShift => 'Smenani ochish';

  @override
  String get closeShift => 'Smenani yopish';

  @override
  String get currentShift => 'Joriy smena';

  @override
  String get shiftHistory => 'Smenalar tarixi';

  @override
  String get openingCash => 'Boshlang\'ich kassa';

  @override
  String get closingCash => 'Yakuniy kassa';

  @override
  String get expectedCash => 'Kutilgan kassa';

  @override
  String get cashDifference => 'Farq';

  @override
  String get noActiveShift => 'Faol smena yo\'q';

  @override
  String get shiftOpened => 'Smena ochildi';

  @override
  String get shiftClosed => 'Smena yopildi';

  @override
  String get enterOpeningCash => 'Boshlang\'ich kassa summasini kiriting';

  @override
  String get zReport => 'Z-hisobot';

  @override
  String get salesBreakdown => 'Savdo taqsimoti';

  @override
  String get cashSales => 'Naqd savdolar';

  @override
  String get cardSales => 'Karta savdolari';

  @override
  String get debtSales => 'Qarzga savdolar';

  @override
  String get returns => 'Qaytarishlar';

  @override
  String get cashDrawer => 'Kassa qutisi';

  @override
  String get withdrawals => 'Chiqarishlar';

  @override
  String get topProductsSold => 'Eng ko\'p sotilgan tovarlar';

  @override
  String get zReportHeaderTitle => 'Z-ОТЧЁТ';

  @override
  String get zReportSalesCount => 'Количество продаж';

  @override
  String get zReportTotalSales => 'Итого продаж';

  @override
  String get zReportReturnsCount => 'Количество возвратов';

  @override
  String get zReportReturnsAmount => 'Сумма возвратов';

  @override
  String get zReportOpeningAmount => 'Начальная сумма';

  @override
  String get zReportCashSalesLabel => 'Продажи (нал.)';

  @override
  String get zReportCashReturnsLabel => 'Возвраты (нал.)';

  @override
  String get zReportExpectedAmount => 'Ожидаемая сумма';

  @override
  String get zReportActualAmount => 'Фактическая сумма';

  @override
  String get zReportPrintButton => 'Печать Z-отчёта';

  @override
  String zReportPdfSalesReturnsLine(String sales, String returns) {
    return 'Продаж: $sales  Возвратов: $returns';
  }

  @override
  String zReportPdfDebtLine(String debt) {
    return 'Долг: $debt';
  }

  @override
  String zReportPdfTotalLine(String total) {
    return 'ИТОГО: $total сом.';
  }

  @override
  String get payroll => 'Maosh';

  @override
  String get calculatePayroll => 'Maoshni hisoblash';

  @override
  String get payrollPeriod => 'Maosh davri';

  @override
  String get bonus => 'Bonus';

  @override
  String get deduction => 'Ushlanma';

  @override
  String get addBonus => 'Bonus qo\'shish';

  @override
  String get addDeduction => 'Ushlanma qo\'shish';

  @override
  String get pay => 'To\'lash';

  @override
  String get payAll => 'Hammaga to\'lash';

  @override
  String get paid => 'To\'langan';

  @override
  String get unpaid => 'To\'lanmagan';

  @override
  String get shiftsWorked => 'Ishlangan smenalar';

  @override
  String get totalSales => 'Umumiy savdolar';

  @override
  String get totalAmount => 'Umumiy summa';

  @override
  String get adjustmentType => 'Turi';

  @override
  String get adjustmentAmount => 'Summa';

  @override
  String get adjustmentDescription => 'Tavsif';

  @override
  String get payrollCalculated => 'Maosh hisoblandi';

  @override
  String get payrollPaid => 'Maosh to\'landi';

  @override
  String get allPayrollsPaid => 'Barcha maoshlar to\'landi';

  @override
  String get permissions => 'Ruxsatlar';

  @override
  String get viewSales => 'Savdolarni ko\'rish';

  @override
  String get createSales => 'Savdo yaratish';

  @override
  String get cancelSales => 'Savdoni bekor qilish';

  @override
  String get viewProfit => 'Foydani ko\'rish';

  @override
  String get changePrices => 'Narxlarni o\'zgartirish';

  @override
  String get manageProducts => 'Tovarlarni boshqarish';

  @override
  String get addExpenses => 'Xarajat qo\'shish';

  @override
  String get manageCustomers => 'Mijozlarni boshqarish';

  @override
  String get manageStaff => 'Xodimlarni boshqarish';

  @override
  String get viewReports => 'Hisobotlarni ko\'rish';

  @override
  String get employeeCreated => 'Xodim yaratildi';

  @override
  String get employeeAdded => 'Сотрудник добавлен';

  @override
  String get employeeUpdated => 'Xodim yangilandi';

  @override
  String get employeeDeactivated => 'Xodim faolsizlantirildi';

  @override
  String get permissionsUpdated => 'Ruxsatlar yangilandi';

  @override
  String get noEmployees => 'Xodimlar yo\'q';

  @override
  String get noShifts => 'Smenalar yo\'q';

  @override
  String get selectMonth => 'Oyni tanlang';

  @override
  String get duration => 'Davomiylik';

  @override
  String get navHome => 'Asosiy';

  @override
  String get navProducts => 'Mahsulotlar';

  @override
  String get navPOS => 'Kassa';

  @override
  String get navFinance => 'Moliya';

  @override
  String get navMore => 'Ko\'proq';

  @override
  String get a11yShare => 'Ulashish';

  @override
  String get a11yRefresh => 'Yangilash';

  @override
  String get a11yFilter => 'Filtr';

  @override
  String get a11yFilters => 'Filtrlar';

  @override
  String get a11yDeleteProduct => 'Mahsulotni o\'chirish';

  @override
  String get a11yAddClient => 'Mijoz qo\'shish';

  @override
  String get a11yCallClient => 'Mijozga qo\'ng\'iroq qilish';

  @override
  String get a11ySelectClient => 'Mijozni tanlash';

  @override
  String get a11yEditStore => 'Do\'konni tahrirlash';

  @override
  String get a11yEditDiscount => 'Chegirmani tahrirlash';

  @override
  String get a11yDeleteDiscount => 'Chegirmani o\'chirish';

  @override
  String get a11yEditCategory => 'Kategoriyani tahrirlash';

  @override
  String get a11yDeleteCategory => 'Kategoriyani o\'chirish';

  @override
  String get a11yOpenReports => 'Hisobotlarni ochish';

  @override
  String get a11yDownloadReport => 'Hisobotni yuklab olish';

  @override
  String get a11yCalculationHistory => 'Hisob-kitoblar tarixi';

  @override
  String get a11yIncreaseQuantity => 'Miqdorni oshirish';

  @override
  String get a11yDecreaseQuantity => 'Miqdorni kamaytirish';

  @override
  String get a11yWithoutChange => 'Qaytarimsiz';

  @override
  String get a11ySelectPeriod => 'Davrni tanlang';

  @override
  String get a11yUploadPhoto => 'Rasm yuklash';

  @override
  String get a11yOpenZReport => 'Z-hisobotni ochish';

  @override
  String get a11yMarkAsRead => 'O\'qilgan deb belgilash';

  @override
  String get a11yEditProfile => 'Profilni tahrirlash';

  @override
  String a11yQuickAmount(String amount) {
    return 'Tezkor summa $amount';
  }

  @override
  String a11ySelectCurrency(String code) {
    return 'Valyutani tanlang $code';
  }

  @override
  String a11ySelectStore(String name) {
    return 'Do\'konni tanlang $name';
  }

  @override
  String a11yChooseLanguage(String language) {
    return 'Tilni tanlang $language';
  }

  @override
  String a11yOpenProduct(String name) {
    return 'Mahsulotni ochish $name';
  }

  @override
  String a11yPaymentOf(String plan) {
    return 'To\'lov $plan';
  }

  @override
  String get snackRefundSuccess => 'Qaytarish muvaffaqiyatli rasmiylashtirildi';

  @override
  String get snackSelectOrder => 'Buyurtmani tanlang';

  @override
  String get snackSelectCourier => 'Kuryerni tanlang';

  @override
  String get snackAdjustmentAdded => 'Tuzatish qo\'shildi';

  @override
  String get snackSyncStatusReset => 'Статус синхронизации сброшен';

  @override
  String get snackScannerSettingsSaved => 'Skaner sozlamalari saqlandi';

  @override
  String get snackSettingsSaved => 'Sozlamalar saqlandi';

  @override
  String get snackTelegramSendFailed =>
      'Yuborib bo\'lmadi. Mijoz botga bog\'lanmagan?';

  @override
  String get snackSettingSaveFailed => 'Sozlamani saqlab bo\'lmadi';

  @override
  String get snackNoPhoneNumber => 'Telefon raqami ko\'rsatilmagan';

  @override
  String get snackPrintError => 'Chop etish xatosi';

  @override
  String get snackSaveError => 'Saqlash xatosi';

  @override
  String get snackLoadError => 'Ошибка загрузки';

  @override
  String get snackPrinterNotConnected =>
      'Printer ulanmagan. Sozlamalar → Printer bo\'limida sozlang.';

  @override
  String get snackIntakeSuccess => 'Kirim muvaffaqiyatli rasmiylashtirildi';

  @override
  String get snackCalculationCopied => 'Hisob-kitob nusxalandi';

  @override
  String get snackSyncCompleted => 'Sinxronizatsiya bajarildi';

  @override
  String get snackShiftClosed => 'Smena yopildi';

  @override
  String get snackShiftOpened => 'Smena ochildi';

  @override
  String get snackTestPrintDone => 'Sinov chop etildi';

  @override
  String get snackTestMessageSent => 'Sinov xabari yuborildi';

  @override
  String get snackReceiptPrinted => 'Chek chop etildi';

  @override
  String get snackReceiptSentToTelegram => 'Chek Telegram\'ga yuborildi';

  @override
  String get snackTemplateSaved => 'Shablon saqlandi';

  @override
  String get snackLanguageSaved =>
      'Til saqlandi. Qo\'llash uchun ilovani qayta ishga tushiring.';

  @override
  String snackCustomerSelectedForSale(String name) {
    return 'Mijoz $name sotish uchun tanlandi';
  }

  @override
  String snackStoreSelected(String name) {
    return 'Do\'kon \"$name\" tanlandi';
  }

  @override
  String snackPrintErrorDetails(String error) {
    return 'Chop etish xatosi: $error';
  }

  @override
  String snackConnectionError(String error) {
    return 'Ulanish xatosi: $error';
  }

  @override
  String snackSyncError(String error) {
    return 'Sinxronizatsiya xatosi: $error';
  }

  @override
  String snackGenericError(String error) {
    return 'Xatolik: $error';
  }

  @override
  String snackProductAddedToCart(String name) {
    return '$name savatga qo\'shildi';
  }

  @override
  String get snackActionGoToCheckout => 'Kassaga';

  @override
  String get investmentCreated => 'Investitsiya qoʻshildi';

  @override
  String get investmentUpdated => 'Investitsiya yangilandi';

  @override
  String get investmentDeleted => 'Investitsiya oʻchirildi';
}
