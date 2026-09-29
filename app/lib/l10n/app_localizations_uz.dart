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
  String get actionCannotBeUndone => 'Это действие нельзя отменить.';

  @override
  String deleteConfirmBody(String name) {
    return 'Вы уверены, что хотите удалить \"$name\"?';
  }

  @override
  String get edit => 'Tahrirlash';

  @override
  String get modify => 'Изменить';

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
  String get printLabel => 'Печать';

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
  String get reset => 'Сбросить';

  @override
  String get loadMore => 'Загрузить ещё';

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
  String get noCustomers => 'Нет клиентов';

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
  String get myStoresEditTitle => 'Редактировать магазин';

  @override
  String get myStoresAddTitle => 'Добавить магазин';

  @override
  String get myStoresNameLabel => 'Название *';

  @override
  String get myStoresCategoryLabel => 'Категория *';

  @override
  String get myStoresEmptyState => 'Нет магазинов';

  @override
  String get myStoresActiveStatus => 'Активный';

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
  String get addProductNameRequiredLabel => 'Название товара *';

  @override
  String get addProductSkuLabel => 'Артикул (SKU)';

  @override
  String get addProductImageSizeHint => 'JPG, PNG до 5MB';

  @override
  String get addProductInitialQuantityLabel => 'Начальное количество *';

  @override
  String get addProductQuantityRequiredError => 'Введите количество';

  @override
  String get addProductMinStockLabel => 'Минимальный остаток';

  @override
  String get addProductPhotoSectionLabel => 'Фото товара';

  @override
  String get addProductTapToUploadHint => 'Нажмите для загрузки';

  @override
  String get addProductSavedSyncingMessage =>
      'Товар сохранён. Синхронизация в фоне.';

  @override
  String get addPhotoLabel => 'Добавить фото';

  @override
  String get productName => 'Tovar nomi';

  @override
  String get productCountOne => 'товар';

  @override
  String get productCountFew => 'товара';

  @override
  String get productCountMany => 'товаров';

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
  String get enterQuantityHint => 'Введите количество';

  @override
  String get enterCostPriceHint => 'Введите себестоимость';

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
  String get percentRangeErrorFrom1 => 'От 1 до 100';

  @override
  String get quantity => 'Miqdor';

  @override
  String get quantityShort => 'Кол-во';

  @override
  String get category => 'Kategoriya';

  @override
  String get categories => 'Kategoriyalar';

  @override
  String get categoriesEditTitle => 'Редактировать категорию';

  @override
  String get categoriesNewTitle => 'Новая категория';

  @override
  String get categoriesDeleteTitle => 'Удалить категорию?';

  @override
  String get categoriesEmptyTitle => 'Нет категорий';

  @override
  String get categoriesEmptySubtitle =>
      'Создайте первую категорию для ваших товаров';

  @override
  String get categoriesEmptyButton => 'Создать категорию';

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
  String get noProductsFound => 'Товары не найдены';

  @override
  String get emptyProductsTitle => 'Добавьте свой первый товар';

  @override
  String get emptyProductsSubtitle =>
      'Начните добавлять товары в ваш магазин, чтобы управлять продажами и складом';

  @override
  String get importFromExcel => 'Импорт из Excel';

  @override
  String get productSearchHint => 'Поиск товара';

  @override
  String get productFilterLowStock => 'Заканчивается';

  @override
  String get productFilterAttention => 'Требует внимания';

  @override
  String get productsEmptyFilteredTitle => 'Нет товаров по фильтру';

  @override
  String get productsEmptyAddSubtitle => 'Добавьте первый товар в каталог';

  @override
  String get productsEmptyFilteredSubtitle =>
      'Попробуйте изменить фильтр или поисковый запрос';

  @override
  String productSkuLine(String sku) {
    return 'Арт: $sku';
  }

  @override
  String productStockQuantityLine(String value) {
    return 'На складе: $value';
  }

  @override
  String get productStatusActive => 'Активен';

  @override
  String get productStatusInactive => 'Неактивен';

  @override
  String get productDetailUnitLabel => 'Единица';

  @override
  String productDetailCurrentStockLine(String qty, String unit) {
    return 'Текущий остаток: $qty $unit';
  }

  @override
  String productDetailMinStockLine(String qty, String unit) {
    return 'Минимальный: $qty $unit';
  }

  @override
  String get productDetailBarcodeLabel => 'Штрих-код';

  @override
  String get productDetailStockAvailabilityTitle => 'Наличие на складе';

  @override
  String get productDetailInfoSectionTitle => 'Информация';

  @override
  String get productDetailSellButton => 'Продать';

  @override
  String get productDetailDeleteConfirmTitle => 'Удалить товар?';

  @override
  String get productDetailStoreNotSelectedError => 'Магазин не выбран';

  @override
  String get productDetailMovementHistoryLoadError =>
      'Не удалось загрузить историю движений';

  @override
  String get productDetailMovementHistoryTitle => 'История движений';

  @override
  String get productDetailNoMovements => 'Нет движений';

  @override
  String get productDetailBatchNoDataMessage =>
      'Нет данных о последней закупке — оформите приход, чтобы видеть окупаемость партии.';

  @override
  String get productDetailBatchPayabilityTitle => 'Окупаемость партии';

  @override
  String get productDetailBatchCostLabel => 'Себестоимость партии';

  @override
  String get productDetailBatchRevenueLabel => 'Выручка от партии';

  @override
  String get productDetailBatchProfitEarnedLabel => 'Прибыль заработана';

  @override
  String get productDetailBatchTimeToPaybackLabel => 'До окупаемости партии';

  @override
  String get productDetailBatchPaidOffLabel => 'Партия окупилась';

  @override
  String get productDetailStockRemainingLabel => 'Остаток';

  @override
  String productDetailStockRemainingValue(String qty, String value) {
    return '$qty шт. на $value';
  }

  @override
  String productDetailBatchPaybackPercentLine(String percent) {
    return '$percent% окупаемости';
  }

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
  String get totalCaps => 'ИТОГО';

  @override
  String totalTjsLine(String amount) {
    return 'Итого: $amount TJS';
  }

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
  String get paymentMixedShort => 'Смешанная';

  @override
  String get posCheckoutNoCustomerOption => 'Без клиента';

  @override
  String get posCheckoutSearchHint => 'Поиск по названию';

  @override
  String get posCheckoutEmptyCartSubtitle =>
      'Найдите товар через поиск или выберите из списка выше';

  @override
  String posCheckoutCartHeader(String count) {
    return 'Корзина ($count товаров)';
  }

  @override
  String posCheckoutCta(String total) {
    return 'Оформить продажу — $total';
  }

  @override
  String posCheckoutPointsRedeemPreview(String points, String value) {
    return '$points баллов = -$value сом';
  }

  @override
  String posCheckoutPointsAvailableInline(String points) {
    return '$points баллов доступно';
  }

  @override
  String get posCheckoutRedeemPointsTitle => 'Списать баллы';

  @override
  String posCheckoutPointsAvailableLabel(String points) {
    return 'Доступно: $points баллов';
  }

  @override
  String posCheckoutDiscountPreview(String amount) {
    return 'Скидка: -$amount сом';
  }

  @override
  String get posCheckoutDiscountPercentHint => 'Процент';

  @override
  String get posCheckoutDiscountAmountHint => 'Сумма';

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
  String get saleSuccessTitle => 'Продажа оформлена!';

  @override
  String saleSuccessChangeLine(String amount) {
    return 'Сдача: $amount';
  }

  @override
  String get saleSuccessSendToTelegramButton => 'Отправить в Telegram';

  @override
  String saleSuccessReceiptShareTextWhatsapp(String receiptNo, String total) {
    return 'Чек #$receiptNo\nИтого: $total сом.';
  }

  @override
  String saleSuccessReceiptShareTextSms(String receiptNo, String total) {
    return 'Чек #$receiptNo, Итого: $total сом.';
  }

  @override
  String get receiptNo => 'Chek №';

  @override
  String get receiptQtyAbbrev => 'Кол.';

  @override
  String get printReceipt => 'Chekni chop etish';

  @override
  String get printReceiptButton => 'Печатать чек';

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
  String get salesFilterSheetTitle => 'Фильтры';

  @override
  String get salesFilterReset => 'Сбросить';

  @override
  String get salesFilterCustomDates => 'Выбрать даты';

  @override
  String get salesFilterPaymentTypeSectionLabel => 'Тип оплаты';

  @override
  String get debtLabel => 'Долг';

  @override
  String get salesFilterStatusSectionLabel => 'Статус';

  @override
  String get salesFilterStatusCompleted => 'Выполнен';

  @override
  String get salesFilterStatusCancelled => 'Отменён';

  @override
  String get salesHistoryCustomDateChip => 'Выбрать';

  @override
  String get salesHistoryEmptySubtitle =>
      'История продаж появится здесь после первой транзакции';

  @override
  String salesHistoryStatsLine(String count, String amount) {
    return '$count продаж  |  $amount';
  }

  @override
  String salesHistorySkippedRowsLine(String count, String word) {
    return '$count $word пропущено';
  }

  @override
  String salesHistorySaleSummaryLine(String customer, String itemsCount) {
    return '$customer  •  $itemsCount товаров';
  }

  @override
  String get recordsCountOne => 'запись';

  @override
  String get recordsCountFew => 'записи';

  @override
  String get recordsCountMany => 'записей';

  @override
  String get todaySales => 'Bugungi savdolar';

  @override
  String get transactionDetail => 'Amaliyot tafsilotlari';

  @override
  String transactionDetailItemQtyLine(String quantity, String price) {
    return '$quantity шт × $price';
  }

  @override
  String get transactionDetailStatusReturned => 'Возвращён';

  @override
  String get transactionDetailInfoSectionTitle => 'Информация';

  @override
  String get transactionDetailNoItemsData => 'Нет данных о товарах';

  @override
  String get transactionDetailStatusPaid => 'Оплачен';

  @override
  String transactionDetailReceiptTitle(String receiptNo) {
    return 'Чек $receiptNo';
  }

  @override
  String get transactionDetailRetailCustomerFallback => 'Розничный';

  @override
  String get refund => 'Qaytarish';

  @override
  String get refundConfirmTitle => 'Подтвердить возврат?';

  @override
  String refundConfirmBody(String amount, String count) {
    return 'Сумма возврата: $amount\nВыбрано позиций: $count';
  }

  @override
  String get refundInstructionBanner => 'Выберите товары для возврата';

  @override
  String get refundSelectAll => 'Выбрать все';

  @override
  String get refundDeselectAll => 'Снять все';

  @override
  String get refundReasonLabel => 'Причина возврата';

  @override
  String get refundReasonHint => 'Укажите причину возврата';

  @override
  String get refundTotalLabel => 'Сумма возврата:';

  @override
  String get refundSubmitButton => 'Оформить возврат';

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
  String get stockIntakeSearchHint => 'Найти товар для прихода';

  @override
  String get stockIntakeEmptyState => 'Найдите товар для оформления прихода';

  @override
  String stockIntakeRemainingLine(String quantity, String unit) {
    return 'Остаток: $quantity $unit';
  }

  @override
  String stockIntakePriceLine(String price) {
    return 'Цена: $price';
  }

  @override
  String get stockIntakeCostPerUnitLabel => 'Себестоимость (за единицу)';

  @override
  String get stockIntakeTotalCostLabel => 'Итоговая стоимость';

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
  String get intakeType => 'Приход';

  @override
  String get outflowType => 'Расход';

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
  String get margin => 'Маржа';

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
      'Отметка времени последней синхронизации будет сброшена на этом устройстве. Локальные данные не удаляются.';

  @override
  String get offlineResetSyncStatusConfirm => 'Сбросить';

  @override
  String get offlineSyncErrorPartialDetail =>
      'не удалось синхронизировать часть операций';

  @override
  String get offlineAllSynced => 'Всё синхронизировано';

  @override
  String offlinePendingOpsCount(String count) {
    return '$count операций в очереди';
  }

  @override
  String offlineLastSyncLabel(String date) {
    return 'Последняя синхронизация: $date';
  }

  @override
  String get offlineNeverSynced => 'Синхронизация ещё не выполнялась';

  @override
  String get offlineSyncingButton => 'Синхронизация...';

  @override
  String get offlineSyncNowButton => 'Синхронизировать сейчас';

  @override
  String get offlineAutoSyncLabel => 'Авто-синхронизация';

  @override
  String get offlineAutoSyncDescription =>
      'Синхронизировать при подключении к сети';

  @override
  String get offlineInfoBody =>
      'В офлайн-режиме все операции сохраняются локально и автоматически синхронизируются при восстановлении подключения к интернету.';

  @override
  String get offlineDataSectionLabel => 'Данные';

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
  String get customerListSearchHint => 'Поиск клиента';

  @override
  String get customerListFilterDebt => 'С долгом';

  @override
  String get customerListFilterVip => 'VIP';

  @override
  String get customerListFilterNew => 'Новые';

  @override
  String get customerListEmptyTitle => 'Клиентов пока нет';

  @override
  String get customerListEmptySubtitle =>
      'Добавьте первого клиента, чтобы отслеживать продажи и долги';

  @override
  String get customerListEmptyButton => 'Добавить клиента';

  @override
  String get customerListFilterEmptyTitle => 'Нет клиентов по этому фильтру';

  @override
  String get customerListFilterEmptySubtitle =>
      'Попробуйте выбрать другой фильтр';

  @override
  String get customerListResetFilterButton => 'Сбросить фильтр';

  @override
  String get customerListNameHint => 'Введите имя клиента';

  @override
  String get customerListAddConfirm => 'Добавить';

  @override
  String customerListStatsLine(String count, String debt) {
    return '$count клиентов  |  Долг: $debt';
  }

  @override
  String get customerListNoDebt => 'Нет долга';

  @override
  String customerListPurchasesLine(String amount) {
    return 'Покупок: $amount';
  }

  @override
  String get customerDetailPageTitle => 'Клиент';

  @override
  String get customerDetailSpentLabel => 'Потрачено';

  @override
  String get customerDetailLoyaltyHistoryTitle => 'История баллов';

  @override
  String customerDetailPointsLine(String sign, String points) {
    return '$sign$points баллов';
  }

  @override
  String customerDetailPointsExpiryLine(String date) {
    return 'до $date';
  }

  @override
  String get newSupplier => 'Новый поставщик';

  @override
  String get editSupplier => 'Редактировать поставщика';

  @override
  String get supplierAdded => 'Поставщик добавлен';

  @override
  String get supplierUpdated => 'Поставщик обновлён';

  @override
  String get supplierListSearchHint => 'Поиск поставщика';

  @override
  String get supplierListEmptyTitle => 'Поставщиков пока нет';

  @override
  String get supplierListEmptySubtitle =>
      'Добавьте первого поставщика, чтобы отслеживать поставки и долги';

  @override
  String get supplierListNameHint => 'Введите название поставщика';

  @override
  String get supplierListAddConfirm => 'Добавить';

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
  String get notificationSettingsPageTitle => 'Настройки уведомлений';

  @override
  String get notificationSettingsSubtitle =>
      'Выберите какие уведомления вы хотите получать';

  @override
  String get notificationSettingsLowStockTitle => 'Низкий остаток';

  @override
  String get notificationSettingsLowStockSubtitle =>
      'Когда товар заканчивается на складе';

  @override
  String get notificationSettingsNewSaleSubtitle =>
      'Когда кассир оформляет продажу';

  @override
  String get notificationSettingsShiftClosedTitle => 'Закрытие смены';

  @override
  String get notificationSettingsShiftClosedSubtitle =>
      'Когда смена закрывается';

  @override
  String get notificationSettingsDeliveryTitle => 'Доставка выполнена';

  @override
  String get notificationSettingsDeliverySubtitle =>
      'Когда курьер доставил заказ';

  @override
  String get notificationSettingsDebtReminderTitle => 'Напоминание о долге';

  @override
  String get notificationSettingsDebtReminderSubtitle =>
      'Просроченные долги клиентов (> 7 дней)';

  @override
  String get notificationSettingsStaleProductTitle => 'Залежалый товар';

  @override
  String get notificationSettingsStaleProductSubtitle =>
      'Уведомлять, если товар не продаётся N дней и остаток ещё большой';

  @override
  String get notificationSettingsDaysWithoutSaleLabel => 'Дней без продаж';

  @override
  String get notificationSettingsRemainingPercentLabel =>
      'Остаток, % от партии';

  @override
  String get settingsLogoutTitle => 'Выход';

  @override
  String get settingsLogoutConfirmBody => 'Вы уверены, что хотите выйти?';

  @override
  String get settingsPremiumGateTitle => 'Доступно на тарифе PREMIUM';

  @override
  String get settingsPremiumGateBody =>
      'Интеграция с интернет-магазином доступна на тарифе PREMIUM. Перейдите на PREMIUM, чтобы синхронизировать остатки и заказы с вашим сайтом.';

  @override
  String get settingsPremiumGateLater => 'Позже';

  @override
  String get settingsPremiumGateUpgrade => 'Перейти к тарифам';

  @override
  String get settingsSectionIntegrations => 'Интеграции';

  @override
  String get settingsTileStaff => 'Продавцы';

  @override
  String get settingsTileRoles => 'Роли и доступы';

  @override
  String get settingsTileReceiptTemplates => 'Шаблоны чеков';

  @override
  String get settingsTileTelegramBot => 'Telegram-бот';

  @override
  String get settingsTileKkm => 'ККМ / Фискализация';

  @override
  String get settingsTilePrinter => 'Принтер чеков';

  @override
  String get settingsTileScanner => 'Сканер';

  @override
  String get settingsSectionApp => 'Приложение';

  @override
  String get settingsTileOfflineMode => 'Офлайн-режим';

  @override
  String get settingsSynced => 'Синхронизировано';

  @override
  String settingsPendingSyncOps(String count) {
    return '$count в очереди';
  }

  @override
  String get settingsSectionSubscription => 'Подписка';

  @override
  String get settingsPlanFallbackLabel => 'Тариф';

  @override
  String settingsPlanUntilDate(String plan, String date) {
    return '$plan до $date';
  }

  @override
  String get settingsChangePlan => 'Сменить тариф';

  @override
  String get settingsLogoutButton => 'Выйти из аккаунта';

  @override
  String get subscriptionFeatureStores1 => '1 магазин';

  @override
  String get subscriptionFeatureProducts500 => '500 товаров';

  @override
  String get subscriptionFeatureEmployees2 => '2 сотрудника';

  @override
  String get subscriptionFeatureSalesReport => 'Отчёт продаж';

  @override
  String get subscriptionFeatureCurrencies => 'Валюты';

  @override
  String get subscriptionPriceStart => '49 TJS/мес';

  @override
  String get subscriptionFeatureStores3 => '3 магазина';

  @override
  String get subscriptionFeatureProducts2000 => '2000 товаров';

  @override
  String get subscriptionFeatureEmployees10 => '10 сотрудников';

  @override
  String get subscriptionFeatureAllReports => 'Все отчёты';

  @override
  String get subscriptionFeatureDiscounts5 => '5 скидок';

  @override
  String get subscriptionPriceBusiness => '149 TJS/мес';

  @override
  String get subscriptionFeatureStores5 => '5 магазинов';

  @override
  String get subscriptionFeatureUnlimitedProductsEmployees =>
      'Безлимит товаров/сотрудников';

  @override
  String get subscriptionFeatureExportPdfExcel => 'Экспорт PDF/Excel';

  @override
  String get subscriptionFeatureUnlimitedDiscounts => 'Безлимит скидок';

  @override
  String get subscriptionFeaturePrioritySupport => 'Приоритетная поддержка';

  @override
  String get subscriptionPricePremium => '299 TJS/мес';

  @override
  String get subscriptionActiveStatus => 'Активна';

  @override
  String get subscriptionTrialStatus => 'Пробный период';

  @override
  String get subscriptionExpiredStatus => 'Истекла';

  @override
  String subscriptionTrialDaysLeftLine(String days) {
    return 'Пробный период: осталось $days дней';
  }

  @override
  String subscriptionExpiryUntilLine(String date) {
    return 'до $date';
  }

  @override
  String subscriptionAdminDiscountBadge(String percent) {
    return 'Скидка $percent%';
  }

  @override
  String get subscriptionPendingBannerText => 'Ожидает подтверждения оплаты';

  @override
  String get subscriptionCurrentPlanBadge => 'Текущий план';

  @override
  String get subscriptionSelectPlanButton => 'Выбрать';

  @override
  String get subscriptionPaymentPendingStatus => 'Ожидает';

  @override
  String get subscriptionPaymentConfirmedStatus => 'Подтверждено';

  @override
  String get subscriptionPaymentRejectedStatus => 'Отклонено';

  @override
  String subscriptionPaymentDialogTitle(String plan) {
    return 'Платёж — $plan';
  }

  @override
  String subscriptionPaymentAmountLine(String amount) {
    return 'Сумма: $amount TJS';
  }

  @override
  String get subscriptionCardTransferMethod => 'Перевод на карту';

  @override
  String subscriptionPaymentMethodLine(String method) {
    return 'Метод: $method';
  }

  @override
  String subscriptionPaymentStatusLine(String status) {
    return 'Статус: $status';
  }

  @override
  String subscriptionPaymentDateLine(String date) {
    return 'Дата: $date';
  }

  @override
  String subscriptionAdminNoteLine(String note) {
    return 'Примечание: $note';
  }

  @override
  String get subscriptionReceiptLabel => 'Чек:';

  @override
  String get subscriptionReceiptImageUnavailable => 'Изображение недоступно';

  @override
  String get subscriptionPlansSectionTitle => 'Тарифные планы';

  @override
  String get subscriptionCameraSource => 'Камера';

  @override
  String get subscriptionGallerySource => 'Галерея';

  @override
  String subscriptionPaymentSheetTitle(String plan) {
    return 'Оплата тарифа «$plan»';
  }

  @override
  String get subscriptionTransferDetailsTitle => 'Реквизиты для перевода';

  @override
  String get subscriptionRecipientLabel => 'Получатель';

  @override
  String get subscriptionBankLabel => 'Банк';

  @override
  String get subscriptionUploadReceiptButton => 'Я перевёл — загрузить чек';

  @override
  String get reportsExportSheetTitle => 'Экспорт отчёта';

  @override
  String get reportsExportPdf => 'Скачать PDF';

  @override
  String get reportsExportExcelLocal => 'Скачать Excel (локальный)';

  @override
  String get reportsExportExcelAllData => 'Скачать Excel (все данные)';

  @override
  String reportsPdfPeriodLabel(String period) {
    return 'Период: $period';
  }

  @override
  String reportsShareSubjectWithPeriod(String tabName, String period) {
    return 'Отчёт $tabName ($period)';
  }

  @override
  String get reportsRevenueColumnLabel => 'Выручка';

  @override
  String get reportsMetricColumnLabel => 'Показатель';

  @override
  String get reportsValueColumnLabel => 'Значение';

  @override
  String get reportsNetProfitLabel => 'Чистая прибыль';

  @override
  String get reportsMarginPercentLabel => 'Маржа %';

  @override
  String get reportsDeadStockPdfLabel => 'Залёжные товары';

  @override
  String reportsShareSubject(String tabName) {
    return 'Отчёт $tabName';
  }

  @override
  String reportsExportTypeShareSubject(String type) {
    return 'Экспорт $type';
  }

  @override
  String get reportsExportTypeSheetTitle => 'Что экспортировать?';

  @override
  String get reportsExcelTopProductsSectionHeader => '=== Топ товары ===';

  @override
  String get reportsExcelDeadStockSectionHeader => '=== Залёжные товары ===';

  @override
  String get reportsStockValueLabel => 'Стоимость склада';

  @override
  String get reportsPageTitle => 'Отчёты';

  @override
  String get reportsChannelAll => 'Все каналы';

  @override
  String get reportsChannelInStore => 'В магазине';

  @override
  String get reportsChannelOnline => 'Онлайн';

  @override
  String get reportsSalesDataSectionTitle => 'Данные по продажам';

  @override
  String get reportsAvgCheckColumnLabel => 'Ср. чек';

  @override
  String get reportsTop5ByRevenueChartTitle => 'Топ-5 товаров по выручке';

  @override
  String get reportsExpensesByCategoryChartTitle => 'Расходы по категориям';

  @override
  String get reportsDetailsSectionTitle => 'Детализация';

  @override
  String get reportsIncomeVsExpensesChartTitle => 'Доход vs Расходы по месяцам';

  @override
  String get reportsTopSalesSectionTitle => 'Топ продажи';

  @override
  String reportsQuantityUnitsLine(String qty) {
    return '$qty шт';
  }

  @override
  String get reportsDeadStockSectionTitle => 'Залёжные товары (30+ дней)';

  @override
  String get reportsSalesByCashierChartTitle => 'Продажи по кассирам';

  @override
  String reportsSalesCountTooltip(String count) {
    return '$count продаж';
  }

  @override
  String get finances => 'Moliya';

  @override
  String get financeDashboard => 'Moliyaviy boshqaruv paneli';

  @override
  String get financeDashboardPeriodHalfYear => '6 мес';

  @override
  String get financeTotalIncome => 'Общий доход';

  @override
  String get financeTotalExpenses => 'Общие расходы';

  @override
  String get financeGrossProfit => 'Валовая прибыль';

  @override
  String get financeNetProfit => 'Чистая прибыль';

  @override
  String financeDashboardQuantityUnit(String quantity) {
    return '$quantity шт';
  }

  @override
  String get financeDashboardCurrencies => 'Валюты';

  @override
  String get financeDashboardDelivery => 'Доставка';

  @override
  String get financeDashboardReport => 'Отчёт';

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
  String get salesCountAbbrev => 'Продаж';

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
  String get monthJanuary => 'Январь';

  @override
  String get monthFebruary => 'Февраль';

  @override
  String get monthMarch => 'Март';

  @override
  String get monthApril => 'Апрель';

  @override
  String get monthMay => 'Май';

  @override
  String get monthJune => 'Июнь';

  @override
  String get monthJuly => 'Июль';

  @override
  String get monthAugust => 'Август';

  @override
  String get monthSeptember => 'Сентябрь';

  @override
  String get monthOctober => 'Октябрь';

  @override
  String get monthNovember => 'Ноябрь';

  @override
  String get monthDecember => 'Декабрь';

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
  String get amountRequired => 'Введите сумму';

  @override
  String get amountTjs => 'Сумма (TJS)';

  @override
  String get description => 'Tavsif';

  @override
  String get notes => 'Qaydlar';

  @override
  String get date => 'Sana';

  @override
  String get dateNotSelected => 'Не выбрана';

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
  String get customerDebtsSalesTitle => 'Продажи с долгом';

  @override
  String get customerDebtsEmptyState => 'Нет продаж с долгом';

  @override
  String get supplierDebts => 'Yetkazib beruvchilarga qarzlarimiz';

  @override
  String get noDebts => 'Faol qarzlar yo\'q';

  @override
  String get overdueLabel => 'Просрочено';

  @override
  String get acceptDebtPayment => 'Принять оплату';

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
  String paymentFormMaxAmountLine(String amount) {
    return 'Максимум: $amount TJS';
  }

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
  String get cashPaymentPageTitle => 'Оплата наличными';

  @override
  String get cashPaymentAmountToPayLabel => 'Сумма к оплате';

  @override
  String get cashPaymentReceivedFromCustomerLabel => 'Получено от клиента';

  @override
  String get cashPaymentNoChangeButton => 'Без сдачи';

  @override
  String get cashPaymentInsufficientLabel => 'Недостаточно';

  @override
  String get cashPaymentCompleteButton => 'Завершить и печатать чек';

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
  String get zakatCalculatorAssetsSection => 'АКТИВЫ МАГАЗИНА';

  @override
  String get zakatCalculatorStockValueLabel => 'Товарные остатки';

  @override
  String get zakatCalculatorAutoFromCatalog => 'Автоматически из каталога';

  @override
  String get zakatCalculatorAutoBadge => 'Авто';

  @override
  String get zakatCalculatorSupplierDebtsLabel => 'Долги поставщикам';

  @override
  String get zakatCalculatorAutoFromSupplierModule => 'Автоматически из модуля';

  @override
  String get zakatCalculatorDeductionsSection => 'ВЫЧЕТЫ';

  @override
  String get zakatCalculatorTaxableAmountLabel => 'Облагаемая сумма:';

  @override
  String get zakatCalculatorNisabLabel => 'Нисаб (85г золота):';

  @override
  String get zakatCalculatorNisabExceededBadge => 'Превышен';

  @override
  String zakatCalculatorZakatAmountLabel(String rate) {
    return 'СУММА ЗАКЯТА ($rate%):';
  }

  @override
  String get zakatCalculatorMarkPaidButton => 'Отметить как оплачено';

  @override
  String zakatCalculatorInfoBanner(String rate) {
    return 'Закят — $rate% от имущества, хранящегося 1 лунный год';
  }

  @override
  String zakatCalculatorShareText(String due, String nisab, String netAssets) {
    return 'Закят: $due сом.\nНисаб: $nisab сом.\nЧистые активы: $netAssets сом.';
  }

  @override
  String get zakatCalculatorShareButton => 'Поделиться расчётом';

  @override
  String get zakatBreakdownTitle => 'Разбивка активов';

  @override
  String get zakatBreakdownStockLabel => 'Товарные запасы';

  @override
  String get zakatBreakdownNisabLabel => 'Нисаб';

  @override
  String get zakatBreakdownDueLabel => 'Закят (2.5%)';

  @override
  String get zakatSettings => 'Zakot sozlamalari';

  @override
  String get zakatHistory => 'To\'lovlar tarixi';

  @override
  String get zakatHistoryPageTitle => 'История закята';

  @override
  String get zakatHistoryEmptyTitle => 'Нет расчётов закята';

  @override
  String get zakatHistoryEmptySubtitle =>
      'Рассчитайте закят в калькуляторе, чтобы история появилась здесь';

  @override
  String get zakatHistoryTotalPaidLabel => 'Всего выплачено:';

  @override
  String zakatHistoryPaymentsCountLine(String count) {
    return 'за $count выплат';
  }

  @override
  String get zakatHistoryPaymentTitle => 'Выплата закята';

  @override
  String zakatHistoryPaidOnLine(String date) {
    return 'Оплачен $date';
  }

  @override
  String zakatHistoryTaxableLine(String amount) {
    return 'Облагаемая: $amount';
  }

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
  String get belowNisabNotice => 'Активы ниже нисаба. Закят не обязателен.';

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
  String get zakatSettingsMethodSection => 'МЕТОД РАСЧЁТА';

  @override
  String get zakatSettingsNisabStandardLabel => 'Стандарт нисаба';

  @override
  String get zakatSettingsNisabGoldOption => 'По золоту (85g)';

  @override
  String get zakatSettingsNisabSilverOption => 'По серебру (595g)';

  @override
  String get zakatSettingsGoldPriceLabel => 'Курс золота (за 1g)';

  @override
  String get requiredFieldError => 'Обязательное поле';

  @override
  String get requiredNumberError => 'Введите число';

  @override
  String get cannotBeNegativeError => 'Не может быть отрицательным';

  @override
  String get zakatSettingsCashOnHandLabel => 'Наличные в кассе';

  @override
  String get zakatSettingsCashHelperText =>
      'Учитывается в активах при расчёте закята';

  @override
  String get zakatSettingsHaulSection => 'ЛУННЫЙ ГОД (ХАВЛЬ)';

  @override
  String get zakatSettingsHaulStartDateLabel => 'Дата начала хавля';

  @override
  String get zakatSettingsReminderTitle => 'Напоминание';

  @override
  String get zakatSettingsReminderSubtitle => 'За 30 дней до окончания хавля';

  @override
  String get zakatSettingsAutoDataSection => 'АВТОМАТИЧЕСКИЕ ДАННЫЕ';

  @override
  String get zakatSettingsStockValueToggleTitle => 'Товарные остатки магазина';

  @override
  String get zakatSettingsStockAutoSubtitle => 'Авто из каталога';

  @override
  String get zakatSettingsSupplierDebtsToggleTitle =>
      'Долги поставщикам (вычет)';

  @override
  String get zakatSettingsSupplierDebtsAutoSubtitle =>
      'Авто из модуля поставщиков';

  @override
  String get savingEllipsis => 'Сохранение...';

  @override
  String get editProfile => 'Profilni tahrirlash';

  @override
  String get editProfileChangePhotoLabel => 'Изменить фото';

  @override
  String get editProfileLastNameLabel => 'Фамилия';

  @override
  String get editProfileSecuritySectionLabel => 'Безопасность';

  @override
  String get editProfileSaveChangesButton => 'Сохранить изменения';

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
  String get expenseListDeleteTitle => 'Удалить расход?';

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
  String get kkmTicketHeaderLine => 'ККМ/Фискализация\n';

  @override
  String get kkmTestPrintTicketLine => 'Тестовая печать\n';

  @override
  String get kkmFiscalNoteBody =>
      'Фискализация чеков через подключённый ККМ-принтер. Убедитесь, что устройство зарегистрировано в налоговой.';

  @override
  String get kkmBluetoothPrinterSectionLabel => 'Bluetooth принтер';

  @override
  String get kkmAutoPrintLabel => 'Автопечать при продаже';

  @override
  String get scannerPageTitle => 'Сканер штрихкодов';

  @override
  String get scannerCameraSectionLabel => 'Камера';

  @override
  String get scannerBackCameraLabel => 'Задняя камера';

  @override
  String get scannerBackCameraHint => 'Рекомендуется для сканирования';

  @override
  String get scannerFrontCameraLabel => 'Передняя камера';

  @override
  String get scannerFrontCameraHint => 'Фронтальная камера';

  @override
  String get scannerBehaviorSectionLabel => 'Поведение';

  @override
  String get scannerSoundLabel => 'Звук при сканировании';

  @override
  String get scannerVibrationLabel => 'Вибрация при сканировании';

  @override
  String get scannerAutoAddToCartLabel => 'Авто-добавление в корзину';

  @override
  String get scannerFormatsSectionLabel => 'Форматы штрихкодов';

  @override
  String get scannerSaveSettingsButton => 'Сохранить настройки';

  @override
  String get receiptTemplatePageTitle => 'Шаблон чека';

  @override
  String get receiptTemplateSaveButton => 'Сохранить шаблон';

  @override
  String get receiptTemplatePreviewLabel => 'Предпросмотр';

  @override
  String get receiptTemplateTextSectionLabel => 'Текст';

  @override
  String get receiptTemplateHeaderFieldLabel => 'Заголовок чека';

  @override
  String get receiptTemplateHeaderFieldHint =>
      'Название магазина или приветствие';

  @override
  String get receiptTemplateFooterFieldLabel => 'Подвал чека';

  @override
  String get receiptPreviewDefaultFooter => 'Спасибо за покупку!';

  @override
  String get receiptTemplateFontSizeLabel => 'Размер шрифта';

  @override
  String get receiptTemplateFontSizeSmall => 'Мал.';

  @override
  String get receiptTemplateFontSizeMedium => 'Ср.';

  @override
  String get receiptTemplateFontSizeLarge => 'Бол.';

  @override
  String get receiptTemplatePaperWidthLabel => 'Ширина бумаги';

  @override
  String get receiptTemplatePaperWidth58mm => '58 мм';

  @override
  String get receiptTemplatePaperWidth80mm => '80 мм';

  @override
  String get receiptTemplateShowOnReceiptLabel => 'Показывать на чеке';

  @override
  String get receiptTemplateQrToggleLabel => 'QR-код';

  @override
  String get receiptTemplateDateTimeToggleLabel => 'Дата и время';

  @override
  String get receiptPreviewDefaultHeader => 'Ваш магазин';

  @override
  String get receiptPreviewItemLine1 => 'Товар 1                 50.00 TJS';

  @override
  String get receiptPreviewItemLine2 => 'Товар 2                 30.00 TJS';

  @override
  String get receiptPreviewDiscountLine => 'Скидка                  -5.00 TJS';

  @override
  String get receiptPreviewTotalLine => 'ИТОГО                   75.00 TJS';

  @override
  String get receiptPreviewCashierLine => 'Кассир: Иванов И.';

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
  String get telegramLinkedCustomersLabel => 'Подключённых клиентов';

  @override
  String get telegramHowToConnectTitle => 'Как подключить клиентов';

  @override
  String telegramStep1Text(String username) {
    return 'Клиент находит бота $username в Telegram';
  }

  @override
  String get telegramStep2Text =>
      'Нажимает /start и вводит свой номер телефона';

  @override
  String get telegramStep3Text =>
      'Бот проверяет номер в базе клиентов и связывает аккаунт';

  @override
  String get telegramStep4Text =>
      'Клиент получает уведомления о продажах и долгах';

  @override
  String get telegramSendingButton => 'Отправка...';

  @override
  String get telegramTestMessageButton => 'Тестовое сообщение';

  @override
  String get languageSettingsPageTitle => 'Язык интерфейса';

  @override
  String get languageSettingsChooseLabel => 'Выберите язык';

  @override
  String get languageSettingsRestartNotice =>
      'Для применения языка перезапустите приложение.';

  @override
  String get employees => 'Xodimlar';

  @override
  String get unknownStaffLabel => 'Сотрудник';

  @override
  String get addEmployee => 'Xodim qo\'shish';

  @override
  String get editEmployee => 'Xodimni tahrirlash';

  @override
  String get employeeDetail => 'Xodim profili';

  @override
  String get staffFormNameLabel => 'Имя сотрудника';

  @override
  String get staffRoleWarehouseShort => 'Склад';

  @override
  String get staffStatusLabel => 'Статус';

  @override
  String get staffNotOnShiftStatusDetail => 'Нет смены';

  @override
  String get staffStatsTabLabel => 'Статистика';

  @override
  String get staffTodaySalesLabel => 'Продажи сегодня';

  @override
  String get staffRegistrationDateLabel => 'Дата регистрации';

  @override
  String get staffListEmptyTitle => 'Сотрудников пока нет';

  @override
  String get staffListEmptySubtitle =>
      'Добавьте сотрудников для учёта смен и зарплаты';

  @override
  String staffListTodaySalesLine(String amount) {
    return 'Сегодня: $amount';
  }

  @override
  String get staffCardTodayLabel => 'сегодня';

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
  String get openShiftHeading => 'Начало смены';

  @override
  String get openShiftSubtitle =>
      'Укажите сумму наличных в кассе на начало смены';

  @override
  String get openShiftCashLabel => 'Сумма наличных (TJS)';

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
  String get shiftsCloseCashPrompt => 'Введите сумму наличных в кассе:';

  @override
  String get shiftsCashAmountLabel => 'Сумма наличных';

  @override
  String get shiftsCashAmountNegative => 'Сумма не может быть отрицательной';

  @override
  String shiftsDurationFormat(String hours, String minutes) {
    return '$hoursч $minutesм';
  }

  @override
  String get shiftsEmptySubtitle =>
      'Откройте смену, чтобы начать приём платежей';

  @override
  String get shiftsActiveStatus => 'Активна';

  @override
  String shiftsCashierLine(String name) {
    return 'Кассир: $name';
  }

  @override
  String get shiftsUnknownCashier => 'Не указан';

  @override
  String shiftsOpenedLine(String time, String duration) {
    return 'Открыта: $time  •  Время работы: $duration';
  }

  @override
  String shiftsSalesLine(String count, String amount) {
    return 'Продаж: $count  |  Сумма: $amount';
  }

  @override
  String shiftsHistoryRowLine(
    String openedTime,
    String closedTime,
    String count,
    String amount,
  ) {
    return '$openedTime–$closedTime  •  $count продаж  •  $amount';
  }

  @override
  String get shiftsClosedStatus => 'Сдано';

  @override
  String get shiftsOpenStatus => 'Открыта';

  @override
  String get shiftCardClosedStatus => 'Закрыта';

  @override
  String shiftCardSalesCountLine(String count) {
    return '$count продаж';
  }

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
  String get payrollPayAllTitle => 'Выплатить всем';

  @override
  String get payrollPayAllConfirmBody =>
      'Вы уверены, что хотите выплатить зарплату всем сотрудникам?';

  @override
  String get payrollPayAllConfirm => 'Выплатить';

  @override
  String get payrollStaffCardPayButton => 'Выплатить';

  @override
  String get payrollDeleteAdjustmentTitle => 'Удалить корректировку?';

  @override
  String get payrollCalculateButton => 'Рассчитать';

  @override
  String get payrollCalculateEmptyTitle => 'Расчёт зарплаты';

  @override
  String get payrollCalculateEmptySubtitle =>
      'Выберите месяц и нажмите \"Рассчитать\" для расчёта зарплаты сотрудников';

  @override
  String get payrollNoDataTitle => 'Нет данных по зарплате';

  @override
  String get payrollNoDataSubtitle => 'Выберите месяц и нажмите \"Рассчитать\"';

  @override
  String get payrollAddAdjustmentTooltip => 'Добавить корректировку';

  @override
  String get payrollNoStaffData => 'Нет данных по сотрудникам';

  @override
  String get payrollStatusCalculated => 'Рассчитано';

  @override
  String get payrollStatusPartiallyPaid => 'Частично оплачено';

  @override
  String get payrollPaidLabel => 'Выплачено';

  @override
  String get payrollAdjustmentPageTitle => 'Корректировка';

  @override
  String get payrollAdjustmentInstructions =>
      'Укажите тип, сумму и описание корректировки';

  @override
  String get payrollAdjustmentTypeLabel => 'Тип корректировки';

  @override
  String get payrollDeductionTypeLabel => 'Удержание';

  @override
  String get payrollAdjustmentStaffIdLabel => 'ID сотрудника (необязательно)';

  @override
  String get payrollAdjustmentStaffIdHint => 'Оставьте пустым для всех';

  @override
  String get payrollAdjustmentDescriptionRequiredError => 'Введите описание';

  @override
  String get payrollAdjustmentAmountMustBePositiveError =>
      'Сумма должна быть больше 0';

  @override
  String get payrollAdjustmentSubmit => 'Добавить';

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
  String get permissionManageStaffLabel => 'Управление персоналом';

  @override
  String get permissionManageExpensesLabel => 'Управление расходами';

  @override
  String get permissionManageCustomersLabel => 'Управление покупателями';

  @override
  String get permissionManageSuppliersLabel => 'Управление поставщиками';

  @override
  String get permissionManageStockLabel => 'Управление складом';

  @override
  String get permissionManageDebtsLabel => 'Управление долгами';

  @override
  String get permissionManageSettingsLabel => 'Настройки магазина';

  @override
  String get permissionOpenCloseShiftLabel => 'Открытие/закрытие смены';

  @override
  String get permissionApplyDiscountsLabel => 'Применение скидок';

  @override
  String get permissionManagePayrollLabel => 'Управление зарплатой';

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
  String get discountsPageTitle => 'Скидки';

  @override
  String get discountsEmptyState => 'Нет скидок. Нажмите + для создания.';

  @override
  String get discountsDeleteTitle => 'Удалить скидку?';

  @override
  String get discountsEditTitle => 'Редактировать скидку';

  @override
  String get discountsNewTitle => 'Новая скидка';

  @override
  String get discountsTypePercent => '% Процент';

  @override
  String get discountsTypeFixed => 'Сум Фиксированная';

  @override
  String get discountsValuePercentLabel => 'Значение (%)';

  @override
  String get discountsValueFixedLabel => 'Значение (TJS)';

  @override
  String get discountsMinOrderLabel =>
      'Мин. сумма заказа (условие, необязательно)';

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

  @override
  String get investmentAddPageTitle => 'Добавить вложение';

  @override
  String get investmentInvestorNameRequiredError => 'Введите имя инвестора';

  @override
  String get investmentStartDateLabel => 'Дата начала';

  @override
  String get investmentEndDateLabel => 'Дата окончания (необязательно)';

  @override
  String get investmentInvestorNameLabel => 'Имя инвестора *';

  @override
  String get investmentAmountLabel => 'Сумма *';

  @override
  String get investmentReturnAmountLabel => 'Сумма возврата';

  @override
  String get investmentInvestorPhoneLabel => 'Телефон инвестора';

  @override
  String get investments => 'Вложения';

  @override
  String get investmentEmptyState => 'Вложений пока нет';

  @override
  String get investmentStatusActive => 'Активно';

  @override
  String get investmentStatusCompleted => 'Завершено';

  @override
  String get investmentStatusCancelled => 'Отменено';

  @override
  String get currenciesPageTitle => 'Курсы валют';

  @override
  String get currenciesHistoryChartTitle => 'Динамика за 30 дней';

  @override
  String get currenciesNoHistoryData => 'Нет данных за 30 дней';

  @override
  String get currenciesConverterTitle => 'Конвертер';

  @override
  String get currenciesConvertedResultLabel => 'Результат (в TJS):';

  @override
  String get nbtBankLabel => 'НБТ — Национальный банк Таджикистана';

  @override
  String get currencyUsd => 'Доллар США';

  @override
  String get currencyRub => 'Российский рубль';

  @override
  String get currencyEur => 'Евро';

  @override
  String get currencyCny => 'Китайский юань';
}
