import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';
import 'app_localizations_tg.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('tg'),
    Locale('uz'),
  ];

  /// Application title
  ///
  /// In ru, this message translates to:
  /// **'DukonPro'**
  String get appTitle;

  /// Save button
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// Cancel button
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// Delete button
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// Edit button
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get edit;

  /// Search action/label
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get search;

  /// Back button
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get back;

  /// Next button
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get next;

  /// Done button
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get done;

  /// Close button
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// Confirm button
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get confirm;

  /// Retry button
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// Loading indicator text
  ///
  /// In ru, this message translates to:
  /// **'Загрузка...'**
  String get loading;

  /// Generic error label
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get error;

  /// Generic success label
  ///
  /// In ru, this message translates to:
  /// **'Успешно'**
  String get success;

  /// No data available
  ///
  /// In ru, this message translates to:
  /// **'Нет данных'**
  String get noData;

  /// No search results
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get noResults;

  /// Empty list placeholder
  ///
  /// In ru, this message translates to:
  /// **'Список пуст'**
  String get emptyList;

  /// Login button
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get login;

  /// Register button
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрироваться'**
  String get register;

  /// Logout button
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get logout;

  /// Phone number field label
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона'**
  String get phone;

  /// Password field label
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get password;

  /// Name field label
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get name;

  /// Email field label
  ///
  /// In ru, this message translates to:
  /// **'Электронная почта'**
  String get email;

  /// Forgot password link
  ///
  /// In ru, this message translates to:
  /// **'Забыли пароль?'**
  String get forgotPassword;

  /// Create password screen title
  ///
  /// In ru, this message translates to:
  /// **'Создайте пароль'**
  String get createPassword;

  /// OTP entry screen title
  ///
  /// In ru, this message translates to:
  /// **'Введите код подтверждения'**
  String get enterOtp;

  /// OTP sent confirmation message
  ///
  /// In ru, this message translates to:
  /// **'Код отправлен на ваш номер'**
  String get otpSent;

  /// Phone number input hint
  ///
  /// In ru, this message translates to:
  /// **'+992XXXXXXXXX'**
  String get phoneHint;

  /// Login screen welcome message
  ///
  /// In ru, this message translates to:
  /// **'Добро пожаловать!'**
  String get loginWelcome;

  /// Register screen welcome message
  ///
  /// In ru, this message translates to:
  /// **'Создайте аккаунт'**
  String get registerWelcome;

  /// Confirm password field
  ///
  /// In ru, this message translates to:
  /// **'Подтвердите пароль'**
  String get confirmPassword;

  /// No account prompt
  ///
  /// In ru, this message translates to:
  /// **'Нет аккаунта?'**
  String get noAccount;

  /// Has account prompt
  ///
  /// In ru, this message translates to:
  /// **'Уже есть аккаунт?'**
  String get hasAccount;

  /// Onboarding slide 1 title
  ///
  /// In ru, this message translates to:
  /// **'Управляйте магазином'**
  String get onboardingTitle1;

  /// Onboarding slide 2 title
  ///
  /// In ru, this message translates to:
  /// **'Быстрые продажи'**
  String get onboardingTitle2;

  /// Onboarding slide 3 title
  ///
  /// In ru, this message translates to:
  /// **'Учёт товаров'**
  String get onboardingTitle3;

  /// Onboarding slide 4 title
  ///
  /// In ru, this message translates to:
  /// **'Аналитика'**
  String get onboardingTitle4;

  /// Onboarding slide 1 description
  ///
  /// In ru, this message translates to:
  /// **'Полный контроль над вашим бизнесом в одном приложении'**
  String get onboardingDesc1;

  /// Onboarding slide 2 description
  ///
  /// In ru, this message translates to:
  /// **'Оформляйте продажи за секунды с удобной кассой'**
  String get onboardingDesc2;

  /// Onboarding slide 3 description
  ///
  /// In ru, this message translates to:
  /// **'Отслеживайте остатки, приход и расход товаров'**
  String get onboardingDesc3;

  /// Onboarding slide 4 description
  ///
  /// In ru, this message translates to:
  /// **'Подробные отчёты о выручке, прибыли и продажах'**
  String get onboardingDesc4;

  /// Skip button on onboarding
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get skip;

  /// Get started button on onboarding
  ///
  /// In ru, this message translates to:
  /// **'Начать'**
  String get getStarted;

  /// Create store action
  ///
  /// In ru, this message translates to:
  /// **'Создать магазин'**
  String get createStore;

  /// Store name field
  ///
  /// In ru, this message translates to:
  /// **'Название магазина'**
  String get storeName;

  /// Store category field
  ///
  /// In ru, this message translates to:
  /// **'Тип магазина'**
  String get storeCategory;

  /// Store address field
  ///
  /// In ru, this message translates to:
  /// **'Адрес магазина'**
  String get storeAddress;

  /// Grocery store type
  ///
  /// In ru, this message translates to:
  /// **'Продуктовый'**
  String get grocery;

  /// Clothing store type
  ///
  /// In ru, this message translates to:
  /// **'Одежда'**
  String get clothing;

  /// Electronics store type
  ///
  /// In ru, this message translates to:
  /// **'Электроника'**
  String get electronics;

  /// Hardware store type
  ///
  /// In ru, this message translates to:
  /// **'Стройматериалы'**
  String get hardware;

  /// Pharmacy store type
  ///
  /// In ru, this message translates to:
  /// **'Аптека'**
  String get pharmacy;

  /// Other store type
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get other;

  /// Currency label
  ///
  /// In ru, this message translates to:
  /// **'Валюта'**
  String get currency;

  /// Products section title
  ///
  /// In ru, this message translates to:
  /// **'Товары'**
  String get products;

  /// Add product action
  ///
  /// In ru, this message translates to:
  /// **'Добавить товар'**
  String get addProduct;

  /// Edit product action
  ///
  /// In ru, this message translates to:
  /// **'Редактировать товар'**
  String get editProduct;

  /// Product name field
  ///
  /// In ru, this message translates to:
  /// **'Название товара'**
  String get productName;

  /// Barcode field
  ///
  /// In ru, this message translates to:
  /// **'Штрихкод'**
  String get barcode;

  /// Cost/purchase price
  ///
  /// In ru, this message translates to:
  /// **'Цена закупки'**
  String get costPrice;

  /// Selling price
  ///
  /// In ru, this message translates to:
  /// **'Цена продажи'**
  String get sellPrice;

  /// Quantity field
  ///
  /// In ru, this message translates to:
  /// **'Количество'**
  String get quantity;

  /// Category label
  ///
  /// In ru, this message translates to:
  /// **'Категория'**
  String get category;

  /// Categories section title
  ///
  /// In ru, this message translates to:
  /// **'Категории'**
  String get categories;

  /// All categories filter
  ///
  /// In ru, this message translates to:
  /// **'Все категории'**
  String get allCategories;

  /// Uncategorized products
  ///
  /// In ru, this message translates to:
  /// **'Без категории'**
  String get uncategorized;

  /// Unit of measurement
  ///
  /// In ru, this message translates to:
  /// **'Единица измерения'**
  String get unit;

  /// Pieces unit
  ///
  /// In ru, this message translates to:
  /// **'шт'**
  String get pcs;

  /// Kilogram unit
  ///
  /// In ru, this message translates to:
  /// **'кг'**
  String get kg;

  /// Liter unit
  ///
  /// In ru, this message translates to:
  /// **'л'**
  String get liter;

  /// Pack unit
  ///
  /// In ru, this message translates to:
  /// **'уп'**
  String get pack;

  /// In stock status
  ///
  /// In ru, this message translates to:
  /// **'В наличии'**
  String get inStock;

  /// Out of stock status
  ///
  /// In ru, this message translates to:
  /// **'Нет в наличии'**
  String get outOfStock;

  /// Low stock warning
  ///
  /// In ru, this message translates to:
  /// **'Мало на складе'**
  String get lowStock;

  /// Import products action
  ///
  /// In ru, this message translates to:
  /// **'Импорт товаров'**
  String get importProducts;

  /// Scan barcode action
  ///
  /// In ru, this message translates to:
  /// **'Сканировать штрихкод'**
  String get scanBarcode;

  /// Product creation step 1
  ///
  /// In ru, this message translates to:
  /// **'Основная информация'**
  String get step1BasicInfo;

  /// Product creation step 2
  ///
  /// In ru, this message translates to:
  /// **'Цена и остатки'**
  String get step2PriceStock;

  /// Product creation step 3
  ///
  /// In ru, this message translates to:
  /// **'Дополнительно'**
  String get step3Additional;

  /// SKU field
  ///
  /// In ru, this message translates to:
  /// **'Артикул'**
  String get sku;

  /// No products placeholder
  ///
  /// In ru, this message translates to:
  /// **'Нет товаров'**
  String get noProducts;

  /// Point of Sale section
  ///
  /// In ru, this message translates to:
  /// **'Касса'**
  String get pos;

  /// Checkout action
  ///
  /// In ru, this message translates to:
  /// **'Оформить продажу'**
  String get checkout;

  /// Cart label
  ///
  /// In ru, this message translates to:
  /// **'Корзина'**
  String get cart;

  /// Empty cart message
  ///
  /// In ru, this message translates to:
  /// **'Корзина пуста'**
  String get emptyCart;

  /// Subtotal label
  ///
  /// In ru, this message translates to:
  /// **'Подытог'**
  String get subtotal;

  /// Discount label
  ///
  /// In ru, this message translates to:
  /// **'Скидка'**
  String get discount;

  /// Total label
  ///
  /// In ru, this message translates to:
  /// **'Итого'**
  String get total;

  /// Cash payment method
  ///
  /// In ru, this message translates to:
  /// **'Наличные'**
  String get cash;

  /// Card payment method
  ///
  /// In ru, this message translates to:
  /// **'Карта'**
  String get card;

  /// Debt payment method
  ///
  /// In ru, this message translates to:
  /// **'В долг'**
  String get debt;

  /// Mixed payment method
  ///
  /// In ru, this message translates to:
  /// **'Смешанная оплата'**
  String get mixed;

  /// Paid amount label
  ///
  /// In ru, this message translates to:
  /// **'Оплачено'**
  String get paidAmount;

  /// Change amount
  ///
  /// In ru, this message translates to:
  /// **'Сдача'**
  String get change;

  /// Debt amount label
  ///
  /// In ru, this message translates to:
  /// **'Сумма долга'**
  String get debtAmount;

  /// Add to cart action
  ///
  /// In ru, this message translates to:
  /// **'В корзину'**
  String get addToCart;

  /// Remove from cart action
  ///
  /// In ru, this message translates to:
  /// **'Убрать из корзины'**
  String get removeFromCart;

  /// Clear cart action
  ///
  /// In ru, this message translates to:
  /// **'Очистить корзину'**
  String get clearCart;

  /// Sale success message
  ///
  /// In ru, this message translates to:
  /// **'Продажа оформлена'**
  String get saleSuccess;

  /// Receipt number label
  ///
  /// In ru, this message translates to:
  /// **'Чек №'**
  String get receiptNo;

  /// Print receipt action
  ///
  /// In ru, this message translates to:
  /// **'Печать чека'**
  String get printReceipt;

  /// Share receipt action
  ///
  /// In ru, this message translates to:
  /// **'Отправить чек'**
  String get shareReceipt;

  /// New sale action
  ///
  /// In ru, this message translates to:
  /// **'Новая продажа'**
  String get newSale;

  /// Payment label
  ///
  /// In ru, this message translates to:
  /// **'Оплата'**
  String get payment;

  /// Receipt label
  ///
  /// In ru, this message translates to:
  /// **'Чек'**
  String get receipt;

  /// Sales section title
  ///
  /// In ru, this message translates to:
  /// **'Продажи'**
  String get sales;

  /// Sales history section
  ///
  /// In ru, this message translates to:
  /// **'История продаж'**
  String get salesHistory;

  /// Today's sales
  ///
  /// In ru, this message translates to:
  /// **'Продажи за сегодня'**
  String get todaySales;

  /// Transaction detail screen
  ///
  /// In ru, this message translates to:
  /// **'Детали операции'**
  String get transactionDetail;

  /// Refund action
  ///
  /// In ru, this message translates to:
  /// **'Возврат'**
  String get refund;

  /// Completed sale status
  ///
  /// In ru, this message translates to:
  /// **'Завершена'**
  String get completed;

  /// Returned sale status
  ///
  /// In ru, this message translates to:
  /// **'Возвращена'**
  String get returned;

  /// Partially returned status
  ///
  /// In ru, this message translates to:
  /// **'Частичный возврат'**
  String get partiallyReturned;

  /// Cancelled sale status
  ///
  /// In ru, this message translates to:
  /// **'Отменена'**
  String get cancelled;

  /// No sales placeholder
  ///
  /// In ru, this message translates to:
  /// **'Нет продаж'**
  String get noSales;

  /// Stock intake action
  ///
  /// In ru, this message translates to:
  /// **'Приход товара'**
  String get stockIntake;

  /// Stock movement section
  ///
  /// In ru, this message translates to:
  /// **'Движение товара'**
  String get stockMovement;

  /// Purchase type
  ///
  /// In ru, this message translates to:
  /// **'Закупка'**
  String get purchase;

  /// Sale type
  ///
  /// In ru, this message translates to:
  /// **'Продажа'**
  String get sale;

  /// Return movement type
  ///
  /// In ru, this message translates to:
  /// **'Возврат'**
  String get returnType;

  /// Stock adjustment type
  ///
  /// In ru, this message translates to:
  /// **'Корректировка'**
  String get adjustment;

  /// Write-off type
  ///
  /// In ru, this message translates to:
  /// **'Списание'**
  String get writeOff;

  /// Supplier label
  ///
  /// In ru, this message translates to:
  /// **'Поставщик'**
  String get supplier;

  /// Select supplier prompt
  ///
  /// In ru, this message translates to:
  /// **'Выберите поставщика'**
  String get selectSupplier;

  /// Dashboard section title
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get dashboard;

  /// Today's revenue
  ///
  /// In ru, this message translates to:
  /// **'Выручка за сегодня'**
  String get todayRevenue;

  /// Today's profit
  ///
  /// In ru, this message translates to:
  /// **'Прибыль за сегодня'**
  String get todayProfit;

  /// Total products count
  ///
  /// In ru, this message translates to:
  /// **'Всего товаров'**
  String get totalProducts;

  /// Monthly sales
  ///
  /// In ru, this message translates to:
  /// **'Продажи за месяц'**
  String get monthlySales;

  /// Quick actions section
  ///
  /// In ru, this message translates to:
  /// **'Быстрые действия'**
  String get quickActions;

  /// Profit label
  ///
  /// In ru, this message translates to:
  /// **'Прибыль'**
  String get profit;

  /// More button
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get more;

  /// Offline mode message
  ///
  /// In ru, this message translates to:
  /// **'Нет подключения к интернету. Работаем офлайн.'**
  String get offline;

  /// Customers section
  ///
  /// In ru, this message translates to:
  /// **'Покупатели'**
  String get customers;

  /// Suppliers section
  ///
  /// In ru, this message translates to:
  /// **'Поставщики'**
  String get suppliers;

  /// Add customer action
  ///
  /// In ru, this message translates to:
  /// **'Добавить покупателя'**
  String get addCustomer;

  /// Add supplier action
  ///
  /// In ru, this message translates to:
  /// **'Добавить поставщика'**
  String get addSupplier;

  /// Total debt label
  ///
  /// In ru, this message translates to:
  /// **'Общий долг'**
  String get totalDebt;

  /// Total spent label
  ///
  /// In ru, this message translates to:
  /// **'Всего потрачено'**
  String get totalSpent;

  /// Customer label
  ///
  /// In ru, this message translates to:
  /// **'Покупатель'**
  String get customer;

  /// Settings section
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settings;

  /// Profile section
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profile;

  /// Language setting
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get language;

  /// Theme setting
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get theme;

  /// Dark mode toggle
  ///
  /// In ru, this message translates to:
  /// **'Тёмная тема'**
  String get darkMode;

  /// Notifications setting
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get notifications;

  /// About section
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get about;

  /// No description provided for @finances.
  ///
  /// In ru, this message translates to:
  /// **'Финансы'**
  String get finances;

  /// No description provided for @financeDashboard.
  ///
  /// In ru, this message translates to:
  /// **'Финансовый дашборд'**
  String get financeDashboard;

  /// No description provided for @income.
  ///
  /// In ru, this message translates to:
  /// **'Доход'**
  String get income;

  /// No description provided for @expenses.
  ///
  /// In ru, this message translates to:
  /// **'Расходы'**
  String get expenses;

  /// No description provided for @salesCount.
  ///
  /// In ru, this message translates to:
  /// **'Кол-во продаж'**
  String get salesCount;

  /// No description provided for @avgCheck.
  ///
  /// In ru, this message translates to:
  /// **'Средний чек'**
  String get avgCheck;

  /// No description provided for @topProducts.
  ///
  /// In ru, this message translates to:
  /// **'Топ товары'**
  String get topProducts;

  /// No description provided for @period.
  ///
  /// In ru, this message translates to:
  /// **'Период'**
  String get period;

  /// No description provided for @day.
  ///
  /// In ru, this message translates to:
  /// **'День'**
  String get day;

  /// No description provided for @week.
  ///
  /// In ru, this message translates to:
  /// **'Неделя'**
  String get week;

  /// No description provided for @month.
  ///
  /// In ru, this message translates to:
  /// **'Месяц'**
  String get month;

  /// No description provided for @year.
  ///
  /// In ru, this message translates to:
  /// **'Год'**
  String get year;

  /// No description provided for @addExpense.
  ///
  /// In ru, this message translates to:
  /// **'Добавить расход'**
  String get addExpense;

  /// No description provided for @expenseCategory.
  ///
  /// In ru, this message translates to:
  /// **'Категория расхода'**
  String get expenseCategory;

  /// No description provided for @rent.
  ///
  /// In ru, this message translates to:
  /// **'Аренда'**
  String get rent;

  /// No description provided for @salary.
  ///
  /// In ru, this message translates to:
  /// **'Зарплата'**
  String get salary;

  /// No description provided for @utilities.
  ///
  /// In ru, this message translates to:
  /// **'Коммунальные'**
  String get utilities;

  /// No description provided for @transport.
  ///
  /// In ru, this message translates to:
  /// **'Транспорт'**
  String get transport;

  /// No description provided for @marketing.
  ///
  /// In ru, this message translates to:
  /// **'Маркетинг'**
  String get marketing;

  /// No description provided for @amount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get amount;

  /// No description provided for @description.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get description;

  /// No description provided for @notes.
  ///
  /// In ru, this message translates to:
  /// **'Заметки'**
  String get notes;

  /// No description provided for @date.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get date;

  /// No description provided for @debts.
  ///
  /// In ru, this message translates to:
  /// **'Долги'**
  String get debts;

  /// No description provided for @weOwe.
  ///
  /// In ru, this message translates to:
  /// **'Мы должны'**
  String get weOwe;

  /// No description provided for @theyOwe.
  ///
  /// In ru, this message translates to:
  /// **'Нам должны'**
  String get theyOwe;

  /// No description provided for @customerDebts.
  ///
  /// In ru, this message translates to:
  /// **'Долги клиентов'**
  String get customerDebts;

  /// No description provided for @supplierDebts.
  ///
  /// In ru, this message translates to:
  /// **'Наши долги поставщикам'**
  String get supplierDebts;

  /// No description provided for @noDebts.
  ///
  /// In ru, this message translates to:
  /// **'Нет активных долгов'**
  String get noDebts;

  /// No description provided for @recordPayment.
  ///
  /// In ru, this message translates to:
  /// **'Записать оплату'**
  String get recordPayment;

  /// No description provided for @paymentAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма оплаты'**
  String get paymentAmount;

  /// No description provided for @paymentMethod.
  ///
  /// In ru, this message translates to:
  /// **'Способ оплаты'**
  String get paymentMethod;

  /// No description provided for @paymentAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Оплата принята'**
  String get paymentAccepted;

  /// No description provided for @paymentRecorded.
  ///
  /// In ru, this message translates to:
  /// **'Оплата записана'**
  String get paymentRecorded;

  /// No description provided for @zakat.
  ///
  /// In ru, this message translates to:
  /// **'Закят'**
  String get zakat;

  /// No description provided for @zakatCalculator.
  ///
  /// In ru, this message translates to:
  /// **'Калькулятор закята'**
  String get zakatCalculator;

  /// No description provided for @zakatSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки закята'**
  String get zakatSettings;

  /// No description provided for @zakatHistory.
  ///
  /// In ru, this message translates to:
  /// **'История выплат'**
  String get zakatHistory;

  /// No description provided for @stockValue.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость товаров'**
  String get stockValue;

  /// No description provided for @receivables.
  ///
  /// In ru, this message translates to:
  /// **'Дебиторская задолженность'**
  String get receivables;

  /// No description provided for @payables.
  ///
  /// In ru, this message translates to:
  /// **'Кредиторская задолженность'**
  String get payables;

  /// No description provided for @netAssets.
  ///
  /// In ru, this message translates to:
  /// **'Чистые активы'**
  String get netAssets;

  /// No description provided for @nisabThreshold.
  ///
  /// In ru, this message translates to:
  /// **'Порог нисаба'**
  String get nisabThreshold;

  /// No description provided for @zakatDue.
  ///
  /// In ru, this message translates to:
  /// **'Сумма закята'**
  String get zakatDue;

  /// No description provided for @aboveNisab.
  ///
  /// In ru, this message translates to:
  /// **'Выше нисаба'**
  String get aboveNisab;

  /// No description provided for @belowNisab.
  ///
  /// In ru, this message translates to:
  /// **'Ниже нисаба'**
  String get belowNisab;

  /// No description provided for @recordZakatPayment.
  ///
  /// In ru, this message translates to:
  /// **'Записать выплату закята'**
  String get recordZakatPayment;

  /// No description provided for @nisabAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма нисаба'**
  String get nisabAmount;

  /// No description provided for @zakatRate.
  ///
  /// In ru, this message translates to:
  /// **'Ставка закята'**
  String get zakatRate;

  /// No description provided for @haulStartDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата начала хауля'**
  String get haulStartDate;

  /// No description provided for @includeStock.
  ///
  /// In ru, this message translates to:
  /// **'Включить товарные запасы'**
  String get includeStock;

  /// No description provided for @includeCash.
  ///
  /// In ru, this message translates to:
  /// **'Включить наличные'**
  String get includeCash;

  /// No description provided for @includeDebts.
  ///
  /// In ru, this message translates to:
  /// **'Включить долги'**
  String get includeDebts;

  /// No description provided for @editProfile.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать профиль'**
  String get editProfile;

  /// No description provided for @changePassword.
  ///
  /// In ru, this message translates to:
  /// **'Сменить пароль'**
  String get changePassword;

  /// No description provided for @aboutApp.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get aboutApp;

  /// No description provided for @currentPassword.
  ///
  /// In ru, this message translates to:
  /// **'Текущий пароль'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In ru, this message translates to:
  /// **'Новый пароль'**
  String get newPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In ru, this message translates to:
  /// **'Пароль успешно изменён'**
  String get passwordChanged;

  /// No description provided for @profileUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Профиль обновлён'**
  String get profileUpdated;

  /// No description provided for @noExpenses.
  ///
  /// In ru, this message translates to:
  /// **'Расходов пока нет'**
  String get noExpenses;

  /// No description provided for @expenseAdded.
  ///
  /// In ru, this message translates to:
  /// **'Расход добавлен'**
  String get expenseAdded;

  /// No description provided for @expenseDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Расход удалён'**
  String get expenseDeleted;

  /// No description provided for @noPurchases.
  ///
  /// In ru, this message translates to:
  /// **'Нет покупок'**
  String get noPurchases;

  /// No description provided for @loyaltyPoints.
  ///
  /// In ru, this message translates to:
  /// **'Баллы'**
  String get loyaltyPoints;

  /// No description provided for @viewDebts.
  ///
  /// In ru, this message translates to:
  /// **'Посмотреть долги'**
  String get viewDebts;

  /// No description provided for @recentPurchases.
  ///
  /// In ru, this message translates to:
  /// **'Последние покупки'**
  String get recentPurchases;

  /// No description provided for @ourDebt.
  ///
  /// In ru, this message translates to:
  /// **'Наш долг'**
  String get ourDebt;

  /// No description provided for @suppliedProducts.
  ///
  /// In ru, this message translates to:
  /// **'Поставленные товары'**
  String get suppliedProducts;

  /// No description provided for @noDeliveryData.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных о поставках'**
  String get noDeliveryData;

  /// No description provided for @employees.
  ///
  /// In ru, this message translates to:
  /// **'Сотрудники'**
  String get employees;

  /// No description provided for @addEmployee.
  ///
  /// In ru, this message translates to:
  /// **'Добавить сотрудника'**
  String get addEmployee;

  /// No description provided for @editEmployee.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать сотрудника'**
  String get editEmployee;

  /// No description provided for @employeeDetail.
  ///
  /// In ru, this message translates to:
  /// **'Профиль сотрудника'**
  String get employeeDetail;

  /// No description provided for @role.
  ///
  /// In ru, this message translates to:
  /// **'Роль'**
  String get role;

  /// No description provided for @admin.
  ///
  /// In ru, this message translates to:
  /// **'Администратор'**
  String get admin;

  /// No description provided for @cashier.
  ///
  /// In ru, this message translates to:
  /// **'Кассир'**
  String get cashier;

  /// No description provided for @warehouse.
  ///
  /// In ru, this message translates to:
  /// **'Складовщик'**
  String get warehouse;

  /// No description provided for @owner.
  ///
  /// In ru, this message translates to:
  /// **'Владелец'**
  String get owner;

  /// No description provided for @allRoles.
  ///
  /// In ru, this message translates to:
  /// **'Все роли'**
  String get allRoles;

  /// No description provided for @commission.
  ///
  /// In ru, this message translates to:
  /// **'Комиссия'**
  String get commission;

  /// No description provided for @commissionPercent.
  ///
  /// In ru, this message translates to:
  /// **'Комиссия %'**
  String get commissionPercent;

  /// No description provided for @baseSalary.
  ///
  /// In ru, this message translates to:
  /// **'Оклад'**
  String get baseSalary;

  /// No description provided for @isOnShift.
  ///
  /// In ru, this message translates to:
  /// **'На смене'**
  String get isOnShift;

  /// No description provided for @notOnShift.
  ///
  /// In ru, this message translates to:
  /// **'Не на смене'**
  String get notOnShift;

  /// No description provided for @shifts.
  ///
  /// In ru, this message translates to:
  /// **'Смены'**
  String get shifts;

  /// No description provided for @openShift.
  ///
  /// In ru, this message translates to:
  /// **'Открыть смену'**
  String get openShift;

  /// No description provided for @closeShift.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть смену'**
  String get closeShift;

  /// No description provided for @currentShift.
  ///
  /// In ru, this message translates to:
  /// **'Текущая смена'**
  String get currentShift;

  /// No description provided for @shiftHistory.
  ///
  /// In ru, this message translates to:
  /// **'История смен'**
  String get shiftHistory;

  /// No description provided for @openingCash.
  ///
  /// In ru, this message translates to:
  /// **'Начальная касса'**
  String get openingCash;

  /// No description provided for @closingCash.
  ///
  /// In ru, this message translates to:
  /// **'Конечная касса'**
  String get closingCash;

  /// No description provided for @expectedCash.
  ///
  /// In ru, this message translates to:
  /// **'Ожидаемая касса'**
  String get expectedCash;

  /// No description provided for @cashDifference.
  ///
  /// In ru, this message translates to:
  /// **'Разница'**
  String get cashDifference;

  /// No description provided for @noActiveShift.
  ///
  /// In ru, this message translates to:
  /// **'Нет активной смены'**
  String get noActiveShift;

  /// No description provided for @shiftOpened.
  ///
  /// In ru, this message translates to:
  /// **'Смена открыта'**
  String get shiftOpened;

  /// No description provided for @shiftClosed.
  ///
  /// In ru, this message translates to:
  /// **'Смена закрыта'**
  String get shiftClosed;

  /// No description provided for @enterOpeningCash.
  ///
  /// In ru, this message translates to:
  /// **'Введите сумму начальной кассы'**
  String get enterOpeningCash;

  /// No description provided for @zReport.
  ///
  /// In ru, this message translates to:
  /// **'Z-отчёт'**
  String get zReport;

  /// No description provided for @salesBreakdown.
  ///
  /// In ru, this message translates to:
  /// **'Разбивка продаж'**
  String get salesBreakdown;

  /// No description provided for @cashSales.
  ///
  /// In ru, this message translates to:
  /// **'Продажи наличными'**
  String get cashSales;

  /// No description provided for @cardSales.
  ///
  /// In ru, this message translates to:
  /// **'Продажи картой'**
  String get cardSales;

  /// No description provided for @debtSales.
  ///
  /// In ru, this message translates to:
  /// **'Продажи в долг'**
  String get debtSales;

  /// No description provided for @returns.
  ///
  /// In ru, this message translates to:
  /// **'Возвраты'**
  String get returns;

  /// No description provided for @cashDrawer.
  ///
  /// In ru, this message translates to:
  /// **'Денежный ящик'**
  String get cashDrawer;

  /// No description provided for @withdrawals.
  ///
  /// In ru, this message translates to:
  /// **'Изъятия'**
  String get withdrawals;

  /// No description provided for @topProductsSold.
  ///
  /// In ru, this message translates to:
  /// **'Топ товары по продажам'**
  String get topProductsSold;

  /// No description provided for @payroll.
  ///
  /// In ru, this message translates to:
  /// **'Зарплата'**
  String get payroll;

  /// No description provided for @calculatePayroll.
  ///
  /// In ru, this message translates to:
  /// **'Рассчитать зарплату'**
  String get calculatePayroll;

  /// No description provided for @payrollPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Период зарплаты'**
  String get payrollPeriod;

  /// No description provided for @bonus.
  ///
  /// In ru, this message translates to:
  /// **'Бонус'**
  String get bonus;

  /// No description provided for @deduction.
  ///
  /// In ru, this message translates to:
  /// **'Вычет'**
  String get deduction;

  /// No description provided for @addBonus.
  ///
  /// In ru, this message translates to:
  /// **'Добавить бонус'**
  String get addBonus;

  /// No description provided for @addDeduction.
  ///
  /// In ru, this message translates to:
  /// **'Добавить вычет'**
  String get addDeduction;

  /// No description provided for @pay.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить'**
  String get pay;

  /// No description provided for @payAll.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить всем'**
  String get payAll;

  /// No description provided for @paid.
  ///
  /// In ru, this message translates to:
  /// **'Оплачено'**
  String get paid;

  /// No description provided for @unpaid.
  ///
  /// In ru, this message translates to:
  /// **'Не оплачено'**
  String get unpaid;

  /// No description provided for @shiftsWorked.
  ///
  /// In ru, this message translates to:
  /// **'Отработано смен'**
  String get shiftsWorked;

  /// No description provided for @totalSales.
  ///
  /// In ru, this message translates to:
  /// **'Общие продажи'**
  String get totalSales;

  /// No description provided for @totalAmount.
  ///
  /// In ru, this message translates to:
  /// **'Общая сумма'**
  String get totalAmount;

  /// No description provided for @adjustmentType.
  ///
  /// In ru, this message translates to:
  /// **'Тип'**
  String get adjustmentType;

  /// No description provided for @adjustmentAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get adjustmentAmount;

  /// No description provided for @adjustmentDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get adjustmentDescription;

  /// No description provided for @payrollCalculated.
  ///
  /// In ru, this message translates to:
  /// **'Зарплата рассчитана'**
  String get payrollCalculated;

  /// No description provided for @payrollPaid.
  ///
  /// In ru, this message translates to:
  /// **'Зарплата выплачена'**
  String get payrollPaid;

  /// No description provided for @allPayrollsPaid.
  ///
  /// In ru, this message translates to:
  /// **'Все зарплаты выплачены'**
  String get allPayrollsPaid;

  /// No description provided for @permissions.
  ///
  /// In ru, this message translates to:
  /// **'Права доступа'**
  String get permissions;

  /// No description provided for @viewSales.
  ///
  /// In ru, this message translates to:
  /// **'Просмотр продаж'**
  String get viewSales;

  /// No description provided for @createSales.
  ///
  /// In ru, this message translates to:
  /// **'Создание продаж'**
  String get createSales;

  /// No description provided for @cancelSales.
  ///
  /// In ru, this message translates to:
  /// **'Отмена продаж'**
  String get cancelSales;

  /// No description provided for @viewProfit.
  ///
  /// In ru, this message translates to:
  /// **'Просмотр прибыли'**
  String get viewProfit;

  /// No description provided for @changePrices.
  ///
  /// In ru, this message translates to:
  /// **'Изменение цен'**
  String get changePrices;

  /// No description provided for @manageProducts.
  ///
  /// In ru, this message translates to:
  /// **'Управление товарами'**
  String get manageProducts;

  /// No description provided for @addExpenses.
  ///
  /// In ru, this message translates to:
  /// **'Добавление расходов'**
  String get addExpenses;

  /// No description provided for @manageCustomers.
  ///
  /// In ru, this message translates to:
  /// **'Управление клиентами'**
  String get manageCustomers;

  /// No description provided for @manageStaff.
  ///
  /// In ru, this message translates to:
  /// **'Управление сотрудниками'**
  String get manageStaff;

  /// No description provided for @viewReports.
  ///
  /// In ru, this message translates to:
  /// **'Просмотр отчётов'**
  String get viewReports;

  /// No description provided for @employeeCreated.
  ///
  /// In ru, this message translates to:
  /// **'Сотрудник создан'**
  String get employeeCreated;

  /// No description provided for @employeeUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Сотрудник обновлён'**
  String get employeeUpdated;

  /// No description provided for @employeeDeactivated.
  ///
  /// In ru, this message translates to:
  /// **'Сотрудник деактивирован'**
  String get employeeDeactivated;

  /// No description provided for @permissionsUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Права обновлены'**
  String get permissionsUpdated;

  /// No description provided for @noEmployees.
  ///
  /// In ru, this message translates to:
  /// **'Нет сотрудников'**
  String get noEmployees;

  /// No description provided for @noShifts.
  ///
  /// In ru, this message translates to:
  /// **'Нет смен'**
  String get noShifts;

  /// No description provided for @selectMonth.
  ///
  /// In ru, this message translates to:
  /// **'Выберите месяц'**
  String get selectMonth;

  /// No description provided for @duration.
  ///
  /// In ru, this message translates to:
  /// **'Длительность'**
  String get duration;

  /// No description provided for @navHome.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get navHome;

  /// No description provided for @navProducts.
  ///
  /// In ru, this message translates to:
  /// **'Товары'**
  String get navProducts;

  /// No description provided for @navPOS.
  ///
  /// In ru, this message translates to:
  /// **'Касса'**
  String get navPOS;

  /// No description provided for @navFinance.
  ///
  /// In ru, this message translates to:
  /// **'Финансы'**
  String get navFinance;

  /// No description provided for @navMore.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get navMore;

  /// Share action (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Поделиться'**
  String get a11yShare;

  /// Refresh action (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get a11yRefresh;

  /// Filter action singular (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Фильтр'**
  String get a11yFilter;

  /// Filters action plural (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get a11yFilters;

  /// Delete product action (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Удалить товар'**
  String get a11yDeleteProduct;

  /// Add client (tooltip). Distinct from addCustomer which uses 'покупателя'
  ///
  /// In ru, this message translates to:
  /// **'Добавить клиента'**
  String get a11yAddClient;

  /// Call client phone action (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Позвонить клиенту'**
  String get a11yCallClient;

  /// Select client action (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Выбрать клиента'**
  String get a11ySelectClient;

  /// Edit store action (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Редактировать магазин'**
  String get a11yEditStore;

  /// Edit discount action (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Редактировать скидку'**
  String get a11yEditDiscount;

  /// Delete discount action (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Удалить скидку'**
  String get a11yDeleteDiscount;

  /// Edit category action (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Редактировать категорию'**
  String get a11yEditCategory;

  /// Delete category action (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Удалить категорию'**
  String get a11yDeleteCategory;

  /// Open reports action (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Открыть отчёты'**
  String get a11yOpenReports;

  /// Download report action (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Скачать отчёт'**
  String get a11yDownloadReport;

  /// Calculation history action (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'История расчётов'**
  String get a11yCalculationHistory;

  /// Increase item quantity (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Увеличить количество'**
  String get a11yIncreaseQuantity;

  /// Decrease item quantity (tooltip)
  ///
  /// In ru, this message translates to:
  /// **'Уменьшить количество'**
  String get a11yDecreaseQuantity;

  /// Cash payment without change (semantic label)
  ///
  /// In ru, this message translates to:
  /// **'Без сдачи'**
  String get a11yWithoutChange;

  /// Date range / period picker (semantic label)
  ///
  /// In ru, this message translates to:
  /// **'Выбрать период'**
  String get a11ySelectPeriod;

  /// Upload photo action (semantic label)
  ///
  /// In ru, this message translates to:
  /// **'Загрузить фото'**
  String get a11yUploadPhoto;

  /// Open shift Z-report (semantic label)
  ///
  /// In ru, this message translates to:
  /// **'Открыть Z-отчёт'**
  String get a11yOpenZReport;

  /// Mark notification as read (semantic label)
  ///
  /// In ru, this message translates to:
  /// **'Отметить как прочитанное'**
  String get a11yMarkAsRead;

  /// Edit profile action (semantic label)
  ///
  /// In ru, this message translates to:
  /// **'Редактировать профиль'**
  String get a11yEditProfile;

  /// Quick-pick amount chip (semantic label)
  ///
  /// In ru, this message translates to:
  /// **'Быстрая сумма {amount}'**
  String a11yQuickAmount(String amount);

  /// Select currency row (semantic label)
  ///
  /// In ru, this message translates to:
  /// **'Выбрать валюту {code}'**
  String a11ySelectCurrency(String code);

  /// Select store card (semantic label)
  ///
  /// In ru, this message translates to:
  /// **'Выбрать магазин {name}'**
  String a11ySelectStore(String name);

  /// Select language row (semantic label)
  ///
  /// In ru, this message translates to:
  /// **'Выбрать язык {language}'**
  String a11yChooseLanguage(String language);

  /// Open product detail (semantic label)
  ///
  /// In ru, this message translates to:
  /// **'Открыть товар {name}'**
  String a11yOpenProduct(String name);

  /// Subscription payment history tile (semantic label)
  ///
  /// In ru, this message translates to:
  /// **'Платёж {plan}'**
  String a11yPaymentOf(String plan);

  /// No description provided for @snackRefundSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Возврат успешно оформлен'**
  String get snackRefundSuccess;

  /// No description provided for @snackSelectOrder.
  ///
  /// In ru, this message translates to:
  /// **'Выберите заказ'**
  String get snackSelectOrder;

  /// No description provided for @snackSelectCourier.
  ///
  /// In ru, this message translates to:
  /// **'Выберите курьера'**
  String get snackSelectCourier;

  /// No description provided for @snackAdjustmentAdded.
  ///
  /// In ru, this message translates to:
  /// **'Корректировка добавлена'**
  String get snackAdjustmentAdded;

  /// No description provided for @snackCacheCleared.
  ///
  /// In ru, this message translates to:
  /// **'Кэш очищен'**
  String get snackCacheCleared;

  /// No description provided for @snackScannerSettingsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Настройки сканера сохранены'**
  String get snackScannerSettingsSaved;

  /// No description provided for @snackSettingsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Настройки сохранены'**
  String get snackSettingsSaved;

  /// No description provided for @snackTelegramSendFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить. Клиент не привязан к боту?'**
  String get snackTelegramSendFailed;

  /// No description provided for @snackSettingSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить настройку'**
  String get snackSettingSaveFailed;

  /// No description provided for @snackNoPhoneNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона не указан'**
  String get snackNoPhoneNumber;

  /// No description provided for @snackPrintError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка печати'**
  String get snackPrintError;

  /// No description provided for @snackSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения'**
  String get snackSaveError;

  /// No description provided for @snackPrinterNotConnected.
  ///
  /// In ru, this message translates to:
  /// **'Принтер не подключён. Настройте в Настройки → Принтер.'**
  String get snackPrinterNotConnected;

  /// No description provided for @snackIntakeSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Приход успешно оформлен'**
  String get snackIntakeSuccess;

  /// No description provided for @snackCalculationCopied.
  ///
  /// In ru, this message translates to:
  /// **'Расчёт скопирован'**
  String get snackCalculationCopied;

  /// No description provided for @snackSyncCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация выполнена'**
  String get snackSyncCompleted;

  /// No description provided for @snackShiftClosed.
  ///
  /// In ru, this message translates to:
  /// **'Смена закрыта'**
  String get snackShiftClosed;

  /// No description provided for @snackShiftOpened.
  ///
  /// In ru, this message translates to:
  /// **'Смена открыта'**
  String get snackShiftOpened;

  /// No description provided for @snackTestPrintDone.
  ///
  /// In ru, this message translates to:
  /// **'Тестовая печать выполнена'**
  String get snackTestPrintDone;

  /// No description provided for @snackTestMessageSent.
  ///
  /// In ru, this message translates to:
  /// **'Тестовое сообщение отправлено'**
  String get snackTestMessageSent;

  /// No description provided for @snackReceiptPrinted.
  ///
  /// In ru, this message translates to:
  /// **'Чек напечатан'**
  String get snackReceiptPrinted;

  /// No description provided for @snackReceiptSentToTelegram.
  ///
  /// In ru, this message translates to:
  /// **'Чек отправлен в Telegram'**
  String get snackReceiptSentToTelegram;

  /// No description provided for @snackTemplateSaved.
  ///
  /// In ru, this message translates to:
  /// **'Шаблон сохранён'**
  String get snackTemplateSaved;

  /// No description provided for @snackLanguageSaved.
  ///
  /// In ru, this message translates to:
  /// **'Язык сохранён. Перезапустите приложение для применения.'**
  String get snackLanguageSaved;

  /// No description provided for @snackCustomerSelectedForSale.
  ///
  /// In ru, this message translates to:
  /// **'Клиент {name} выбран для продажи'**
  String snackCustomerSelectedForSale(String name);

  /// No description provided for @snackStoreSelected.
  ///
  /// In ru, this message translates to:
  /// **'Магазин \"{name}\" выбран'**
  String snackStoreSelected(String name);

  /// No description provided for @snackPrintErrorDetails.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка печати: {error}'**
  String snackPrintErrorDetails(String error);

  /// No description provided for @snackConnectionError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка подключения: {error}'**
  String snackConnectionError(String error);

  /// No description provided for @snackSyncError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка синхронизации: {error}'**
  String snackSyncError(String error);

  /// No description provided for @snackGenericError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {error}'**
  String snackGenericError(String error);

  /// No description provided for @snackProductAddedToCart.
  ///
  /// In ru, this message translates to:
  /// **'{name} добавлен в корзину'**
  String snackProductAddedToCart(String name);

  /// Action button on add-to-cart snackbar — navigates to POS checkout
  ///
  /// In ru, this message translates to:
  /// **'В кассу'**
  String get snackActionGoToCheckout;

  /// Snackbar after a new investment is created
  ///
  /// In ru, this message translates to:
  /// **'Вложение добавлено'**
  String get investmentCreated;

  /// Snackbar after an investment is updated
  ///
  /// In ru, this message translates to:
  /// **'Вложение обновлено'**
  String get investmentUpdated;

  /// Snackbar after an investment is deleted
  ///
  /// In ru, this message translates to:
  /// **'Вложение удалено'**
  String get investmentDeleted;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru', 'tg', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
    case 'tg':
      return AppLocalizationsTg();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
