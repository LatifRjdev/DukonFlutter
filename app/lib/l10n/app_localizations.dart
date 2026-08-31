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

  /// App tagline shown under the app name/logo — used on both the splash screen and the login screen header
  ///
  /// In ru, this message translates to:
  /// **'Управление магазином'**
  String get appTagline;

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

  /// Generic 'Create' button — often toggled with `save` in the same slot (e.g. "Сохранить" when editing, "Создать" when adding new)
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get create;

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

  /// Share action button (distinct from a11yShare, which is a tooltip/semantic label)
  ///
  /// In ru, this message translates to:
  /// **'Поделиться'**
  String get share;

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

  /// Apply button (e.g. apply filters, apply inventory count results)
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get apply;

  /// Retry button
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// Generic 'Clear' action button (e.g. dismiss/discard something without confirming) — distinct from `clearCart` ("Очистить корзину"), which is a full-sentence cart-clearing label
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get clear;

  /// Generic 'Restore' action button (e.g. restoring a previously saved/persisted state)
  ///
  /// In ru, this message translates to:
  /// **'Восстановить'**
  String get restore;

  /// Relative time — event happened less than a minute ago
  ///
  /// In ru, this message translates to:
  /// **'только что'**
  String get justNow;

  /// Relative time — N minutes ago; placeholder is a pre-formatted String
  ///
  /// In ru, this message translates to:
  /// **'{minutes} мин назад'**
  String minutesAgo(String minutes);

  /// Relative time — N hours ago; placeholder is a pre-formatted String
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч назад'**
  String hoursAgo(String hours);

  /// Relative time — N days ago; placeholder is a pre-formatted String
  ///
  /// In ru, this message translates to:
  /// **'{days} дн назад'**
  String daysAgo(String days);

  /// Loading indicator text
  ///
  /// In ru, this message translates to:
  /// **'Загрузка...'**
  String get loading;

  /// Generic in-progress button label shown while a submit action is running — distinct from `loading` ("Загрузка...", used for page/data loading states)
  ///
  /// In ru, this message translates to:
  /// **'Обработка...'**
  String get processing;

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

  /// Generic short past-tense confirmation snackbar shown after a save action completes — distinct from `snackSettingsSaved` ("Настройки сохранены"), which is specifically about settings
  ///
  /// In ru, this message translates to:
  /// **'Сохранено'**
  String get saved;

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

  /// Generic singular 'product' label, e.g. a table column header
  ///
  /// In ru, this message translates to:
  /// **'Товар'**
  String get product;

  /// Shown when a scanned/looked-up product cannot be matched
  ///
  /// In ru, this message translates to:
  /// **'Товар не найден'**
  String get productNotFound;

  /// Generic 'difference' label (e.g. expected vs actual quantity), distinct from cashDifference which is specifically a cash-amount context
  ///
  /// In ru, this message translates to:
  /// **'Разница'**
  String get difference;

  /// Generic 'All' filter option, e.g. the first chip in a category filter list
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get all;

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

  /// Short bare 'Phone' field label (no "number") — distinct from `phone` ("Номер телефона"); this shorter wording recurs verbatim on other contact-info forms (e.g. the add-staff screen)
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get phoneLabel;

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

  /// Forgot password screen — instructs the user to enter the phone number linked to their account
  ///
  /// In ru, this message translates to:
  /// **'Введите номер телефона, привязанный к вашему аккаунту. Мы отправим код подтверждения.'**
  String get forgotPasswordSubtitle;

  /// Forgot password screen — submit button that requests an OTP code; distinct from otpResendButton ("Отправить код повторно"), which re-sends a code on the OTP screen
  ///
  /// In ru, this message translates to:
  /// **'Отправить код'**
  String get forgotPasswordSendCodeButton;

  /// Forgot password screen — link back to the login screen
  ///
  /// In ru, this message translates to:
  /// **'Вернуться к входу'**
  String get forgotPasswordBackToLogin;

  /// Create password screen title
  ///
  /// In ru, this message translates to:
  /// **'Создайте пароль'**
  String get createPassword;

  /// Create password screen subtitle shown under the heading
  ///
  /// In ru, this message translates to:
  /// **'Создайте новый пароль для вашего аккаунта'**
  String get createPasswordSubtitle;

  /// Create password screen submit button — distinct from generic `save` ("Сохранить"), includes the word "пароль"
  ///
  /// In ru, this message translates to:
  /// **'Сохранить пароль'**
  String get createPasswordSaveButton;

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

  /// OTP verification screen heading — distinct from `enterOtp` ("Введите код подтверждения"), which is a different OTP-entry screen's title
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение'**
  String get otpPageTitle;

  /// OTP verification screen — instructs the user to enter the code sent to their phone number
  ///
  /// In ru, this message translates to:
  /// **'Введите 6-значный код, отправленный на\n{phone}'**
  String otpInstructions(String phone);

  /// OTP verification screen — button shown once the resend countdown has expired, lets the user request a new code
  ///
  /// In ru, this message translates to:
  /// **'Отправить код повторно'**
  String get otpResendButton;

  /// OTP verification screen — countdown shown before resend becomes available; placeholder is a pre-formatted String
  ///
  /// In ru, this message translates to:
  /// **'Повторная отправка через {seconds} сек.'**
  String otpResendCountdown(String seconds);

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

  /// Register screen heading — distinct from `registerWelcome` ("Создайте аккаунт"), a different piece of copy
  ///
  /// In ru, this message translates to:
  /// **'Регистрация'**
  String get registerTitle;

  /// Register screen subtitle shown under the heading
  ///
  /// In ru, this message translates to:
  /// **'Создайте аккаунт для управления магазином'**
  String get registerSubtitle;

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

  /// Onboarding sales-slide description, paired with the reused onboardingTitle2 title; wording differs from the stale, currently-unused onboardingDesc2
  ///
  /// In ru, this message translates to:
  /// **'Проводите продажи за секунды через удобный POS-интерфейс'**
  String get onboardingSalesDesc;

  /// Onboarding inventory-slide description, paired with the reused onboardingTitle3 title; wording differs from the stale, currently-unused onboardingDesc3
  ///
  /// In ru, this message translates to:
  /// **'Полный контроль склада: приход, расход, остатки в реальном времени'**
  String get onboardingInventoryDesc;

  /// Onboarding analytics-slide description, paired with the reused onboardingTitle4 title; wording differs from the stale, currently-unused onboardingDesc4
  ///
  /// In ru, this message translates to:
  /// **'Выручка, прибыль и статистика продаж на одном экране'**
  String get onboardingAnalyticsDesc;

  /// Onboarding slide title for the offline-support feature (4th slide on the onboarding page)
  ///
  /// In ru, this message translates to:
  /// **'Работает офлайн'**
  String get onboardingOfflineTitle;

  /// Onboarding slide description for the offline-support feature
  ///
  /// In ru, this message translates to:
  /// **'Продавайте без интернета — данные синхронизируются автоматически'**
  String get onboardingOfflineDesc;

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

  /// Validation error shown on the create-store form when the store name field is left empty; distinct from `enterName` ("Введите имя"), which asks for a person's name
  ///
  /// In ru, this message translates to:
  /// **'Введите название'**
  String get createStoreNameRequiredError;

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

  /// Create-store form's optional address field label; distinct from `storeAddress` ("Адрес магазина"), a differently-worded label used elsewhere
  ///
  /// In ru, this message translates to:
  /// **'Адрес (необязательно)'**
  String get createStoreAddressLabel;

  /// Create-store form's optional phone field label
  ///
  /// In ru, this message translates to:
  /// **'Телефон магазина (необязательно)'**
  String get createStorePhoneLabel;

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

  /// Add-product wizard app bar title (shown on all 3 wizard steps) — distinct from `addProduct` ("Добавить товар", the action button) and `editProduct` ("Редактировать товар", shown instead when editing an existing product)
  ///
  /// In ru, this message translates to:
  /// **'Новый товар'**
  String get newProductTitle;

  /// Add-product wizard step indicator label — step 1 (basic info)
  ///
  /// In ru, this message translates to:
  /// **'Основное'**
  String get addProductStepBasic;

  /// Add-product wizard step indicator label — step 2 (prices)
  ///
  /// In ru, this message translates to:
  /// **'Цены'**
  String get addProductStepPrices;

  /// Add-product wizard step indicator label — step 3 (stock)
  ///
  /// In ru, this message translates to:
  /// **'Склад'**
  String get addProductStepStock;

  /// Product name field
  ///
  /// In ru, this message translates to:
  /// **'Название товара'**
  String get productName;

  /// Generic bare 'Name' field/column label (e.g. table column header, form field for a category/supplier/investment name) — distinct from `name` ("Имя", a person's name) and `productName` ("Название товара", the fuller product-specific label)
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get itemName;

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

  /// Generic bare 'Price' column/field label — distinct from `costPrice` ("Цена закупки") and `sellPrice` ("Цена продажи")
  ///
  /// In ru, this message translates to:
  /// **'Цена'**
  String get price;

  /// Wholesale price form field label
  ///
  /// In ru, this message translates to:
  /// **'Оптовая цена'**
  String get wholesalePrice;

  /// Add-product step 2 — cost price form field label with a required-field asterisk; distinct from `dashboardCost` ("Себестоимость", the dashboard metric tile label, no asterisk) and `costPrice` ("Цена закупки", a differently-worded purchase-price label)
  ///
  /// In ru, this message translates to:
  /// **'Себестоимость *'**
  String get costPriceRequiredLabel;

  /// Add-product step 2 — sell price form field label with a required-field asterisk; distinct from `sellPrice` ("Цена продажи", no asterisk)
  ///
  /// In ru, this message translates to:
  /// **'Цена продажи *'**
  String get sellPriceRequiredLabel;

  /// Validation error shown when a cost price field is left empty
  ///
  /// In ru, this message translates to:
  /// **'Введите себестоимость'**
  String get costPriceRequiredError;

  /// Validation error shown when a sell price field is left empty
  ///
  /// In ru, this message translates to:
  /// **'Введите цену продажи'**
  String get sellPriceRequiredError;

  /// Generic validation error for a malformed numeric field value
  ///
  /// In ru, this message translates to:
  /// **'Неверный формат'**
  String get invalidFormatError;

  /// Generic 'name is required' validation error, used across multiple forms with a name field
  ///
  /// In ru, this message translates to:
  /// **'Введите имя'**
  String get enterName;

  /// Generic 'phone number is required' validation error, used across multiple auth/contact forms
  ///
  /// In ru, this message translates to:
  /// **'Введите номер телефона'**
  String get phoneRequired;

  /// Generic password-too-short validation error, used across multiple password forms
  ///
  /// In ru, this message translates to:
  /// **'Минимум 6 символов'**
  String get passwordMinLength;

  /// Generic 'passwords do not match' validation error, used across multiple password-confirmation forms
  ///
  /// In ru, this message translates to:
  /// **'Пароли не совпадают'**
  String get passwordsDoNotMatch;

  /// Generic 'invalid amount' validation error, used across multiple forms with a monetary/numeric amount field
  ///
  /// In ru, this message translates to:
  /// **'Некорректная сумма'**
  String get invalidAmount;

  /// Generic 'invalid value' validation error for a numeric field that isn't specifically an amount
  ///
  /// In ru, this message translates to:
  /// **'Некорректное значение'**
  String get invalidValue;

  /// Validation error shown when a percentage field's value falls outside the 0-100 range
  ///
  /// In ru, this message translates to:
  /// **'От 0 до 100'**
  String get percentRangeError;

  /// Quantity field
  ///
  /// In ru, this message translates to:
  /// **'Количество'**
  String get quantity;

  /// Abbreviated 'Qty' column/label for space-constrained UI (e.g. table columns) — distinct from `quantity` ("Количество", the full word)
  ///
  /// In ru, this message translates to:
  /// **'Кол-во'**
  String get quantityShort;

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

  /// Full-word 'Piece' unit label (unit picker) — distinct from `pcs` ("шт", the abbreviated symbol)
  ///
  /// In ru, this message translates to:
  /// **'Штука'**
  String get unitPiece;

  /// Full-word 'Kilogram' unit label (unit picker) — distinct from `kg` ("кг", the abbreviated symbol)
  ///
  /// In ru, this message translates to:
  /// **'Килограмм'**
  String get unitKilogram;

  /// Full-word 'Liter' unit label (unit picker) — distinct from `liter` ("л", the abbreviated symbol)
  ///
  /// In ru, this message translates to:
  /// **'Литр'**
  String get unitLiter;

  /// Full-word 'Meter' unit label (unit picker)
  ///
  /// In ru, this message translates to:
  /// **'Метр'**
  String get unitMeter;

  /// Full-word 'Box' unit label (unit picker)
  ///
  /// In ru, this message translates to:
  /// **'Коробка'**
  String get unitBox;

  /// Full-word 'Pack' unit label (unit picker) — distinct from `pack` ("уп", the abbreviated symbol)
  ///
  /// In ru, this message translates to:
  /// **'Упаковка'**
  String get unitPack;

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

  /// Import products screen — instructions shown before a file is picked
  ///
  /// In ru, this message translates to:
  /// **'Загрузите список товаров из Excel или CSV файла.\nСкачайте шаблон для правильного формата.'**
  String get importProductsSubtitle;

  /// Import products screen — button to open the file picker
  ///
  /// In ru, this message translates to:
  /// **'Выбрать файл'**
  String get importProductsSelectFile;

  /// Import products screen — button to download the import template file
  ///
  /// In ru, this message translates to:
  /// **'Скачать шаблон'**
  String get importProductsDownloadTemplate;

  /// Import products preview — summary bar showing how many rows were parsed from the file
  ///
  /// In ru, this message translates to:
  /// **'{count} товаров найдено'**
  String importProductsFoundCount(String count);

  /// Import products preview — compact badge showing the error count (count-first phrasing). Distinct from `importProductsErrorsSummary` ("Ошибки: {count}", label-first phrasing used in the completion dialog)
  ///
  /// In ru, this message translates to:
  /// **'{count} ошибок'**
  String importProductsErrorsBadge(String count);

  /// Import products — one row-level validation error, used both in the preview error list and the completion dialog's error list
  ///
  /// In ru, this message translates to:
  /// **'Строка {row}: {message}'**
  String importProductsRowError(String row, String message);

  /// Import products preview — button to confirm the import of the parsed rows
  ///
  /// In ru, this message translates to:
  /// **'Импортировать {count} товаров'**
  String importProductsConfirmButton(String count);

  /// Title of the dialog shown after an import finishes
  ///
  /// In ru, this message translates to:
  /// **'Импорт завершён'**
  String get importProductsCompleted;

  /// Import completion dialog — number of products created
  ///
  /// In ru, this message translates to:
  /// **'Создано: {count}'**
  String importProductsCreatedCount(String count);

  /// Import completion dialog — number of rows skipped
  ///
  /// In ru, this message translates to:
  /// **'Пропущено: {count}'**
  String importProductsSkippedCount(String count);

  /// Import completion dialog — label-first error count summary line. Distinct from `importProductsErrorsBadge` ("{count} ошибок", count-first phrasing used in the preview badge)
  ///
  /// In ru, this message translates to:
  /// **'Ошибки: {count}'**
  String importProductsErrorsSummary(String count);

  /// Import completion dialog — shown when there are more errors than fit in the visible list
  ///
  /// In ru, this message translates to:
  /// **'...и ещё {count}'**
  String importProductsMoreErrorsCount(String count);

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

  /// Empty products page — headline shown when the store has no products yet
  ///
  /// In ru, this message translates to:
  /// **'Добавьте свой первый товар'**
  String get emptyProductsTitle;

  /// Empty products page — subtitle explaining the benefit of adding products
  ///
  /// In ru, this message translates to:
  /// **'Начните добавлять товары в ваш магазин, чтобы управлять продажами и складом'**
  String get emptyProductsSubtitle;

  /// Button label to import data from an Excel file; generic (also appears on the product list page's overflow menu)
  ///
  /// In ru, this message translates to:
  /// **'Импорт из Excel'**
  String get importFromExcel;

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

  /// Checkout screen — title of the confirmation dialog shown before a CARD payment is processed (cash and debt already require a dedicated confirming screen; this gives CARD the same review-before-submit step, SPEC.md #8)
  ///
  /// In ru, this message translates to:
  /// **'Оплата картой?'**
  String get cardPaymentConfirmTitle;

  /// Checkout screen — body of the CARD payment confirmation dialog; placeholder is the pre-formatted total (amount + currency), following this file's String-only placeholder convention
  ///
  /// In ru, this message translates to:
  /// **'Сумма к оплате: {total}'**
  String cardPaymentConfirmMessage(String total);

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

  /// Bank transfer payment method option (distinct from the POS cash/card/debt/mixed payment methods)
  ///
  /// In ru, this message translates to:
  /// **'Перевод'**
  String get transfer;

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

  /// Snackbar shown when the cart quantity stepper's "+" button is pressed but the item is already at the product's full stock quantity — distinct from `outOfStock` ("Нет в наличии"), which labels a product with zero stock rather than a blocked increment
  ///
  /// In ru, this message translates to:
  /// **'Больше нет в наличии'**
  String get cartMaxStockReached;

  /// Cart restore prompt — dialog title asking whether to restore a previously persisted POS cart on cold start
  ///
  /// In ru, this message translates to:
  /// **'Восстановить корзину?'**
  String get cartRestoreDialogTitle;

  /// Cart restore prompt — dialog body. {time} is a pre-formatted relative-time string (see justNow/minutesAgo/hoursAgo/daysAgo), {count} is the pre-formatted saved-cart item count
  ///
  /// In ru, this message translates to:
  /// **'Найдена сохранённая корзина ({time}, {count} товаров).'**
  String cartRestoreDialogMessage(String time, String count);

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

  /// Generic 'no sales yet' empty-state headline — dashboard's Recent Sales card caption and empty sales page's headline (formerly `dashboardNoSalesYet`, renamed/generalized when reused on a second screen); distinct from `noSales` ("Нет продаж"), a shorter placeholder used elsewhere
  ///
  /// In ru, this message translates to:
  /// **'Пока нет продаж'**
  String get noSalesYet;

  /// Empty sales page — subtitle explaining that a sale made via checkout will appear here
  ///
  /// In ru, this message translates to:
  /// **'Совершите первую продажу через кассу, и она появится здесь'**
  String get emptySalesSubtitle;

  /// Empty sales page — button label to navigate to the POS checkout
  ///
  /// In ru, this message translates to:
  /// **'Перейти к кассе'**
  String get emptySalesGoToCheckout;

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

  /// More page — sales/finance section header
  ///
  /// In ru, this message translates to:
  /// **'Продажи и Финансы'**
  String get moreSalesFinanceTitle;

  /// More page — staff section header
  ///
  /// In ru, this message translates to:
  /// **'Персонал'**
  String get moreStaffTitle;

  /// More page — menu item linking to the roles & permissions screen
  ///
  /// In ru, this message translates to:
  /// **'Роли и права'**
  String get moreRolesAndPermissions;

  /// More page — counterparties (customers/suppliers) section header
  ///
  /// In ru, this message translates to:
  /// **'Контрагенты'**
  String get moreCounterpartiesTitle;

  /// More page — menu item linking to the customer list
  ///
  /// In ru, this message translates to:
  /// **'Клиенты'**
  String get moreClients;

  /// More page — store section header. Distinct from `dashboardStoreFallback` ("Магазин" used as a placeholder store name before one is selected)
  ///
  /// In ru, this message translates to:
  /// **'Магазин'**
  String get moreStoreTitle;

  /// More page — menu item linking to the user's store list
  ///
  /// In ru, this message translates to:
  /// **'Мои магазины'**
  String get moreMyStores;

  /// Offline mode message
  ///
  /// In ru, this message translates to:
  /// **'Нет подключения к интернету. Работаем офлайн.'**
  String get offline;

  /// Offline mode page — button that clears the locally displayed last-synced timestamp and pending-ops count. It does NOT delete any cached product/category/sale data (that data doubles as the offline-first read source and may hold unsynced local writes), so the label must not say anything implying data is erased
  ///
  /// In ru, this message translates to:
  /// **'Сбросить статус синхронизации'**
  String get offlineResetSyncStatusButton;

  /// Confirmation dialog title for offlineResetSyncStatusButton
  ///
  /// In ru, this message translates to:
  /// **'Сбросить статус синхронизации?'**
  String get offlineResetSyncStatusTitle;

  /// Confirmation dialog body for offlineResetSyncStatusButton — clarifies no local data is deleted
  ///
  /// In ru, this message translates to:
  /// **'Отметка времени последней синхронизации и счётчик операций в очереди будут сброшены на этом устройстве. Локальные данные не удаляются.'**
  String get offlineResetSyncStatusBody;

  /// Confirm action in the offlineResetSyncStatusButton dialog
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get offlineResetSyncStatusConfirm;

  /// Dashboard header greeting
  ///
  /// In ru, this message translates to:
  /// **'Салом 👋'**
  String get dashboardGreeting;

  /// Fallback store name shown before a store is selected
  ///
  /// In ru, this message translates to:
  /// **'Магазин'**
  String get dashboardStoreFallback;

  /// Store selector bottom sheet title
  ///
  /// In ru, this message translates to:
  /// **'Выберите магазин'**
  String get dashboardSelectStoreTitle;

  /// Cost-of-goods metric tile label
  ///
  /// In ru, this message translates to:
  /// **'Себестоимость'**
  String get dashboardCost;

  /// Dashboard action tiles section title
  ///
  /// In ru, this message translates to:
  /// **'Операции'**
  String get dashboardOperationsTitle;

  /// Stock levels action tile title
  ///
  /// In ru, this message translates to:
  /// **'Остатки на складе'**
  String get dashboardStockTitle;

  /// Stock levels action tile subtitle (no low-stock items)
  ///
  /// In ru, this message translates to:
  /// **'{count} товаров'**
  String dashboardStockSubtitle(String count);

  /// Stock levels action tile subtitle (with low-stock items)
  ///
  /// In ru, this message translates to:
  /// **'{count} товаров · {lowCount} мало'**
  String dashboardStockSubtitleLow(String count, String lowCount);

  /// Customer debts action tile title
  ///
  /// In ru, this message translates to:
  /// **'Вам должны'**
  String get dashboardCustomerOwedTitle;

  /// Customer debts action tile subtitle (active debts)
  ///
  /// In ru, this message translates to:
  /// **'Долги клиентов по продажам'**
  String get dashboardCustomerOwedSubtitle;

  /// Supplier debts action tile title
  ///
  /// In ru, this message translates to:
  /// **'Вы должны'**
  String get dashboardSupplierOwedTitle;

  /// Supplier debts action tile subtitle (active debts)
  ///
  /// In ru, this message translates to:
  /// **'Долги поставщикам'**
  String get dashboardSupplierOwedSubtitle;

  /// Inventory count action tile subtitle
  ///
  /// In ru, this message translates to:
  /// **'Проверить фактические остатки'**
  String get dashboardInventorySubtitle;

  /// Recent sales section title
  ///
  /// In ru, this message translates to:
  /// **'Последние продажи'**
  String get dashboardRecentSalesTitle;

  /// Link to full sales history
  ///
  /// In ru, this message translates to:
  /// **'Все продажи >'**
  String get dashboardAllSalesLink;

  /// Hero revenue card label, today period
  ///
  /// In ru, this message translates to:
  /// **'Выручка сегодня'**
  String get dashboardRevenueToday;

  /// Hero revenue card label, week period
  ///
  /// In ru, this message translates to:
  /// **'Выручка за неделю'**
  String get dashboardRevenueWeek;

  /// Hero revenue card label, month period
  ///
  /// In ru, this message translates to:
  /// **'Выручка за месяц'**
  String get dashboardRevenueMonth;

  /// Hero revenue card label, custom period
  ///
  /// In ru, this message translates to:
  /// **'Выручка за период'**
  String get dashboardRevenuePeriod;

  /// Hero revenue card sales count meta
  ///
  /// In ru, this message translates to:
  /// **'{count} продаж'**
  String dashboardSalesCountLabel(String count);

  /// Hero revenue card average check meta
  ///
  /// In ru, this message translates to:
  /// **'Средний чек {value}'**
  String dashboardAvgCheckLabel(String value);

  /// Recent sale card receipt number label
  ///
  /// In ru, this message translates to:
  /// **'Чек #{receiptNo}'**
  String dashboardSaleReceiptLabel(String receiptNo);

  /// Inventory count feature name — used both as the dashboard tile title and the inventory count screen's own AppBar title
  ///
  /// In ru, this message translates to:
  /// **'Инвентаризация'**
  String get inventoryTitle;

  /// Inventory count start screen description
  ///
  /// In ru, this message translates to:
  /// **'Запустите инвентаризацию, чтобы сверить фактические остатки товаров с ожидаемыми.'**
  String get inventoryCountIntro;

  /// Button to begin an inventory count
  ///
  /// In ru, this message translates to:
  /// **'Начать инвентаризацию'**
  String get inventoryCountStart;

  /// AppBar title during the inventory count entry step
  ///
  /// In ru, this message translates to:
  /// **'Подсчёт'**
  String get inventoryCountingTitle;

  /// Hint shown above the inventory count product list
  ///
  /// In ru, this message translates to:
  /// **'Нажмите на строку для редактирования'**
  String get inventoryCountEditHint;

  /// Expected quantity shown under a product row during inventory count
  ///
  /// In ru, this message translates to:
  /// **'Ожидается: {expected}'**
  String inventoryExpectedLine(String expected);

  /// AppBar title on the inventory count diff/results step
  ///
  /// In ru, this message translates to:
  /// **'Результаты'**
  String get inventoryResultsTitle;

  /// Inventory count diff table column header for expected quantity
  ///
  /// In ru, this message translates to:
  /// **'Ожидалось'**
  String get inventoryExpectedColumn;

  /// Inventory count diff table column header for actual counted quantity
  ///
  /// In ru, this message translates to:
  /// **'Факт'**
  String get inventoryActualColumn;

  /// Heading shown once an inventory count has been applied
  ///
  /// In ru, this message translates to:
  /// **'Инвентаризация завершена'**
  String get inventoryCountCompleted;

  /// Subtitle shown once an inventory count has been applied
  ///
  /// In ru, this message translates to:
  /// **'Остатки товаров успешно обновлены.'**
  String get inventoryCountUpdated;

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

  /// Prompt shown on a customer-picker sheet/field, and used as the placeholder text before a customer is chosen — uses "клиент" (client), the wording this app's customer-list feature uses, distinct from the bare `customer` ("Покупатель") label
  ///
  /// In ru, this message translates to:
  /// **'Выберите клиента'**
  String get selectCustomer;

  /// Title for creating a new customer (dialog/screen), or the fallback title when a customer form isn't in edit mode
  ///
  /// In ru, this message translates to:
  /// **'Новый клиент'**
  String get newCustomer;

  /// Title for editing an existing customer (dialog/screen) — pairs with `newCustomer` as the alternate title when a customer form is in edit mode
  ///
  /// In ru, this message translates to:
  /// **'Редактировать клиента'**
  String get editCustomer;

  /// Success message shown after a customer is created
  ///
  /// In ru, this message translates to:
  /// **'Клиент добавлен'**
  String get customerAdded;

  /// Success message shown after a customer is updated
  ///
  /// In ru, this message translates to:
  /// **'Клиент обновлён'**
  String get customerUpdated;

  /// Phone field label with inline country-code hint, specific to the customer create/edit form — distinct from the bare `phoneLabel` ("Телефон") used elsewhere
  ///
  /// In ru, this message translates to:
  /// **'Телефон (+992)'**
  String get customerFormPhoneLabel;

  /// Validation error shown on the customer form's phone field when the entered number doesn't start with the +992/992 country code — distinct from `phoneRequired` ("Введите номер телефона"), which just checks the field isn't empty
  ///
  /// In ru, this message translates to:
  /// **'Введите номер с кодом +992'**
  String get customerFormPhoneCodeError;

  /// Title for creating a new supplier (screen), or the fallback title when a supplier form isn't in edit mode
  ///
  /// In ru, this message translates to:
  /// **'Новый поставщик'**
  String get newSupplier;

  /// Title for editing an existing supplier (screen) — pairs with `newSupplier` as the alternate title when a supplier form is in edit mode
  ///
  /// In ru, this message translates to:
  /// **'Редактировать поставщика'**
  String get editSupplier;

  /// Success message shown after a supplier is created
  ///
  /// In ru, this message translates to:
  /// **'Поставщик добавлен'**
  String get supplierAdded;

  /// Success message shown after a supplier is updated
  ///
  /// In ru, this message translates to:
  /// **'Поставщик обновлён'**
  String get supplierUpdated;

  /// Generic address field label, used on forms such as the supplier create/edit form — distinct from `storeAddress` ("Адрес магазина", the store's own address) and `deliveryDetailAddressLabel` (an info-row label on the delivery detail screen)
  ///
  /// In ru, this message translates to:
  /// **'Адрес'**
  String get address;

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

  /// Generic 'Balance' label — used as the balance screen's AppBar title
  ///
  /// In ru, this message translates to:
  /// **'Баланс'**
  String get balance;

  /// Generic 'Current balance' label shown above the balance figure
  ///
  /// In ru, this message translates to:
  /// **'Текущий баланс'**
  String get currentBalance;

  /// Generic chart/trend section title ('Dynamics') above an income/expense line chart
  ///
  /// In ru, this message translates to:
  /// **'Динамика'**
  String get dynamics;

  /// Generic 'Transactions' list section header
  ///
  /// In ru, this message translates to:
  /// **'Транзакции'**
  String get transactions;

  /// Empty state shown when a transactions list has no items
  ///
  /// In ru, this message translates to:
  /// **'Транзакций нет'**
  String get noTransactions;

  /// No description provided for @income.
  ///
  /// In ru, this message translates to:
  /// **'Доход'**
  String get income;

  /// Plural 'Incomes' label used where it's paired with `expenses` ("Расходы") in a legend/summary — distinct from singular `income` ("Доход") used as a bare dashboard stat label
  ///
  /// In ru, this message translates to:
  /// **'Доходы'**
  String get incomes;

  /// No description provided for @expenses.
  ///
  /// In ru, this message translates to:
  /// **'Расходы'**
  String get expenses;

  /// Singular 'Expense' label — e.g. a transaction-type fallback description when no other text is available — distinct from plural `expenses` ("Расходы")
  ///
  /// In ru, this message translates to:
  /// **'Расход'**
  String get expense;

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

  /// No description provided for @today.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get yesterday;

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

  /// Generic 'Amount (TJS)' field label with currency suffix — distinct from bare `amount` ("Сумма"); this exact literal also recurs verbatim on other payment-amount fields (e.g. the payroll adjustment screen)
  ///
  /// In ru, this message translates to:
  /// **'Сумма (TJS)'**
  String get amountTjs;

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

  /// Credits/loans feature name — used as the credits screen's AppBar title; the same word also labels this feature's entry on the finance dashboard
  ///
  /// In ru, this message translates to:
  /// **'Кредиты'**
  String get credits;

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

  /// Snackbar shown when a debt payment is submitted while offline and queued for later sync
  ///
  /// In ru, this message translates to:
  /// **'Платёж сохранён офлайн — отправим при подключении'**
  String get paymentQueuedOfflineMessage;

  /// No description provided for @paymentHistory.
  ///
  /// In ru, this message translates to:
  /// **'История оплат'**
  String get paymentHistory;

  /// No description provided for @noPaymentRecords.
  ///
  /// In ru, this message translates to:
  /// **'Нет записей об оплате'**
  String get noPaymentRecords;

  /// Credits screen — shown in a receivables/payables tab when there are no items
  ///
  /// In ru, this message translates to:
  /// **'Записей нет'**
  String get creditsEmptyState;

  /// Credits screen — summary card label on the receivables tab (total owed to the store)
  ///
  /// In ru, this message translates to:
  /// **'Общий долг нам'**
  String get creditsTotalReceivableLabel;

  /// Credits screen — summary card label on the payables tab (total the store owes suppliers)
  ///
  /// In ru, this message translates to:
  /// **'Общий долг поставщикам'**
  String get creditsTotalPayableLabel;

  /// Credits screen — summary card badge showing how many counterparties make up the total (count-first, abbreviated 'people')
  ///
  /// In ru, this message translates to:
  /// **'{count} чел.'**
  String creditsPersonCountLabel(String count);

  /// Credits screen — abbreviated 'last [payment]: {date}' shown on a credit card (date already pre-formatted, or '—' if there was no payment yet)
  ///
  /// In ru, this message translates to:
  /// **'посл. {date}'**
  String creditsLastPaymentLabel(String date);

  /// Credits screen — button label and payment dialog title on the receivables tab (accepting a payment owed to the store)
  ///
  /// In ru, this message translates to:
  /// **'Принять платёж'**
  String get creditsAcceptPayment;

  /// Credits screen — button label and payment dialog title on the payables tab (the store paying a supplier)
  ///
  /// In ru, this message translates to:
  /// **'Внести платёж'**
  String get creditsMakePayment;

  /// Credits screen — payment dialog dropdown label. Wording differs slightly from the existing `paymentMethod` ("Способ оплаты") key; kept as-is to preserve this screen's original text rather than silently changing displayed copy
  ///
  /// In ru, this message translates to:
  /// **'Метод оплаты'**
  String get creditsPaymentMethodLabel;

  /// Credits screen — payment dialog validation error when the entered amount is missing or not positive
  ///
  /// In ru, this message translates to:
  /// **'Введите корректную сумму'**
  String get creditsInvalidAmountError;

  /// Credit-sale screen — app bar title. Distinct from `debtSales` ("Продажи в долг", plural, the Z-report category label)
  ///
  /// In ru, this message translates to:
  /// **'Продажа в долг'**
  String get creditSaleTitle;

  /// Credit-sale screen — the formatted debt total with currency suffix, shown below the `debtAmount` ("Сумма долга") heading label
  ///
  /// In ru, this message translates to:
  /// **'{amount} сом.'**
  String creditSaleAmountLabel(String amount);

  /// Credit-sale screen — required-field section label above the customer picker
  ///
  /// In ru, this message translates to:
  /// **'Клиент *'**
  String get creditSaleCustomerRequiredLabel;

  /// Credit-sale screen — section label above the due-date picker
  ///
  /// In ru, this message translates to:
  /// **'Срок оплаты'**
  String get creditSaleDueDateLabel;

  /// Credit-sale screen — section label above the optional note field. Distinct from `notes` ("Заметки", a different generic list-of-notes label)
  ///
  /// In ru, this message translates to:
  /// **'Примечание'**
  String get creditSaleNoteLabel;

  /// Credit-sale screen — hint text inside the empty note field
  ///
  /// In ru, this message translates to:
  /// **'Добавьте примечание (необязательно)'**
  String get creditSaleNoteHint;

  /// Credit-sale screen — button on the customer picker sheet to open the new-customer dialog
  ///
  /// In ru, this message translates to:
  /// **'Создать нового клиента'**
  String get creditSaleCreateCustomerButton;

  /// Credit-sale screen — primary button to submit the credit sale (shows `processing` instead while the request is in flight)
  ///
  /// In ru, this message translates to:
  /// **'Оформить в долг'**
  String get creditSaleConfirmButton;

  /// Credit-sale screen — shown on the customer picker sheet when the store has no customers yet
  ///
  /// In ru, this message translates to:
  /// **'Список клиентов пуст'**
  String get creditSaleCustomerListEmpty;

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

  /// Generic 'current password is required' validation error, used across password-change forms
  ///
  /// In ru, this message translates to:
  /// **'Введите текущий пароль'**
  String get currentPasswordRequired;

  /// Generic 'new password is required' validation error, used across password-change forms
  ///
  /// In ru, this message translates to:
  /// **'Введите новый пароль'**
  String get newPasswordRequired;

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

  /// Expense list summary card: label for the total-spend-in-period stat, paired above the 'today' stat
  ///
  /// In ru, this message translates to:
  /// **'За период'**
  String get expenseListForPeriod;

  /// Expense list empty-state subtitle shown when there are no expenses yet
  ///
  /// In ru, this message translates to:
  /// **'Добавьте первый расход, чтобы видеть финансовую картину'**
  String get expenseListEmptySubtitle;

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

  /// Call action button label — used on contact-detail screens' action-button row (e.g. supplier detail), opens the phone dialer
  ///
  /// In ru, this message translates to:
  /// **'Звонок'**
  String get call;

  /// SMS action button label — used on contact-detail screens' action-button row (e.g. supplier detail), opens the SMS composer
  ///
  /// In ru, this message translates to:
  /// **'СМС'**
  String get sms;

  /// Generic 'Order' label — delivery detail screen's info row label for the order number, and supplier detail screen's place-order action button caption (formerly `deliveryDetailOrderLabel`, renamed/generalized when reused on a second screen)
  ///
  /// In ru, this message translates to:
  /// **'Заказ'**
  String get order;

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

  /// Delivery detail screen — AppBar title
  ///
  /// In ru, this message translates to:
  /// **'Детали доставки'**
  String get deliveryDetailTitle;

  /// Delivery detail screen — info row label for the customer name; distinct from `customer` ("Покупатель"), used verbatim as "Клиент" on this screen
  ///
  /// In ru, this message translates to:
  /// **'Клиент'**
  String get deliveryDetailCustomerLabel;

  /// Delivery detail screen — info row label for the delivery address
  ///
  /// In ru, this message translates to:
  /// **'Адрес'**
  String get deliveryDetailAddressLabel;

  /// Delivery detail screen — action button shown for a new order, marks it picked up / in transit
  ///
  /// In ru, this message translates to:
  /// **'Забрал'**
  String get deliveryDetailPickedUpButton;

  /// Delivery detail screen — action button shown for an in-transit order, marks it delivered
  ///
  /// In ru, this message translates to:
  /// **'Доставлено'**
  String get deliveryDetailDeliveredButton;

  /// Delivery detail screen — status stepper label for the 'created' step
  ///
  /// In ru, this message translates to:
  /// **'Создан'**
  String get deliveryDetailStepCreated;

  /// Delivery detail screen — status stepper label for the 'in transit' step
  ///
  /// In ru, this message translates to:
  /// **'В пути'**
  String get deliveryDetailStepInTransit;

  /// Delivery detail screen — status stepper label for the 'delivered' step; distinct grammatical form from `deliveryDetailDeliveredButton` ("Доставлено")
  ///
  /// In ru, this message translates to:
  /// **'Доставлен'**
  String get deliveryDetailStepDelivered;

  /// Delivery list screen — AppBar title; distinct from `deliveryDetailTitle` ("Детали доставки")
  ///
  /// In ru, this message translates to:
  /// **'Доставки'**
  String get deliveryListTitle;

  /// Delivery list screen — filter tab label for orders not yet in transit (plural adjective, distinct from `deliveryListStatusNew` which is singular)
  ///
  /// In ru, this message translates to:
  /// **'Новые'**
  String get deliveryListTabNew;

  /// Delivery list screen — filter tab label for delivered orders (plural, distinct from `deliveryDetailStepDelivered` "Доставлен" which is singular)
  ///
  /// In ru, this message translates to:
  /// **'Доставлены'**
  String get deliveryListTabDelivered;

  /// Delivery list screen — empty-state message shown when there are no deliveries; distinct from `noDeliveryData` ("Нет данных о поставках"), which is the supplier-deliveries empty state
  ///
  /// In ru, this message translates to:
  /// **'Доставок пока нет'**
  String get deliveryListEmptyState;

  /// Delivery list screen — status badge label on a delivery card for a newly created order
  ///
  /// In ru, this message translates to:
  /// **'Новый'**
  String get deliveryListStatusNew;

  /// Loyalty settings screen — AppBar title
  ///
  /// In ru, this message translates to:
  /// **'Программа лояльности'**
  String get loyaltySettingsTitle;

  /// Loyalty settings screen — AppBar action button navigating to loyalty analytics
  ///
  /// In ru, this message translates to:
  /// **'Аналитика'**
  String get loyaltySettingsAnalytics;

  /// Loyalty settings screen — label next to the enable/disable toggle
  ///
  /// In ru, this message translates to:
  /// **'Активна'**
  String get loyaltySettingsActive;

  /// Loyalty settings screen — section header for the points-accrual fields
  ///
  /// In ru, this message translates to:
  /// **'Начисление баллов'**
  String get loyaltySettingsAccrualSection;

  /// Loyalty settings screen — field label for the spend amount that earns points
  ///
  /// In ru, this message translates to:
  /// **'За каждые __ сом'**
  String get loyaltySettingsAmountForPointsLabel;

  /// Loyalty settings screen — field label for how many points are awarded per the configured amount
  ///
  /// In ru, this message translates to:
  /// **'Начислять __ баллов'**
  String get loyaltySettingsPointsPerAmountLabel;

  /// Loyalty settings screen — field label for the monetary value of one point
  ///
  /// In ru, this message translates to:
  /// **'1 балл = __ сом'**
  String get loyaltySettingsPointValueLabel;

  /// Loyalty settings screen — section header for the bonus fields (welcome points, birthday discount, points expiry)
  ///
  /// In ru, this message translates to:
  /// **'Бонусы'**
  String get loyaltySettingsBonusSection;

  /// Loyalty settings screen — field label for points granted to new customers
  ///
  /// In ru, this message translates to:
  /// **'Приветственные баллы'**
  String get loyaltySettingsWelcomePointsLabel;

  /// Loyalty settings screen — field label for the birthday discount percentage
  ///
  /// In ru, this message translates to:
  /// **'Скидка в день рождения, %'**
  String get loyaltySettingsBirthdayDiscountLabel;

  /// Loyalty settings screen — hint for the optional birthday discount field
  ///
  /// In ru, this message translates to:
  /// **'Оставьте пустым, если не нужно'**
  String get loyaltySettingsBirthdayDiscountHint;

  /// Loyalty settings screen — field label for the number of days before points expire
  ///
  /// In ru, this message translates to:
  /// **'Срок действия баллов, дней'**
  String get loyaltySettingsPointsExpireDaysLabel;

  /// Loyalty settings screen — hint for the optional points-expiry field, distinct from `loyaltySettingsBirthdayDiscountHint`
  ///
  /// In ru, this message translates to:
  /// **'Оставьте пустым — баллы не сгорают'**
  String get loyaltySettingsPointsExpireDaysHint;

  /// Loyalty analytics screen — AppBar title
  ///
  /// In ru, this message translates to:
  /// **'Аналитика баллов'**
  String get loyaltyAnalyticsTitle;

  /// Loyalty analytics screen — stat card label for total points earned in the selected period
  ///
  /// In ru, this message translates to:
  /// **'Начислено'**
  String get loyaltyAnalyticsEarnedLabel;

  /// Loyalty analytics screen — stat card label for total points redeemed in the selected period
  ///
  /// In ru, this message translates to:
  /// **'Списано'**
  String get loyaltyAnalyticsRedeemedLabel;

  /// Loyalty analytics screen — stat card label for total points expired in the selected period
  ///
  /// In ru, this message translates to:
  /// **'Сгорело'**
  String get loyaltyAnalyticsExpiredLabel;

  /// Loyalty analytics screen — stat card label for the monetary discount value granted via points redemption
  ///
  /// In ru, this message translates to:
  /// **'Экономия'**
  String get loyaltyAnalyticsSavingsLabel;

  /// Loyalty analytics screen — a points count formatted as '<n> points'; used for the earned/redeemed/expired stat card values and each top customer's balance
  ///
  /// In ru, this message translates to:
  /// **'{value} баллов'**
  String loyaltyAnalyticsPointsValue(String value);

  /// Loyalty analytics screen — the savings stat card value, a monetary amount in somoni
  ///
  /// In ru, this message translates to:
  /// **'{value} сом'**
  String loyaltyAnalyticsSavingsValue(String value);

  /// Loyalty analytics screen — count of customers with loyalty activity in the selected period
  ///
  /// In ru, this message translates to:
  /// **'Активных участников: {value}'**
  String loyaltyAnalyticsActiveParticipantsLabel(String value);

  /// Loyalty analytics screen — section header above the top-customers-by-balance list
  ///
  /// In ru, this message translates to:
  /// **'Топ клиентов'**
  String get loyaltyAnalyticsTopCustomersTitle;

  /// Printer settings screen — AppBar title
  ///
  /// In ru, this message translates to:
  /// **'Настройки принтера'**
  String get printerSettingsTitle;

  /// Printer settings screen — connection status label shown when a printer is connected
  ///
  /// In ru, this message translates to:
  /// **'Подключён'**
  String get printerSettingsConnected;

  /// Printer settings screen — connection status label shown when no printer is connected; distinct from `snackPrinterNotConnected`, which is a full sentence with instructions
  ///
  /// In ru, this message translates to:
  /// **'Не подключён'**
  String get printerSettingsNotConnected;

  /// Printer settings screen — button to disconnect the currently connected printer
  ///
  /// In ru, this message translates to:
  /// **'Отключить'**
  String get printerSettingsDisconnectButton;

  /// Printer settings screen — section header above the saved default printer name
  ///
  /// In ru, this message translates to:
  /// **'Принтер по умолчанию'**
  String get printerSettingsDefaultPrinterLabel;

  /// Printer settings screen — button to start scanning for nearby Bluetooth printers
  ///
  /// In ru, this message translates to:
  /// **'Найти принтеры'**
  String get printerSettingsScanButton;

  /// Printer settings screen — scan button label while a scan is in progress
  ///
  /// In ru, this message translates to:
  /// **'Поиск...'**
  String get printerSettingsScanningButton;

  /// Printer settings screen — section header above the list of discovered Bluetooth devices
  ///
  /// In ru, this message translates to:
  /// **'Найденные устройства'**
  String get printerSettingsFoundDevicesTitle;

  /// Printer settings screen — button to send a test print to the connected printer
  ///
  /// In ru, this message translates to:
  /// **'Тестовая печать'**
  String get printerSettingsTestPrintButton;

  /// Printer settings screen — test print button label while printing is in progress
  ///
  /// In ru, this message translates to:
  /// **'Печать...'**
  String get printerSettingsPrintingButton;

  /// Printer settings screen — badge shown on a discovered device tile when it's the saved default printer; distinct from `printerSettingsDefaultPrinterLabel` (a section header) and `printerSettingsSetDefaultButton` (an action)
  ///
  /// In ru, this message translates to:
  /// **'По умолчанию'**
  String get printerSettingsDefaultBadge;

  /// Printer settings screen — button on a device tile to connect to that printer
  ///
  /// In ru, this message translates to:
  /// **'Подключить'**
  String get printerSettingsConnectButton;

  /// Printer settings screen — abbreviated button on a connected device tile to set it as the default printer
  ///
  /// In ru, this message translates to:
  /// **'По умолч.'**
  String get printerSettingsSetDefaultButton;

  /// Ecommerce settings screen — AppBar title
  ///
  /// In ru, this message translates to:
  /// **'Интернет-магазин'**
  String get ecommerceSettingsTitle;

  /// Ecommerce settings screen — field label above the read-only inbound webhook URL that the storefront should send orders to
  ///
  /// In ru, this message translates to:
  /// **'URL для входящих заказов'**
  String get ecommerceSettingsInboundUrlLabel;

  /// Ecommerce settings screen — field label above the API key value; distinct from `ecommerceSettingsKeyLabel`, the short noun used in the copied-to-clipboard snackbar
  ///
  /// In ru, this message translates to:
  /// **'API-ключ'**
  String get ecommerceSettingsApiKeyLabel;

  /// Ecommerce settings screen — placeholder shown in the API key field before the integration has been configured/saved
  ///
  /// In ru, this message translates to:
  /// **'Сохраните настройки, чтобы создать ключ'**
  String get ecommerceSettingsSaveToCreateKey;

  /// Ecommerce settings screen — short noun for the API key, used as the {label} in `ecommerceSettingsCopiedMessage` when the key is copied to clipboard
  ///
  /// In ru, this message translates to:
  /// **'Ключ'**
  String get ecommerceSettingsKeyLabel;

  /// Ecommerce settings screen — button to regenerate the API key
  ///
  /// In ru, this message translates to:
  /// **'Перегенерировать ключ'**
  String get ecommerceSettingsRegenerateKeyButton;

  /// Ecommerce settings screen — field label above the outbound webhook URL text field, where the store owner enters their storefront's webhook endpoint
  ///
  /// In ru, this message translates to:
  /// **'URL вебхука вашего сайта'**
  String get ecommerceSettingsOutboundUrlLabel;

  /// Ecommerce settings screen — label next to the enable/disable toggle
  ///
  /// In ru, this message translates to:
  /// **'Интеграция активна'**
  String get ecommerceSettingsIntegrationActiveLabel;

  /// Ecommerce settings screen — button navigating to the product mapping screen
  ///
  /// In ru, this message translates to:
  /// **'Сопоставление товаров'**
  String get ecommerceSettingsProductMappingButton;

  /// Ecommerce settings screen — snackbar shown after successfully regenerating the API key
  ///
  /// In ru, this message translates to:
  /// **'Ключ перегенерирован'**
  String get ecommerceSettingsKeyRegenerated;

  /// Ecommerce settings screen — snackbar shown after copying the inbound URL or API key to the clipboard; label is `URL` or `ecommerceSettingsKeyLabel`
  ///
  /// In ru, this message translates to:
  /// **'{label} скопирован(о)'**
  String ecommerceSettingsCopiedMessage(String label);

  /// Ecommerce product mapping screen — hint text on the search field for filtering the product list by name
  ///
  /// In ru, this message translates to:
  /// **'Поиск по названию товара'**
  String get ecommerceMappingSearchHint;

  /// Ecommerce product mapping screen — hint text on the text field where the store owner enters the storefront's external product id for a given local product
  ///
  /// In ru, this message translates to:
  /// **'Внешний ID'**
  String get ecommerceMappingExternalIdHint;

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

  /// Staff name field label on the add/edit staff form — distinct from bare `name` ("Имя")
  ///
  /// In ru, this message translates to:
  /// **'Имя сотрудника'**
  String get staffFormNameLabel;

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

  /// Short 'Admin' role label — distinct from `admin` ("Администратор", the full form); used in role pickers/chips where space is limited, recurs verbatim across several staff/role screens
  ///
  /// In ru, this message translates to:
  /// **'Админ'**
  String get adminRoleShort;

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

  /// Commission form field label with parenthesized percent sign — distinct from `commissionPercent` ("Комиссия %", no parentheses)
  ///
  /// In ru, this message translates to:
  /// **'Комиссия (%)'**
  String get commissionPercentField;

  /// No description provided for @baseSalary.
  ///
  /// In ru, this message translates to:
  /// **'Оклад'**
  String get baseSalary;

  /// Base salary form field label with currency suffix — distinct from bare `baseSalary` ("Оклад"), same pattern as `amountTjs`
  ///
  /// In ru, this message translates to:
  /// **'Оклад (TJS)'**
  String get baseSalaryTjs;

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

  /// No description provided for @zReportHeaderTitle.
  ///
  /// In ru, this message translates to:
  /// **'Z-ОТЧЁТ'**
  String get zReportHeaderTitle;

  /// No description provided for @zReportSalesCount.
  ///
  /// In ru, this message translates to:
  /// **'Количество продаж'**
  String get zReportSalesCount;

  /// No description provided for @zReportTotalSales.
  ///
  /// In ru, this message translates to:
  /// **'Итого продаж'**
  String get zReportTotalSales;

  /// No description provided for @zReportReturnsCount.
  ///
  /// In ru, this message translates to:
  /// **'Количество возвратов'**
  String get zReportReturnsCount;

  /// No description provided for @zReportReturnsAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма возвратов'**
  String get zReportReturnsAmount;

  /// No description provided for @zReportOpeningAmount.
  ///
  /// In ru, this message translates to:
  /// **'Начальная сумма'**
  String get zReportOpeningAmount;

  /// No description provided for @zReportCashSalesLabel.
  ///
  /// In ru, this message translates to:
  /// **'Продажи (нал.)'**
  String get zReportCashSalesLabel;

  /// No description provided for @zReportCashReturnsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Возвраты (нал.)'**
  String get zReportCashReturnsLabel;

  /// No description provided for @zReportExpectedAmount.
  ///
  /// In ru, this message translates to:
  /// **'Ожидаемая сумма'**
  String get zReportExpectedAmount;

  /// No description provided for @zReportActualAmount.
  ///
  /// In ru, this message translates to:
  /// **'Фактическая сумма'**
  String get zReportActualAmount;

  /// No description provided for @zReportPrintButton.
  ///
  /// In ru, this message translates to:
  /// **'Печать Z-отчёта'**
  String get zReportPrintButton;

  /// Z-report PDF receipt: sales/returns count summary line
  ///
  /// In ru, this message translates to:
  /// **'Продаж: {sales}  Возвратов: {returns}'**
  String zReportPdfSalesReturnsLine(String sales, String returns);

  /// Z-report PDF receipt: debt total line
  ///
  /// In ru, this message translates to:
  /// **'Долг: {debt}'**
  String zReportPdfDebtLine(String debt);

  /// Z-report PDF receipt: grand total line
  ///
  /// In ru, this message translates to:
  /// **'ИТОГО: {total} сом.'**
  String zReportPdfTotalLine(String total);

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

  /// Success message shown on the add-staff form after creating a staff member — distinct from `employeeCreated` ("Сотрудник создан"), different wording used elsewhere
  ///
  /// In ru, this message translates to:
  /// **'Сотрудник добавлен'**
  String get employeeAdded;

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

  /// Confirmation after offlineResetSyncStatusButton runs — replaces the old, inaccurate 'cache cleared' wording since no local data is actually deleted
  ///
  /// In ru, this message translates to:
  /// **'Статус синхронизации сброшен'**
  String get snackSyncStatusReset;

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
