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

  /// Generic destructive-confirmation dialog body warning the action is irreversible — reused across delete-confirmation dialogs for expenses, discounts, payroll adjustments, etc.
  ///
  /// In ru, this message translates to:
  /// **'Это действие нельзя отменить.'**
  String get actionCannotBeUndone;

  /// Generic delete-confirmation dialog body naming the item being deleted — reused by the discounts and categories list screens. Was `discountsDeleteConfirmBody`; promoted to an unprefixed generic key (value unchanged) when the categories screen needed the identical wording, rather than minting a duplicate value. Distinct from `actionCannotBeUndone` ("Это действие нельзя отменить."), which warns about irreversibility without naming the item
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите удалить \"{name}\"?'**
  String deleteConfirmBody(String name);

  /// Edit button
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get edit;

  /// Shorter-form edit action button (supplier detail page) — distinct from `edit` ("Редактировать"), a different Russian verb with the same intent
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get modify;

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

  /// Default hint/placeholder text inside a search input field (AppSearchBar). Distinct from `search` ("Поиск", the bare search action/label with no ellipsis) and from `printerSettingsScanningButton` ("Поиск..."), a coincidentally identical value that labels a printer-discovery button while a Bluetooth scan runs — not a text-field placeholder
  ///
  /// In ru, this message translates to:
  /// **'Поиск...'**
  String get searchPlaceholder;

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

  /// Bare 'Print' action button label — deliberately unprefixed and generic (sibling of `share` on the receipt-preview screen). Distinct from `printReceipt` ("Печать чека"), the longer noun phrase, and from `printReceiptButton` ("Печатать чек"), the imperative form.
  ///
  /// In ru, this message translates to:
  /// **'Печать'**
  String get printLabel;

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

  /// Generic 'Allow' / grant-permission action button — deliberately unprefixed, the affirmative half of any approval prompt (first use: approving an impersonation-access request from the notifications list). Distinct from `confirm` ("Подтвердить"), which confirms the user's own pending action rather than granting a third party access.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить'**
  String get allow;

  /// Generic 'Decline' / reject action button — deliberately unprefixed, the negative half of any approval prompt and the counterpart of `allow` (first use: rejecting an impersonation-access request from the notifications list). Distinct from `cancel` ("Отмена"), which aborts the user's own action rather than refusing someone else's request.
  ///
  /// In ru, this message translates to:
  /// **'Отклонить'**
  String get decline;

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

  /// Generic 'Reset' action — deliberately unprefixed, same class of generic action word as cancel/save/delete/create/retry
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get reset;

  /// Generic pagination button that appends the next page of results to an already-rendered list — deliberately unprefixed, same class of generic action word as retry/apply/reset. Distinct from `more` ("Ещё"), which is a bare 'More' navigation entry rather than a load-next-page action.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить ещё'**
  String get loadMore;

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

  /// Relative time — N days ago, abbreviated to a single-letter day unit ("д"). Distinct from `daysAgo` ("{days} дн назад"), which uses the two-letter "дн" abbreviation: both render N-days-ago, but the two wordings are pre-existing and used by different screens (this one by the notifications list), so they are kept as separate keys rather than one wording being silently changed to match the other. Placeholder is a pre-formatted String.
  ///
  /// In ru, this message translates to:
  /// **'{days} д назад'**
  String daysAgoShort(String days);

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

  /// Generic empty state for a customer picker list — deliberately unprefixed since any customer-selection UI could plausibly reuse it
  ///
  /// In ru, this message translates to:
  /// **'Нет клиентов'**
  String get noCustomers;

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

  /// Generic error shown when a screen cannot load store-scoped data because no store is selected — deliberately unprefixed, since nothing about the message is specific to one screen (promoted from the former `productDetailStoreNotSelectedError`, same value, when the notifications list needed the identical message).
  ///
  /// In ru, this message translates to:
  /// **'Магазин не выбран'**
  String get storeNotSelectedError;

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
  /// **'Продукты'**
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

  /// My-stores create/edit bottom sheet header when editing an existing store — same wording as the `a11yEditStore` tooltip but a different UI role (sheet header vs. icon-button tooltip), kept as a separate key
  ///
  /// In ru, this message translates to:
  /// **'Редактировать магазин'**
  String get myStoresEditTitle;

  /// My-stores create/edit bottom sheet header when adding a new store — also reused as the empty-state 'add store' button label on the same page, since both refer to the identical add-store action with identical wording
  ///
  /// In ru, this message translates to:
  /// **'Добавить магазин'**
  String get myStoresAddTitle;

  /// My-stores create/edit form's required name field label — distinct from `storeName` ("Название магазина") and `itemName` ("Название"), which are worded differently
  ///
  /// In ru, this message translates to:
  /// **'Название *'**
  String get myStoresNameLabel;

  /// My-stores create/edit form's required category field label — distinct from the bare `category` ("Категория", no asterisk) used elsewhere
  ///
  /// In ru, this message translates to:
  /// **'Категория *'**
  String get myStoresCategoryLabel;

  /// My-stores page — message shown when the user has no stores yet
  ///
  /// In ru, this message translates to:
  /// **'Нет магазинов'**
  String get myStoresEmptyState;

  /// My-stores page — badge label marking the currently selected/active store in the list
  ///
  /// In ru, this message translates to:
  /// **'Активный'**
  String get myStoresActiveStatus;

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

  /// Add-product wizard step indicator label — step 3 (stock). Distinct from `staffRoleWarehouseShort` (literally the same word "Склад" but meaning the warehouse staff role on the staff list page)
  ///
  /// In ru, this message translates to:
  /// **'Склад'**
  String get addProductStepStock;

  /// Add-product step 1 — product name form field label with a required-field asterisk; distinct from `productName` ("Название товара", the same wording without the asterisk, used where the field is not marked required)
  ///
  /// In ru, this message translates to:
  /// **'Название товара *'**
  String get addProductNameRequiredLabel;

  /// Add-product step 1 — SKU field label including the parenthetical latin hint; distinct from the bare `sku` key ("Артикул")
  ///
  /// In ru, this message translates to:
  /// **'Артикул (SKU)'**
  String get addProductSkuLabel;

  /// Add-product step 1 — accepted image formats and size limit hint under the photo upload zone
  ///
  /// In ru, this message translates to:
  /// **'JPG, PNG до 5MB'**
  String get addProductImageSizeHint;

  /// Add-product step 3 — opening stock quantity form field label with a required-field asterisk; distinct from `quantity` ("Количество"), the bare generic label
  ///
  /// In ru, this message translates to:
  /// **'Начальное количество *'**
  String get addProductInitialQuantityLabel;

  /// Validation error shown when the add-product initial quantity field is left empty
  ///
  /// In ru, this message translates to:
  /// **'Введите количество'**
  String get addProductQuantityRequiredError;

  /// Add-product step 3 — minimum stock threshold form field label; distinct from `productDetailMinStockLine` ("Минимальный: {qty} {unit}"), a product detail read-out line
  ///
  /// In ru, this message translates to:
  /// **'Минимальный остаток'**
  String get addProductMinStockLabel;

  /// Add-product step 3 — section heading above the product photo upload zone
  ///
  /// In ru, this message translates to:
  /// **'Фото товара'**
  String get addProductPhotoSectionLabel;

  /// Add-product step 3 — hint inside the empty photo upload zone prompting the user to tap it
  ///
  /// In ru, this message translates to:
  /// **'Нажмите для загрузки'**
  String get addProductTapToUploadHint;

  /// Success snackbar after the add-product wizard submits — tells the user the product is saved locally and will sync in the background
  ///
  /// In ru, this message translates to:
  /// **'Товар сохранён. Синхронизация в фоне.'**
  String get addProductSavedSyncingMessage;

  /// Generic 'Add photo' call-to-action inside an empty image upload zone (add-product step 1) — distinct from `a11yUploadPhoto` ("Загрузить фото", the screen-reader label on that same zone) and `editProfileChangePhotoLabel` ("Изменить фото", replacing an existing photo)
  ///
  /// In ru, this message translates to:
  /// **'Добавить фото'**
  String get addPhotoLabel;

  /// Product name field
  ///
  /// In ru, this message translates to:
  /// **'Название товара'**
  String get productName;

  /// Russian singular form of 'product(s)' used after a count on the categories list (e.g. "1 товар") — deliberately three separate keys rather than an ICU plural, per this file's String-only placeholder convention (mirrors recordsCountOne/Few/Many)
  ///
  /// In ru, this message translates to:
  /// **'товар'**
  String get productCountOne;

  /// Russian few-form (2-4) of 'product(s)', same usage as productCountOne
  ///
  /// In ru, this message translates to:
  /// **'товара'**
  String get productCountFew;

  /// Russian many-form (0, 5+, 11-14) of 'product(s)', same usage as productCountOne
  ///
  /// In ru, this message translates to:
  /// **'товаров'**
  String get productCountMany;

  /// Generic bare 'Name' field/column label (e.g. table column header, form field for a category/supplier/investment/discount name) — distinct from `name` ("Имя", a person's name) and `productName` ("Название товара", the fuller product-specific label)
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get itemName;

  /// Barcode field
  ///
  /// In ru, this message translates to:
  /// **'Штрихкод'**
  String get barcode;

  /// Barcode scanner bottom sheet — sheet title
  ///
  /// In ru, this message translates to:
  /// **'Сканер штрихкода'**
  String get barcodeScannerTitle;

  /// Barcode scanner bottom sheet — hint under the camera preview telling the user to aim the camera at a barcode
  ///
  /// In ru, this message translates to:
  /// **'Наведите камеру на штрихкод'**
  String get barcodeScannerHint;

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

  /// Placeholder/hint text shown inside an empty quantity input field. Deliberately unprefixed — the same hint fits any quantity field. Same Russian text as `addProductQuantityRequiredError` ("Введите количество") but a different UI role: that key is the validation error returned when the add-product quantity field is submitted empty, this one is the field's own inline hint. Kept separate so translators can phrase an inviting hint and a validation error differently.
  ///
  /// In ru, this message translates to:
  /// **'Введите количество'**
  String get enterQuantityHint;

  /// Placeholder/hint text shown inside an empty cost-price (себестоимость) input field. Deliberately unprefixed — the same hint fits any cost-price field. Same Russian text as `costPriceRequiredError` ("Введите себестоимость") but a different UI role: that key is the validation error returned by a form validator when the cost-price field is empty, this one is the field's own inline hint. Kept separate so translators can phrase an inviting hint and a validation error differently.
  ///
  /// In ru, this message translates to:
  /// **'Введите себестоимость'**
  String get enterCostPriceHint;

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

  /// Generic validation error shown when an entered amount exceeds the allowed maximum for the field (e.g. debt payment can't exceed the remaining debt); placeholder is a pre-formatted String
  ///
  /// In ru, this message translates to:
  /// **'Сумма не может превышать {maxAmount}'**
  String amountExceedsMax(String maxAmount);

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

  /// Validation error shown when a percentage field's value falls outside the 1-100 range — distinct from `percentRangeError` (0-100 inclusive): used where 0 itself is rejected (e.g. a Min(1) backend constraint), so the message must not imply 0 is a valid value
  ///
  /// In ru, this message translates to:
  /// **'От 1 до 100'**
  String get percentRangeErrorFrom1;

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

  /// Category create/edit dialog title when editing an existing category — same wording as the `a11yEditCategory` tooltip but a different UI role (dialog title vs. icon-button tooltip), kept as a separate key (mirrors the discountsEditTitle / a11yEditDiscount split)
  ///
  /// In ru, this message translates to:
  /// **'Редактировать категорию'**
  String get categoriesEditTitle;

  /// Category create/edit dialog title when creating a new category — the non-editing branch of a ternary whose other branch is `categoriesEditTitle`
  ///
  /// In ru, this message translates to:
  /// **'Новая категория'**
  String get categoriesNewTitle;

  /// Delete-confirmation dialog title on the categories list page — distinct from `a11yDeleteCategory` ("Удалить категорию", no question mark), which is the row's delete icon-button tooltip
  ///
  /// In ru, this message translates to:
  /// **'Удалить категорию?'**
  String get categoriesDeleteTitle;

  /// Categories list empty-state heading
  ///
  /// In ru, this message translates to:
  /// **'Нет категорий'**
  String get categoriesEmptyTitle;

  /// Categories list empty-state body text
  ///
  /// In ru, this message translates to:
  /// **'Создайте первую категорию для ваших товаров'**
  String get categoriesEmptySubtitle;

  /// Categories list empty-state call-to-action button — distinct from `create` ("Создать"), the bare generic verb
  ///
  /// In ru, this message translates to:
  /// **'Создать категорию'**
  String get categoriesEmptyButton;

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

  /// Metre unit abbreviation for ProductUnit.m — sibling of `pcs`, `kg`, `liter`, `pack`. Distinct from `unitMeter` ("Метр", the full word used in the unit picker).
  ///
  /// In ru, this message translates to:
  /// **'м'**
  String get meter;

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

  /// Empty state shown when a product *search* returns no matches. Deliberately unprefixed and shared across search surfaces. Distinct from `noProducts` ("Нет товаров", the store has no products at all — not a search result) and from `noResults` ("Ничего не найдено", a subject-less generic used where the searched entity isn't products).
  ///
  /// In ru, this message translates to:
  /// **'Товары не найдены'**
  String get noProductsFound;

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

  /// Product list page — search field hint text
  ///
  /// In ru, this message translates to:
  /// **'Поиск товара'**
  String get productSearchHint;

  /// Product list page — stock filter chip for products running low; distinct from `lowStock` ("Мало на складе"), a differently-worded low-stock warning used elsewhere
  ///
  /// In ru, this message translates to:
  /// **'Заканчивается'**
  String get productFilterLowStock;

  /// Product list page — stock filter chip for the combined low-stock + out-of-stock 'needs attention' filter (see the file's BUG #26 comments)
  ///
  /// In ru, this message translates to:
  /// **'Требует внимания'**
  String get productFilterAttention;

  /// Product list page — empty-state headline shown when a stock filter/search hides all products. Distinct from `emptyProductsTitle` ("Добавьте свой первый товар"), a differently-worded empty-state used on another products screen. Rendered as the filtered branch of a ternary whose other branch is `noProducts`, the headline used when the store has no products at all.
  ///
  /// In ru, this message translates to:
  /// **'Нет товаров по фильтру'**
  String get productsEmptyFilteredTitle;

  /// Product list page — empty-state subtitle shown when the store has zero products at all; distinct from `emptyProductsSubtitle` ("Начните добавлять товары в ваш магазин, чтобы управлять продажами и складом"), differently-worded text on another products screen
  ///
  /// In ru, this message translates to:
  /// **'Добавьте первый товар в каталог'**
  String get productsEmptyAddSubtitle;

  /// Product list page — empty-state subtitle shown when a filter/search hides all products
  ///
  /// In ru, this message translates to:
  /// **'Попробуйте изменить фильтр или поисковый запрос'**
  String get productsEmptyFilteredSubtitle;

  /// Product list card — SKU line
  ///
  /// In ru, this message translates to:
  /// **'Арт: {sku}'**
  String productSkuLine(String sku);

  /// Product list card — in-stock quantity line. {value} is the pre-formatted '<quantity> <unit>' string. This collapses what was previously two separately-styled Text widgets (grey label + stock-status-colored value) into one Text per the label+separator+value composite-string rule (.claude/rules/mobile-l10n.md) — the merged Text keeps the stock-status color since that's the more important visual signal
  ///
  /// In ru, this message translates to:
  /// **'На складе: {value}'**
  String productStockQuantityLine(String value);

  /// Product active-status badge, masculine grammatical agreement (product = 'товар', masculine) — distinct from the feminine-agreement 'Активна' forms used elsewhere (subscription/loyalty/shift status badges), which cannot be reused here without breaking Russian grammar
  ///
  /// In ru, this message translates to:
  /// **'Активен'**
  String get productStatusActive;

  /// Product inactive-status badge — the other branch of the same ternary as `productStatusActive`, and in the same masculine grammatical agreement (product = 'товар', masculine)
  ///
  /// In ru, this message translates to:
  /// **'Неактивен'**
  String get productStatusInactive;

  /// Product detail page — info-row label for the product's unit of measurement, short form; distinct from `unit` ("Единица измерения", the fuller field label used in forms)
  ///
  /// In ru, this message translates to:
  /// **'Единица'**
  String get productDetailUnitLabel;

  /// Product detail page — current stock quantity line above the stock progress bar
  ///
  /// In ru, this message translates to:
  /// **'Текущий остаток: {qty} {unit}'**
  String productDetailCurrentStockLine(String qty, String unit);

  /// Product detail page — minimum stock quantity line above the stock progress bar
  ///
  /// In ru, this message translates to:
  /// **'Минимальный: {qty} {unit}'**
  String productDetailMinStockLine(String qty, String unit);

  /// Product detail page — info-row label for barcode, spelled with a hyphen; distinct from `barcode` ("Штрихкод", no hyphen) used elsewhere — different literal, kept separate rather than reconciled here
  ///
  /// In ru, this message translates to:
  /// **'Штрих-код'**
  String get productDetailBarcodeLabel;

  /// Product detail page — stock section card title
  ///
  /// In ru, this message translates to:
  /// **'Наличие на складе'**
  String get productDetailStockAvailabilityTitle;

  /// Product detail page — general info section card title. Same value as `transactionDetailInfoSectionTitle` ("Информация") on the transaction-detail screen; each screen's info card lists different fields, so they may diverge in tg/uz. Do not merge.
  ///
  /// In ru, this message translates to:
  /// **'Информация'**
  String get productDetailInfoSectionTitle;

  /// Product detail page — bottom button to add the product to the cart
  ///
  /// In ru, this message translates to:
  /// **'Продать'**
  String get productDetailSellButton;

  /// Product detail page — delete confirmation dialog title
  ///
  /// In ru, this message translates to:
  /// **'Удалить товар?'**
  String get productDetailDeleteConfirmTitle;

  /// Product detail page — error shown when the stock movement history fails to load
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить историю движений'**
  String get productDetailMovementHistoryLoadError;

  /// Product detail page — stock movement history section title
  ///
  /// In ru, this message translates to:
  /// **'История движений'**
  String get productDetailMovementHistoryTitle;

  /// Product detail page — empty state for the stock movement history list
  ///
  /// In ru, this message translates to:
  /// **'Нет движений'**
  String get productDetailNoMovements;

  /// Product detail page — shown in the batch profitability card when the product has no batch data yet
  ///
  /// In ru, this message translates to:
  /// **'Нет данных о последней закупке — оформите приход, чтобы видеть окупаемость партии.'**
  String get productDetailBatchNoDataMessage;

  /// Product detail page — batch profitability card title
  ///
  /// In ru, this message translates to:
  /// **'Окупаемость партии'**
  String get productDetailBatchPayabilityTitle;

  /// Product detail page — batch profitability card, cost-of-batch info row label
  ///
  /// In ru, this message translates to:
  /// **'Себестоимость партии'**
  String get productDetailBatchCostLabel;

  /// Product detail page — batch profitability card, revenue-from-batch info row label
  ///
  /// In ru, this message translates to:
  /// **'Выручка от партии'**
  String get productDetailBatchRevenueLabel;

  /// Product detail page — batch profitability card, profit-earned info row label
  ///
  /// In ru, this message translates to:
  /// **'Прибыль заработана'**
  String get productDetailBatchProfitEarnedLabel;

  /// Product detail page — batch profitability card, remaining-amount-until-payback info row label
  ///
  /// In ru, this message translates to:
  /// **'До окупаемости партии'**
  String get productDetailBatchTimeToPaybackLabel;

  /// Product detail page — batch profitability card, shown once the batch has fully paid off
  ///
  /// In ru, this message translates to:
  /// **'Партия окупилась'**
  String get productDetailBatchPaidOffLabel;

  /// Product detail page — batch profitability card, remaining-stock info row label
  ///
  /// In ru, this message translates to:
  /// **'Остаток'**
  String get productDetailStockRemainingLabel;

  /// Product detail page — batch profitability card, remaining-stock info row value (quantity and its monetary value)
  ///
  /// In ru, this message translates to:
  /// **'{qty} шт. на {value}'**
  String productDetailStockRemainingValue(String qty, String value);

  /// Product detail page — batch profitability card, percent-paid-off caption under the progress bar
  ///
  /// In ru, this message translates to:
  /// **'{percent}% окупаемости'**
  String productDetailBatchPaybackPercentLine(String percent);

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

  /// All-caps grand-total row label, used where the design emphasises the grand total — distinct from `total` ("Итого", title case). Deliberately unprefixed because four unrelated surfaces share it: pos_checkout_page.dart and widgets/pos/receipt_widget.dart (promoted from the former `posCheckoutTotalCaps`, same value), plus the two service-layer receipt renderers core/services/thermal_printer_service.dart and core/services/receipt_pdf_service.dart, which were routed through this key in ADR-0002 Track 2b (they previously each carried their own hardcoded 'ИТОГО').
  ///
  /// In ru, this message translates to:
  /// **'ИТОГО'**
  String get totalCaps;

  /// Composite 'total' row: label + separator + a pre-formatted amount followed by a hardcoded TJS currency suffix. Full-sentence key so the colon stays translatable. Deliberately unprefixed and shared — it is the payroll period-detail header total and the per-sale total caption on the customer-debts screen (promoted from the former `payrollTotalLine`, same value, when a second feature needed it). Do not use where the amount may be in a non-TJS currency, since the suffix is baked in; use `total` ("Итого") plus a separately formatted value there.
  ///
  /// In ru, this message translates to:
  /// **'Итого: {amount} TJS'**
  String totalTjsLine(String amount);

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

  /// Bare 'Mixed' payment-method label (as used on compact payment-method selector buttons/status labels) — distinct from `mixed` ("Смешанная оплата", the fuller phrase used in the checkout confirmation flow). Shared across pos_checkout_page.dart and transaction_detail_page.dart (a later task in this plan), both of which use the bare form for the same UI role (a compact payment-method chip/label).
  ///
  /// In ru, this message translates to:
  /// **'Смешанная'**
  String get paymentMixedShort;

  /// No description provided for @posCheckoutNoCustomerOption.
  ///
  /// In ru, this message translates to:
  /// **'Без клиента'**
  String get posCheckoutNoCustomerOption;

  /// No description provided for @posCheckoutSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по названию'**
  String get posCheckoutSearchHint;

  /// No description provided for @posCheckoutEmptyCartSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Найдите товар через поиск или выберите из списка выше'**
  String get posCheckoutEmptyCartSubtitle;

  /// No description provided for @posCheckoutCartHeader.
  ///
  /// In ru, this message translates to:
  /// **'Корзина ({count} товаров)'**
  String posCheckoutCartHeader(String count);

  /// No description provided for @posCheckoutCta.
  ///
  /// In ru, this message translates to:
  /// **'Оформить продажу — {total}'**
  String posCheckoutCta(String total);

  /// No description provided for @posCheckoutPointsRedeemPreview.
  ///
  /// In ru, this message translates to:
  /// **'{points} баллов = -{value} сом'**
  String posCheckoutPointsRedeemPreview(String points, String value);

  /// No description provided for @posCheckoutPointsAvailableInline.
  ///
  /// In ru, this message translates to:
  /// **'{points} баллов доступно'**
  String posCheckoutPointsAvailableInline(String points);

  /// No description provided for @posCheckoutRedeemPointsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Списать баллы'**
  String get posCheckoutRedeemPointsTitle;

  /// No description provided for @posCheckoutPointsAvailableLabel.
  ///
  /// In ru, this message translates to:
  /// **'Доступно: {points} баллов'**
  String posCheckoutPointsAvailableLabel(String points);

  /// No description provided for @posCheckoutDiscountPreview.
  ///
  /// In ru, this message translates to:
  /// **'Скидка: -{amount} сом'**
  String posCheckoutDiscountPreview(String amount);

  /// No description provided for @posCheckoutDiscountPercentHint.
  ///
  /// In ru, this message translates to:
  /// **'Процент'**
  String get posCheckoutDiscountPercentHint;

  /// No description provided for @posCheckoutDiscountAmountHint.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get posCheckoutDiscountAmountHint;

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

  /// Sale-success screen — the large headline under the green checkmark. Exclamative form; distinct from `saleSuccess` ("Продажа оформлена", no exclamation mark) which is the neutral status/confirmation wording used elsewhere. Do not merge — the trailing "!" is part of this screen's celebratory copy.
  ///
  /// In ru, this message translates to:
  /// **'Продажа оформлена!'**
  String get saleSuccessTitle;

  /// Sale-success screen — the change-due line, rendered as one contiguous text run inside a single Text widget (label, separator and value share one style), so it is one full-sentence key rather than the bare `change` label plus manual interpolation. {amount} is the pre-formatted change amount including currency.
  ///
  /// In ru, this message translates to:
  /// **'Сдача: {amount}'**
  String saleSuccessChangeLine(String amount);

  /// Sale-success screen — button that opens the share sheet for sending the receipt (labelled for Telegram, the primary option). Distinct from `shareReceipt` ("Отправить чек", the generic share-receipt action) and from `snackReceiptSentToTelegram` (the success snackbar).
  ///
  /// In ru, this message translates to:
  /// **'Отправить в Telegram'**
  String get saleSuccessSendToTelegramButton;

  /// Sale-success screen — receipt body shared via the WhatsApp option of the share sheet. Newline-separated (receipt number on the first line, total on the second), because WhatsApp preserves line breaks. Distinct from `saleSuccessReceiptShareTextSms`, which carries the same information comma-separated on a single line for SMS. {receiptNo} is the receipt number, {total} the total formatted to two decimals.
  ///
  /// In ru, this message translates to:
  /// **'Чек #{receiptNo}\nИтого: {total} сом.'**
  String saleSuccessReceiptShareTextWhatsapp(String receiptNo, String total);

  /// Sale-success screen — receipt body shared via the SMS option of the share sheet. Single line, comma-separated, to stay compact in an SMS. Distinct from `saleSuccessReceiptShareTextWhatsapp`, which is the same information split across two lines with a newline. {receiptNo} is the receipt number, {total} the total formatted to two decimals.
  ///
  /// In ru, this message translates to:
  /// **'Чек #{receiptNo}, Итого: {total} сом.'**
  String saleSuccessReceiptShareTextSms(String receiptNo, String total);

  /// Receipt number label
  ///
  /// In ru, this message translates to:
  /// **'Чек №'**
  String get receiptNo;

  /// Abbreviated quantity column header on a receipt's item table, shortened to fit a narrow receipt column — distinct from `quantity` ("Количество", the full word used where space allows). Shared by the on-screen receipt widget and the PDF receipt, which use the same abbreviated header.
  ///
  /// In ru, this message translates to:
  /// **'Кол.'**
  String get receiptQtyAbbrev;

  /// Quantity column header on the thermal (ESC/POS) receipt, with NO trailing period — distinct from `receiptQtyAbbrev` ("Кол.", with a period) used on the PDF receipt and in the on-screen receipt widget. The two differ by one character in the existing product copy; do not merge them without a deliberate product decision, since either change alters printed output.
  ///
  /// In ru, this message translates to:
  /// **'Кол'**
  String get receiptQtyAbbrevShort;

  /// Printed-receipt line showing loyalty points earned on this sale; points is pre-formatted at the call site.
  ///
  /// In ru, this message translates to:
  /// **'Начислено баллов: +{points}'**
  String receiptPointsEarnedLine(String points);

  /// Printed-receipt line showing the customer's loyalty balance after this sale.
  ///
  /// In ru, this message translates to:
  /// **'Ваш баланс: {points} баллов'**
  String receiptPointsBalanceLine(String points);

  /// Print receipt action
  ///
  /// In ru, this message translates to:
  /// **'Печать чека'**
  String get printReceipt;

  /// Imperative-form 'Print receipt' button label. Distinct from `printReceipt` ("Печать чека", noun form used as an action/title name) — different grammatical form, do not merge. Deliberately unprefixed: used as the print button on both the transaction-detail screen and the sale-success screen (promoted from the former `transactionDetailPrintReceiptButton`, same value).
  ///
  /// In ru, this message translates to:
  /// **'Печатать чек'**
  String get printReceiptButton;

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

  /// Sales-filter bottom sheet heading. Same value as the pre-existing `a11yFilters` ("Фильтры"), which is a screen-reader/tooltip label — visible chrome and a11y labels are kept as separate keys in this ARB (cf. `share`/`a11yShare`). Do not merge.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get salesFilterSheetTitle;

  /// Sales-filter bottom sheet's reset-all-filters button — distinct from `offlineResetSyncStatusConfirm` ("Сбросить"), a different screen's dialog-confirm button that happens to share the same Russian word
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get salesFilterReset;

  /// Sales-filter bottom sheet's period-section chip for opening a custom date-range picker ("Выбрать даты") — distinct from `salesHistoryCustomDateChip` ("Выбрать"), the shorter wording used on the sales-history page's own period chips
  ///
  /// In ru, this message translates to:
  /// **'Выбрать даты'**
  String get salesFilterCustomDates;

  /// No description provided for @salesFilterPaymentTypeSectionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Тип оплаты'**
  String get salesFilterPaymentTypeSectionLabel;

  /// Generic bare 'Debt' label — shared by three surfaces: this sheet's payment-type filter chip, customer_detail_page.dart's debt stat card, and the debt row of the PDF receipt (core/services/receipt_pdf_service.dart, added in ADR-0002 Track 2b). Distinct from `debt` ("В долг"), the preposition-inflected form used as a payment-method value elsewhere — including `_paymentTypeName` inside that same PDF service, so both keys coexist in one file and must not be merged
  ///
  /// In ru, this message translates to:
  /// **'Долг'**
  String get debtLabel;

  /// Sales-filter bottom sheet — section header above the order-status filter chips. Distinct from `staffStatusLabel` ("Статус"), the staff detail page's on-shift stat-column label
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get salesFilterStatusSectionLabel;

  /// No description provided for @salesFilterStatusCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Выполнен'**
  String get salesFilterStatusCompleted;

  /// No description provided for @salesFilterStatusCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменён'**
  String get salesFilterStatusCancelled;

  /// Sales-history period-filter chip for opening a custom date-range picker (bare "Выбрать") — distinct from `salesFilterCustomDates` ("Выбрать даты"), the fuller wording used in the sales-filter bottom sheet's period section. Also shares its bare value with `subscriptionSelectPlanButton` ("Выбрать"), a plan-selection button — unrelated actions that coincide in Russian and may not in tg/uz. Do not merge.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать'**
  String get salesHistoryCustomDateChip;

  /// Sales-history empty-state subtitle shown when there are no sales yet
  ///
  /// In ru, this message translates to:
  /// **'История продаж появится здесь после первой транзакции'**
  String get salesHistoryEmptySubtitle;

  /// Stats banner above the sales list — sale count and total amount, both pre-formatted strings
  ///
  /// In ru, this message translates to:
  /// **'{count} продаж  |  {amount}'**
  String salesHistoryStatsLine(String count, String amount);

  /// Shown when the sales import parser skipped rows (BUG #28 warning banner); `word` is the already-pluralized Russian noun form (записей/запись/записи), pre-formatted at the call site via _pluralRecord
  ///
  /// In ru, this message translates to:
  /// **'{count} {word} пропущено'**
  String salesHistorySkippedRowsLine(String count, String word);

  /// Sales-history list row's second line — customer name (or the retail-customer fallback, reusing `transactionDetailRetailCustomerFallback`) bullet-separated from the item count
  ///
  /// In ru, this message translates to:
  /// **'{customer}  •  {itemsCount} товаров'**
  String salesHistorySaleSummaryLine(String customer, String itemsCount);

  /// Russian singular form of 'record(s)', used in the skipped-rows warning on the sales-history import screen
  ///
  /// In ru, this message translates to:
  /// **'запись'**
  String get recordsCountOne;

  /// Russian few-form (2-4) of 'record(s)', same usage as recordsCountOne
  ///
  /// In ru, this message translates to:
  /// **'записи'**
  String get recordsCountFew;

  /// Russian many-form (0, 5+, 11-14) of 'record(s)', same usage as recordsCountOne — deliberately three separate keys rather than ICU plural, per this file's String-only placeholder convention
  ///
  /// In ru, this message translates to:
  /// **'записей'**
  String get recordsCountMany;

  /// Today's sales ("Продажи за сегодня"). Distinct from `staffTodaySalesLabel` ("Продажи сегодня", without the preposition "за"), the staff detail page's stats-row label
  ///
  /// In ru, this message translates to:
  /// **'Продажи за сегодня'**
  String get todaySales;

  /// Transaction detail screen
  ///
  /// In ru, this message translates to:
  /// **'Детали операции'**
  String get transactionDetail;

  /// No description provided for @transactionDetailItemQtyLine.
  ///
  /// In ru, this message translates to:
  /// **'{quantity} шт × {price}'**
  String transactionDetailItemQtyLine(String quantity, String price);

  /// Sale status badge — 'Returned' (masculine form, agrees with 'чек'). Distinct from `returned` ("Возвращена", feminine form used elsewhere) — different grammatical gender, do not merge.
  ///
  /// In ru, this message translates to:
  /// **'Возвращён'**
  String get transactionDetailStatusReturned;

  /// No description provided for @transactionDetailInfoSectionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Информация'**
  String get transactionDetailInfoSectionTitle;

  /// No description provided for @transactionDetailNoItemsData.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных о товарах'**
  String get transactionDetailNoItemsData;

  /// Sale status badge — 'Paid/Completed'. Distinct from `completed` ("Завершена", a different word) and `paid` ("Оплачено", a different grammatical form used for the paid-amount value row on this same screen) — do not merge any of the three.
  ///
  /// In ru, this message translates to:
  /// **'Оплачен'**
  String get transactionDetailStatusPaid;

  /// Receipt-detail screen header. Distinct from `receiptNo` ("Чек №") and `dashboardSaleReceiptLabel` ("Чек #{receiptNo}") — this screen's header has no separating symbol before the number, unlike either existing candidate; do not merge.
  ///
  /// In ru, this message translates to:
  /// **'Чек {receiptNo}'**
  String transactionDetailReceiptTitle(String receiptNo);

  /// Fallback customer name shown when a sale has no linked customer (walk-in/retail sale)
  ///
  /// In ru, this message translates to:
  /// **'Розничный'**
  String get transactionDetailRetailCustomerFallback;

  /// Refund action
  ///
  /// In ru, this message translates to:
  /// **'Возврат'**
  String get refund;

  /// Refund page — confirmation dialog title. Distinct from `confirm` ("Подтвердить"), the dialog's own bare action button on the same dialog — do not merge.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить возврат?'**
  String get refundConfirmTitle;

  /// Refund confirmation dialog body — combines the refund total and selected-item count into one translatable sentence (was two adjacent Dart string literals forming one Text)
  ///
  /// In ru, this message translates to:
  /// **'Сумма возврата: {amount}\nВыбрано позиций: {count}'**
  String refundConfirmBody(String amount, String count);

  /// Refund page — info banner instructing the cashier to pick which line items to refund
  ///
  /// In ru, this message translates to:
  /// **'Выберите товары для возврата'**
  String get refundInstructionBanner;

  /// Refund page — toggle-button label that selects every line item for refund
  ///
  /// In ru, this message translates to:
  /// **'Выбрать все'**
  String get refundSelectAll;

  /// Refund page — toggle-button label that clears the line-item selection (shown when all items are already selected)
  ///
  /// In ru, this message translates to:
  /// **'Снять все'**
  String get refundDeselectAll;

  /// Refund page — section header above the free-text reason field
  ///
  /// In ru, this message translates to:
  /// **'Причина возврата'**
  String get refundReasonLabel;

  /// Refund page — placeholder text inside the reason field. Distinct from `refundReasonLabel` ("Причина возврата"), the section header above it — imperative prompt vs noun label, do not merge.
  ///
  /// In ru, this message translates to:
  /// **'Укажите причину возврата'**
  String get refundReasonHint;

  /// Refund page — bottom-bar total row label, rendered as its own Text at the left edge of a spaceBetween Row with the refund amount right-aligned opposite it (same two-Text pattern as `zakatCalculatorTaxableAmountLabel`/`zakatCalculatorZakatAmountLabel`); the trailing colon is part of the value so translators control it. Distinct from `zReportReturnsAmount` ("Сумма возвратов", plural — a Z-report aggregate over many refunds, not this single refund's total).
  ///
  /// In ru, this message translates to:
  /// **'Сумма возврата:'**
  String get refundTotalLabel;

  /// Refund page — bottom-bar primary action button that submits the refund
  ///
  /// In ru, this message translates to:
  /// **'Оформить возврат'**
  String get refundSubmitButton;

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

  /// Stock-intake screen — search field hint for finding the product to record an intake against
  ///
  /// In ru, this message translates to:
  /// **'Найти товар для прихода'**
  String get stockIntakeSearchHint;

  /// Stock-intake screen — initial empty state prompting the user to search for a product before any search has been typed; distinct from `stockIntakeSearchHint`, which is the search field's own inline hint
  ///
  /// In ru, this message translates to:
  /// **'Найдите товар для оформления прихода'**
  String get stockIntakeEmptyState;

  /// Stock-intake screen — current on-hand stock caption on a product row and on the selected-product card. Full-sentence composite (label + separator + value) so the colon stays translatable. Distinct from `productStockQuantityLine` ("На складе: {value}", different Russian wording on the product list) and from `productDetailStockRemainingLabel` ("Остаток", a bare standalone label). Both placeholders are pre-formatted Strings; `unit` is an already-localised unit display name.
  ///
  /// In ru, this message translates to:
  /// **'Остаток: {quantity} {unit}'**
  String stockIntakeRemainingLine(String quantity, String unit);

  /// Stock-intake screen — sell-price caption on the selected-product card. Full-sentence composite (label + separator + value) so the colon stays translatable; distinct from the bare `price` ("Цена") label. Placeholder is a pre-formatted, currency-bearing String.
  ///
  /// In ru, this message translates to:
  /// **'Цена: {price}'**
  String stockIntakePriceLine(String price);

  /// Stock-intake screen — section label above the unit cost-price field, with an explicit per-unit qualifier. Distinct from `costPriceRequiredLabel` ("Себестоимость *", the add-product field label with a required asterisk), `dashboardCost` ("Себестоимость", a dashboard metric tile) and `productDetailBatchCostLabel` ("Себестоимость партии", the cost of a whole batch rather than per unit)
  ///
  /// In ru, this message translates to:
  /// **'Себестоимость (за единицу)'**
  String get stockIntakeCostPerUnitLabel;

  /// Stock-intake screen — label on the computed total-cost summary card (quantity x unit cost). Distinct from `total` ("Итого") and `stockValue` ("Стоимость товаров", the whole inventory's value)
  ///
  /// In ru, this message translates to:
  /// **'Итоговая стоимость'**
  String get stockIntakeTotalCostLabel;

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

  /// Stock movement type — goods arriving (IN), bare short form; distinct from `stockIntake` ("Приход товара"), the fuller action-button label used elsewhere. Also reused here for the page's own 'record an intake' bottom button, since it's the same bare word in the same underlying concept.
  ///
  /// In ru, this message translates to:
  /// **'Приход'**
  String get intakeType;

  /// Stock movement type — goods leaving (OUT/sold), bare short form. Distinct from `expense` ("Расход", a financial-ledger transaction-type fallback label used in balance_page.dart) — identical Russian spelling, different domain; do not merge.
  ///
  /// In ru, this message translates to:
  /// **'Расход'**
  String get outflowType;

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

  /// Bare 'Margin' metric label — reused verbatim by product_detail_page.dart's batch-profitability mini-card; mint here once, do not duplicate in that file's task
  ///
  /// In ru, this message translates to:
  /// **'Маржа'**
  String get margin;

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

  /// Offline banner — message while the device is offline and the sync queue is empty. Distinct from `offline` ("Нет подключения к интернету. Работаем офлайн."), the longer two-sentence variant used elsewhere
  ///
  /// In ru, this message translates to:
  /// **'Нет подключения к интернету'**
  String get offlineBannerNoConnection;

  /// Offline banner — message while the device is offline and operations are queued. The separator is U+00B7 MIDDLE DOT
  ///
  /// In ru, this message translates to:
  /// **'Офлайн режим · {count} в очереди'**
  String offlineBannerQueuedMessage(String count);

  /// Offline banner — message while a sync is in progress. Distinct from `offlineSyncingButton` ("Синхронизация..."), a coincidentally identical value that labels the manual-sync *button* on the offline mode settings page
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация...'**
  String get offlineBannerSyncing;

  /// Offline banner — message after a sync failed, with the number of operations still unsent. The separator is U+00B7 MIDDLE DOT. Distinct from `snackSyncError` ("Ошибка синхронизации: {error}"), a colon-plus-error-detail snackbar template
  ///
  /// In ru, this message translates to:
  /// **'Ошибка синхронизации · {count} не отправлено'**
  String offlineBannerSyncErrorMessage(String count);

  /// Offline banner — message while online with operations still waiting to sync. Distinct from `offlinePendingOpsCount` ("{count} операций в очереди"), the offline mode settings page's shorter queue-count line
  ///
  /// In ru, this message translates to:
  /// **'{count} операций ожидают синхронизации'**
  String offlineBannerPendingMessage(String count);

  /// Offline mode page — button that clears the locally displayed last-synced timestamp. Does NOT reset the pending-ops count (a live read from the real sync queue as of the 2026-09-23 SyncEngine rewiring — it can't be honestly reset without discarding real queued data) and does NOT delete any cached product/category/sale data (that data doubles as the offline-first read source and may hold unsynced local writes), so the label must not say anything implying data is erased
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
  /// **'Отметка времени последней синхронизации будет сброшена на этом устройстве. Локальные данные не удаляются.'**
  String get offlineResetSyncStatusBody;

  /// Confirm action in the offlineResetSyncStatusButton dialog
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get offlineResetSyncStatusConfirm;

  /// Detail text passed into the generic `snackSyncError({error})` template when a manual sync partially fails
  ///
  /// In ru, this message translates to:
  /// **'не удалось синхронизировать часть операций'**
  String get offlineSyncErrorPartialDetail;

  /// Offline mode page — status card headline when the sync queue is empty
  ///
  /// In ru, this message translates to:
  /// **'Всё синхронизировано'**
  String get offlineAllSynced;

  /// Offline mode page — status card headline when the sync queue still holds unsynced operations
  ///
  /// In ru, this message translates to:
  /// **'{count} операций в очереди'**
  String offlinePendingOpsCount(String count);

  /// Offline mode page — timestamp of the most recent successful sync
  ///
  /// In ru, this message translates to:
  /// **'Последняя синхронизация: {date}'**
  String offlineLastSyncLabel(String date);

  /// Offline mode page — shown in place of offlineLastSyncLabel when no sync has ever completed on this device
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация ещё не выполнялась'**
  String get offlineNeverSynced;

  /// Offline mode page — manual-sync button label while a sync is in progress
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация...'**
  String get offlineSyncingButton;

  /// Offline mode page — manual-sync button's default (non-syncing) label
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировать сейчас'**
  String get offlineSyncNowButton;

  /// Offline mode page — label for the auto-sync toggle
  ///
  /// In ru, this message translates to:
  /// **'Авто-синхронизация'**
  String get offlineAutoSyncLabel;

  /// Offline mode page — sub-label explaining what the auto-sync toggle does
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировать при подключении к сети'**
  String get offlineAutoSyncDescription;

  /// Offline mode page — info banner explaining offline-first behaviour. Distinct from `offline` ("Нет подключения к интернету. Работаем офлайн."), the transient no-connection message
  ///
  /// In ru, this message translates to:
  /// **'В офлайн-режиме все операции сохраняются локально и автоматически синхронизируются при восстановлении подключения к интернету.'**
  String get offlineInfoBody;

  /// Offline mode page — section header above the reset-sync-status button
  ///
  /// In ru, this message translates to:
  /// **'Данные'**
  String get offlineDataSectionLabel;

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

  /// No description provided for @customerListSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск клиента'**
  String get customerListSearchHint;

  /// No description provided for @customerListFilterDebt.
  ///
  /// In ru, this message translates to:
  /// **'С долгом'**
  String get customerListFilterDebt;

  /// No description provided for @customerListFilterVip.
  ///
  /// In ru, this message translates to:
  /// **'VIP'**
  String get customerListFilterVip;

  /// No description provided for @customerListFilterNew.
  ///
  /// In ru, this message translates to:
  /// **'Новые'**
  String get customerListFilterNew;

  /// No description provided for @customerListEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Клиентов пока нет'**
  String get customerListEmptyTitle;

  /// No description provided for @customerListEmptySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте первого клиента, чтобы отслеживать продажи и долги'**
  String get customerListEmptySubtitle;

  /// No description provided for @customerListEmptyButton.
  ///
  /// In ru, this message translates to:
  /// **'Добавить клиента'**
  String get customerListEmptyButton;

  /// No description provided for @customerListFilterEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Нет клиентов по этому фильтру'**
  String get customerListFilterEmptyTitle;

  /// No description provided for @customerListFilterEmptySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Попробуйте выбрать другой фильтр'**
  String get customerListFilterEmptySubtitle;

  /// No description provided for @customerListResetFilterButton.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить фильтр'**
  String get customerListResetFilterButton;

  /// No description provided for @customerListNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя клиента'**
  String get customerListNameHint;

  /// Confirm button on the add-customer dialog — distinct from `addCustomer` ("Добавить покупателя"), which labels the nav action that opens this dialog
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get customerListAddConfirm;

  /// No description provided for @customerListStatsLine.
  ///
  /// In ru, this message translates to:
  /// **'{count} клиентов  |  Долг: {debt}'**
  String customerListStatsLine(String count, String debt);

  /// Shown in place of a debt amount on a customer card when the customer owes nothing
  ///
  /// In ru, this message translates to:
  /// **'Нет долга'**
  String get customerListNoDebt;

  /// Customer card subtitle showing total purchases amount
  ///
  /// In ru, this message translates to:
  /// **'Покупок: {amount}'**
  String customerListPurchasesLine(String amount);

  /// Customer-detail screen's AppBar title — same Russian text as `deliveryDetailCustomerLabel` ("Клиент") but a different UI role (page title vs. an info-row label on the delivery-detail screen); kept as a separate key per convention for near-duplicate values used in different roles
  ///
  /// In ru, this message translates to:
  /// **'Клиент'**
  String get customerDetailPageTitle;

  /// No description provided for @customerDetailSpentLabel.
  ///
  /// In ru, this message translates to:
  /// **'Потрачено'**
  String get customerDetailSpentLabel;

  /// No description provided for @customerDetailLoyaltyHistoryTitle.
  ///
  /// In ru, this message translates to:
  /// **'История баллов'**
  String get customerDetailLoyaltyHistoryTitle;

  /// Loyalty-history row title — signed points delta (sign is '+' or empty, both pre-formatted strings)
  ///
  /// In ru, this message translates to:
  /// **'{sign}{points} баллов'**
  String customerDetailPointsLine(String sign, String points);

  /// Loyalty-history row trailing text — expiry date for earned points, pre-formatted at the call site. Same value as `subscriptionExpiryUntilLine` ("до {date}") but scoped to a different screen; kept separate per the feature-prefix convention.
  ///
  /// In ru, this message translates to:
  /// **'до {date}'**
  String customerDetailPointsExpiryLine(String date);

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

  /// Supplier-list screen — search field hint; mirrors `customerListSearchHint` ("Поиск клиента") on the customer list
  ///
  /// In ru, this message translates to:
  /// **'Поиск поставщика'**
  String get supplierListSearchHint;

  /// Supplier-list screen — empty-state headline when the store has no suppliers yet; mirrors `customerListEmptyTitle`
  ///
  /// In ru, this message translates to:
  /// **'Поставщиков пока нет'**
  String get supplierListEmptyTitle;

  /// Supplier-list screen — empty-state subtitle explaining the benefit of adding a supplier; mirrors `customerListEmptySubtitle`
  ///
  /// In ru, this message translates to:
  /// **'Добавьте первого поставщика, чтобы отслеживать поставки и долги'**
  String get supplierListEmptySubtitle;

  /// Supplier-list screen — hint text in the name field of the add-supplier dialog; mirrors `customerListNameHint` ("Введите имя клиента")
  ///
  /// In ru, this message translates to:
  /// **'Введите название поставщика'**
  String get supplierListNameHint;

  /// Confirm button on the add-supplier dialog — distinct from `addSupplier` ("Добавить поставщика"), which labels the nav action/tooltip that opens this dialog. Bare verb deliberately kept feature-scoped, matching the convention recorded on `payrollAdjustmentSubmit` and `customerListAddConfirm`: no unprefixed generic `add` key exists in this ARB, so each bare-"Добавить" confirm button gets its own scoped key.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get supplierListAddConfirm;

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

  /// Notification settings screen — AppBar title
  ///
  /// In ru, this message translates to:
  /// **'Настройки уведомлений'**
  String get notificationSettingsPageTitle;

  /// Notification settings screen — intro subtitle above the switch list
  ///
  /// In ru, this message translates to:
  /// **'Выберите какие уведомления вы хотите получать'**
  String get notificationSettingsSubtitle;

  /// Notification settings — low-stock alert switch title; distinct from `lowStock` ("Мало на складе"), a differently-worded stock-status label used on the product list page
  ///
  /// In ru, this message translates to:
  /// **'Низкий остаток'**
  String get notificationSettingsLowStockTitle;

  /// No description provided for @notificationSettingsLowStockSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Когда товар заканчивается на складе'**
  String get notificationSettingsLowStockSubtitle;

  /// Notification settings — new-sale alert switch subtitle (the switch title itself reuses `newSale`, "Новая продажа")
  ///
  /// In ru, this message translates to:
  /// **'Когда кассир оформляет продажу'**
  String get notificationSettingsNewSaleSubtitle;

  /// No description provided for @notificationSettingsShiftClosedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Закрытие смены'**
  String get notificationSettingsShiftClosedTitle;

  /// No description provided for @notificationSettingsShiftClosedSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Когда смена закрывается'**
  String get notificationSettingsShiftClosedSubtitle;

  /// No description provided for @notificationSettingsDeliveryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Доставка выполнена'**
  String get notificationSettingsDeliveryTitle;

  /// No description provided for @notificationSettingsDeliverySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Когда курьер доставил заказ'**
  String get notificationSettingsDeliverySubtitle;

  /// No description provided for @notificationSettingsDebtReminderTitle.
  ///
  /// In ru, this message translates to:
  /// **'Напоминание о долге'**
  String get notificationSettingsDebtReminderTitle;

  /// No description provided for @notificationSettingsDebtReminderSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Просроченные долги клиентов (> 7 дней)'**
  String get notificationSettingsDebtReminderSubtitle;

  /// No description provided for @notificationSettingsStaleProductTitle.
  ///
  /// In ru, this message translates to:
  /// **'Залежалый товар'**
  String get notificationSettingsStaleProductTitle;

  /// No description provided for @notificationSettingsStaleProductSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Уведомлять, если товар не продаётся N дней и остаток ещё большой'**
  String get notificationSettingsStaleProductSubtitle;

  /// Notification settings — label of the numeric field setting how many days without a sale marks a product as stale
  ///
  /// In ru, this message translates to:
  /// **'Дней без продаж'**
  String get notificationSettingsDaysWithoutSaleLabel;

  /// Notification settings — label of the numeric field setting the minimum remaining stock, as a percentage of the original batch, for the stale-product alert to fire
  ///
  /// In ru, this message translates to:
  /// **'Остаток, % от партии'**
  String get notificationSettingsRemainingPercentLabel;

  /// Push notification body sent the day before a debt is due. amount is the bare number from debtAmount.toStringAsFixed(2); the currency abbreviation is part of this value, not the argument. Deliberately NOT Formatters.price, which uses NumberFormat(ru_RU) and would render "500,00" with a comma decimal separator plus thousands grouping — a visible change from the literal this replaces. The matching title reuses `notificationSettingsDebtReminderTitle` ("Напоминание о долге") — there is deliberately no due-tomorrow title key.
  ///
  /// In ru, this message translates to:
  /// **'{customer} должен {amount} сом. Срок оплаты завтра.'**
  String debtReminderDueTomorrowBody(String customer, String amount);

  /// Push notification title sent on the day a debt falls due — distinct from `notificationSettingsDebtReminderTitle` ("Напоминание о долге"), the generic debt-reminder wording reused as the due-tomorrow notification title and as the settings switch label
  ///
  /// In ru, this message translates to:
  /// **'Срок оплаты долга'**
  String get debtReminderDueTodayTitle;

  /// Push notification body sent on the day a debt falls due.
  ///
  /// In ru, this message translates to:
  /// **'{customer} должен {amount} сом. Срок оплаты сегодня!'**
  String debtReminderDueTodayBody(String customer, String amount);

  /// Push notification title sent once a debt is past due — distinct from `debtReminderDueTodayTitle` ("Срок оплаты долга", fired on the due date itself) and from `notificationSettingsDebtReminderTitle` ("Напоминание о долге", the generic wording)
  ///
  /// In ru, this message translates to:
  /// **'Просроченный долг'**
  String get debtReminderOverdueTitle;

  /// Push notification body sent once a debt is past due.
  ///
  /// In ru, this message translates to:
  /// **'{customer}: просрочен долг {amount} сом.'**
  String debtReminderOverdueBody(String customer, String amount);

  /// Push notification title for the low-stock alert — distinct from `lowStock` ("Мало на складе"), the shorter stock-status badge on the product list, and from `notificationSettingsLowStockTitle` ("Низкий остаток"), the settings switch label for this same alert
  ///
  /// In ru, this message translates to:
  /// **'Мало товара на складе'**
  String get lowStockAlertTitle;

  /// Push notification body for the low-stock alert. quantity is the bare count from currentQuantity.toString(); the unit abbreviation is part of this value. NOTE: that abbreviation is hardcoded to pieces, so a product measured in kg or litres still reads as pieces. This is a pre-existing bug in the literal being replaced, preserved deliberately — fixing it is a product change, not an extraction.
  ///
  /// In ru, this message translates to:
  /// **'{product}: осталось {quantity} шт.'**
  String lowStockAlertBody(String product, String quantity);

  /// Notifications list page — empty state shown when the user has no notifications
  ///
  /// In ru, this message translates to:
  /// **'Нет уведомлений'**
  String get notificationsEmptyState;

  /// Notifications list page — snackbar confirming the user approved a support agent's impersonation-access request
  ///
  /// In ru, this message translates to:
  /// **'Доступ предоставлен'**
  String get impersonationAccessGranted;

  /// Notifications list page — snackbar confirming the user rejected a support agent's impersonation-access request
  ///
  /// In ru, this message translates to:
  /// **'Запрос отклонён'**
  String get impersonationRequestRejected;

  /// Notifications list page — snackbar shown when responding to an impersonation-access request fails, most often because the request already expired or was withdrawn
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обработать запрос — возможно, он уже неактивен'**
  String get impersonationRequestFailedMessage;

  /// Impersonation banner — persistent banner text shown while the app runs on a support (impersonation) session token
  ///
  /// In ru, this message translates to:
  /// **'Вы вошли как поддержка Dukon'**
  String get impersonationBannerMessage;

  /// Impersonation banner — button that ends the support (impersonation) session and logs the device out
  ///
  /// In ru, this message translates to:
  /// **'Завершить сессию'**
  String get impersonationBannerEndSession;

  /// Settings page — logout confirmation dialog title
  ///
  /// In ru, this message translates to:
  /// **'Выход'**
  String get settingsLogoutTitle;

  /// Settings page — logout confirmation dialog body
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите выйти?'**
  String get settingsLogoutConfirmBody;

  /// Settings page — dialog title shown when tapping the ecommerce integration tile on a non-PREMIUM plan
  ///
  /// In ru, this message translates to:
  /// **'Доступно на тарифе PREMIUM'**
  String get settingsPremiumGateTitle;

  /// Settings page — body text of the PREMIUM upsell dialog for the ecommerce integration
  ///
  /// In ru, this message translates to:
  /// **'Интеграция с интернет-магазином доступна на тарифе PREMIUM. Перейдите на PREMIUM, чтобы синхронизировать остатки и заказы с вашим сайтом.'**
  String get settingsPremiumGateBody;

  /// Settings page — dismiss button on the PREMIUM upsell dialog
  ///
  /// In ru, this message translates to:
  /// **'Позже'**
  String get settingsPremiumGateLater;

  /// Settings page — upgrade button on the PREMIUM upsell dialog, navigates to the subscription screen
  ///
  /// In ru, this message translates to:
  /// **'Перейти к тарифам'**
  String get settingsPremiumGateUpgrade;

  /// Settings page — integrations section header
  ///
  /// In ru, this message translates to:
  /// **'Интеграции'**
  String get settingsSectionIntegrations;

  /// Settings page — tile linking to the staff list
  ///
  /// In ru, this message translates to:
  /// **'Продавцы'**
  String get settingsTileStaff;

  /// Settings page — tile linking to roles and permissions management. Distinct from `moreRolesAndPermissions` ("Роли и права"), a different label used on the More page
  ///
  /// In ru, this message translates to:
  /// **'Роли и доступы'**
  String get settingsTileRoles;

  /// Settings page — tile linking to receipt template settings
  ///
  /// In ru, this message translates to:
  /// **'Шаблоны чеков'**
  String get settingsTileReceiptTemplates;

  /// Settings page — tile linking to Telegram bot settings
  ///
  /// In ru, this message translates to:
  /// **'Telegram-бот'**
  String get settingsTileTelegramBot;

  /// Settings page — tile linking to fiscal register (KKM) settings
  ///
  /// In ru, this message translates to:
  /// **'ККМ / Фискализация'**
  String get settingsTileKkm;

  /// Settings page — tile linking to receipt printer settings
  ///
  /// In ru, this message translates to:
  /// **'Принтер чеков'**
  String get settingsTilePrinter;

  /// Settings page — tile linking to barcode scanner settings
  ///
  /// In ru, this message translates to:
  /// **'Сканер'**
  String get settingsTileScanner;

  /// Settings page — app section header
  ///
  /// In ru, this message translates to:
  /// **'Приложение'**
  String get settingsSectionApp;

  /// Settings page — tile linking to offline mode settings
  ///
  /// In ru, this message translates to:
  /// **'Офлайн-режим'**
  String get settingsTileOfflineMode;

  /// Settings page — offline-mode tile trailing label shown when there are no pending sync operations
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировано'**
  String get settingsSynced;

  /// Settings page — offline-mode tile trailing label shown when there are pending sync operations
  ///
  /// In ru, this message translates to:
  /// **'{count} в очереди'**
  String settingsPendingSyncOps(String count);

  /// Settings page — subscription section header
  ///
  /// In ru, this message translates to:
  /// **'Подписка'**
  String get settingsSectionSubscription;

  /// Settings page — fallback plan tile title shown before the subscription has loaded
  ///
  /// In ru, this message translates to:
  /// **'Тариф'**
  String get settingsPlanFallbackLabel;

  /// Settings page — plan tile title showing the plan name and its expiry date
  ///
  /// In ru, this message translates to:
  /// **'{plan} до {date}'**
  String settingsPlanUntilDate(String plan, String date);

  /// Settings page — trailing action on the plan tile, navigates to the subscription screen
  ///
  /// In ru, this message translates to:
  /// **'Сменить тариф'**
  String get settingsChangePlan;

  /// Settings page — full-width logout button at the bottom of the page. Distinct from `logout` ("Выйти"), the bare confirm button inside the logout dialog
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта'**
  String get settingsLogoutButton;

  /// No description provided for @subscriptionFeatureStores1.
  ///
  /// In ru, this message translates to:
  /// **'1 магазин'**
  String get subscriptionFeatureStores1;

  /// No description provided for @subscriptionFeatureProducts500.
  ///
  /// In ru, this message translates to:
  /// **'500 товаров'**
  String get subscriptionFeatureProducts500;

  /// No description provided for @subscriptionFeatureEmployees2.
  ///
  /// In ru, this message translates to:
  /// **'2 сотрудника'**
  String get subscriptionFeatureEmployees2;

  /// No description provided for @subscriptionFeatureSalesReport.
  ///
  /// In ru, this message translates to:
  /// **'Отчёт продаж'**
  String get subscriptionFeatureSalesReport;

  /// No description provided for @subscriptionFeatureCurrencies.
  ///
  /// In ru, this message translates to:
  /// **'Валюты'**
  String get subscriptionFeatureCurrencies;

  /// No description provided for @subscriptionPriceStart.
  ///
  /// In ru, this message translates to:
  /// **'49 TJS/мес'**
  String get subscriptionPriceStart;

  /// No description provided for @subscriptionFeatureStores3.
  ///
  /// In ru, this message translates to:
  /// **'3 магазина'**
  String get subscriptionFeatureStores3;

  /// No description provided for @subscriptionFeatureProducts2000.
  ///
  /// In ru, this message translates to:
  /// **'2000 товаров'**
  String get subscriptionFeatureProducts2000;

  /// No description provided for @subscriptionFeatureEmployees10.
  ///
  /// In ru, this message translates to:
  /// **'10 сотрудников'**
  String get subscriptionFeatureEmployees10;

  /// No description provided for @subscriptionFeatureAllReports.
  ///
  /// In ru, this message translates to:
  /// **'Все отчёты'**
  String get subscriptionFeatureAllReports;

  /// No description provided for @subscriptionFeatureDiscounts5.
  ///
  /// In ru, this message translates to:
  /// **'5 скидок'**
  String get subscriptionFeatureDiscounts5;

  /// No description provided for @subscriptionPriceBusiness.
  ///
  /// In ru, this message translates to:
  /// **'149 TJS/мес'**
  String get subscriptionPriceBusiness;

  /// No description provided for @subscriptionFeatureStores5.
  ///
  /// In ru, this message translates to:
  /// **'5 магазинов'**
  String get subscriptionFeatureStores5;

  /// No description provided for @subscriptionFeatureUnlimitedProductsEmployees.
  ///
  /// In ru, this message translates to:
  /// **'Безлимит товаров/сотрудников'**
  String get subscriptionFeatureUnlimitedProductsEmployees;

  /// No description provided for @subscriptionFeatureExportPdfExcel.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт PDF/Excel'**
  String get subscriptionFeatureExportPdfExcel;

  /// No description provided for @subscriptionFeatureUnlimitedDiscounts.
  ///
  /// In ru, this message translates to:
  /// **'Безлимит скидок'**
  String get subscriptionFeatureUnlimitedDiscounts;

  /// No description provided for @subscriptionFeaturePrioritySupport.
  ///
  /// In ru, this message translates to:
  /// **'Приоритетная поддержка'**
  String get subscriptionFeaturePrioritySupport;

  /// No description provided for @subscriptionPricePremium.
  ///
  /// In ru, this message translates to:
  /// **'299 TJS/мес'**
  String get subscriptionPricePremium;

  /// Subscription-status badge — near-duplicate value to `loyaltySettingsActive` ("Активна", loyalty-toggle label) and `shiftsActiveStatus` ("Активна", shift-status badge); kept as its own key per this ARB's established pattern of not merging same-value keys across unrelated features
  ///
  /// In ru, this message translates to:
  /// **'Активна'**
  String get subscriptionActiveStatus;

  /// No description provided for @subscriptionTrialStatus.
  ///
  /// In ru, this message translates to:
  /// **'Пробный период'**
  String get subscriptionTrialStatus;

  /// No description provided for @subscriptionExpiredStatus.
  ///
  /// In ru, this message translates to:
  /// **'Истекла'**
  String get subscriptionExpiredStatus;

  /// No description provided for @subscriptionTrialDaysLeftLine.
  ///
  /// In ru, this message translates to:
  /// **'Пробный период: осталось {days} дней'**
  String subscriptionTrialDaysLeftLine(String days);

  /// Subscription-card trailing text — plan expiry date, pre-formatted at the call site. Same value as `customerDetailPointsExpiryLine` ("до {date}") but scoped to a different screen; kept separate per the feature-prefix convention.
  ///
  /// In ru, this message translates to:
  /// **'до {date}'**
  String subscriptionExpiryUntilLine(String date);

  /// No description provided for @subscriptionAdminDiscountBadge.
  ///
  /// In ru, this message translates to:
  /// **'Скидка {percent}%'**
  String subscriptionAdminDiscountBadge(String percent);

  /// No description provided for @subscriptionPendingBannerText.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает подтверждения оплаты'**
  String get subscriptionPendingBannerText;

  /// No description provided for @subscriptionCurrentPlanBadge.
  ///
  /// In ru, this message translates to:
  /// **'Текущий план'**
  String get subscriptionCurrentPlanBadge;

  /// No description provided for @subscriptionSelectPlanButton.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать'**
  String get subscriptionSelectPlanButton;

  /// Payment-record status badge, default/pending case — distinct from `subscriptionPendingBannerText`, the fuller pending-payment banner sentence shown elsewhere on the same page
  ///
  /// In ru, this message translates to:
  /// **'Ожидает'**
  String get subscriptionPaymentPendingStatus;

  /// No description provided for @subscriptionPaymentConfirmedStatus.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждено'**
  String get subscriptionPaymentConfirmedStatus;

  /// No description provided for @subscriptionPaymentRejectedStatus.
  ///
  /// In ru, this message translates to:
  /// **'Отклонено'**
  String get subscriptionPaymentRejectedStatus;

  /// No description provided for @subscriptionPaymentDialogTitle.
  ///
  /// In ru, this message translates to:
  /// **'Платёж — {plan}'**
  String subscriptionPaymentDialogTitle(String plan);

  /// No description provided for @subscriptionPaymentAmountLine.
  ///
  /// In ru, this message translates to:
  /// **'Сумма: {amount} TJS'**
  String subscriptionPaymentAmountLine(String amount);

  /// No description provided for @subscriptionCardTransferMethod.
  ///
  /// In ru, this message translates to:
  /// **'Перевод на карту'**
  String get subscriptionCardTransferMethod;

  /// No description provided for @subscriptionPaymentMethodLine.
  ///
  /// In ru, this message translates to:
  /// **'Метод: {method}'**
  String subscriptionPaymentMethodLine(String method);

  /// Preserves existing behavior of interpolating the raw backend status code (e.g. "CONFIRMED"), not the already-localized status badge text used elsewhere on this page — not a behavior fix, just the literal migrated as-is
  ///
  /// In ru, this message translates to:
  /// **'Статус: {status}'**
  String subscriptionPaymentStatusLine(String status);

  /// No description provided for @subscriptionPaymentDateLine.
  ///
  /// In ru, this message translates to:
  /// **'Дата: {date}'**
  String subscriptionPaymentDateLine(String date);

  /// No description provided for @subscriptionAdminNoteLine.
  ///
  /// In ru, this message translates to:
  /// **'Примечание: {note}'**
  String subscriptionAdminNoteLine(String note);

  /// No description provided for @subscriptionReceiptLabel.
  ///
  /// In ru, this message translates to:
  /// **'Чек:'**
  String get subscriptionReceiptLabel;

  /// No description provided for @subscriptionReceiptImageUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Изображение недоступно'**
  String get subscriptionReceiptImageUnavailable;

  /// No description provided for @subscriptionPlansSectionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Тарифные планы'**
  String get subscriptionPlansSectionTitle;

  /// No description provided for @subscriptionCameraSource.
  ///
  /// In ru, this message translates to:
  /// **'Камера'**
  String get subscriptionCameraSource;

  /// No description provided for @subscriptionGallerySource.
  ///
  /// In ru, this message translates to:
  /// **'Галерея'**
  String get subscriptionGallerySource;

  /// No description provided for @subscriptionPaymentSheetTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплата тарифа «{plan}»'**
  String subscriptionPaymentSheetTitle(String plan);

  /// No description provided for @subscriptionTransferDetailsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Реквизиты для перевода'**
  String get subscriptionTransferDetailsTitle;

  /// No description provided for @subscriptionRecipientLabel.
  ///
  /// In ru, this message translates to:
  /// **'Получатель'**
  String get subscriptionRecipientLabel;

  /// No description provided for @subscriptionBankLabel.
  ///
  /// In ru, this message translates to:
  /// **'Банк'**
  String get subscriptionBankLabel;

  /// Subscription payment screen — upload-receipt button's default (non-uploading) label; its in-flight counterpart is the generic `loading` ("Загрузка..."), the other branch of the same ternary
  ///
  /// In ru, this message translates to:
  /// **'Я перевёл — загрузить чек'**
  String get subscriptionUploadReceiptButton;

  /// No description provided for @reportsExportSheetTitle.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт отчёта'**
  String get reportsExportSheetTitle;

  /// No description provided for @reportsExportPdf.
  ///
  /// In ru, this message translates to:
  /// **'Скачать PDF'**
  String get reportsExportPdf;

  /// No description provided for @reportsExportExcelLocal.
  ///
  /// In ru, this message translates to:
  /// **'Скачать Excel (локальный)'**
  String get reportsExportExcelLocal;

  /// No description provided for @reportsExportExcelAllData.
  ///
  /// In ru, this message translates to:
  /// **'Скачать Excel (все данные)'**
  String get reportsExportExcelAllData;

  /// No description provided for @reportsPdfPeriodLabel.
  ///
  /// In ru, this message translates to:
  /// **'Период: {period}'**
  String reportsPdfPeriodLabel(String period);

  /// No description provided for @reportsShareSubjectWithPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Отчёт {tabName} ({period})'**
  String reportsShareSubjectWithPeriod(String tabName, String period);

  /// No description provided for @reportsRevenueColumnLabel.
  ///
  /// In ru, this message translates to:
  /// **'Выручка'**
  String get reportsRevenueColumnLabel;

  /// No description provided for @reportsMetricColumnLabel.
  ///
  /// In ru, this message translates to:
  /// **'Показатель'**
  String get reportsMetricColumnLabel;

  /// Reports export — second column header of the metric/value table, companion to `reportsMetricColumnLabel` in the same header array; used by both the PDF and the Excel export
  ///
  /// In ru, this message translates to:
  /// **'Значение'**
  String get reportsValueColumnLabel;

  /// No description provided for @reportsNetProfitLabel.
  ///
  /// In ru, this message translates to:
  /// **'Чистая прибыль'**
  String get reportsNetProfitLabel;

  /// Distinct literal from bare `margin` ("Маржа") — this one already includes the percent sign as part of the string, used only in the Excel-export row
  ///
  /// In ru, this message translates to:
  /// **'Маржа %'**
  String get reportsMarginPercentLabel;

  /// Bare PDF section label — distinct from `reportsDeadStockSectionTitle` ("Залёжные товары (30+ дней)"), the fuller in-app section title
  ///
  /// In ru, this message translates to:
  /// **'Залёжные товары'**
  String get reportsDeadStockPdfLabel;

  /// No description provided for @reportsShareSubject.
  ///
  /// In ru, this message translates to:
  /// **'Отчёт {tabName}'**
  String reportsShareSubject(String tabName);

  /// No description provided for @reportsExportTypeShareSubject.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт {type}'**
  String reportsExportTypeShareSubject(String type);

  /// No description provided for @reportsExportTypeSheetTitle.
  ///
  /// In ru, this message translates to:
  /// **'Что экспортировать?'**
  String get reportsExportTypeSheetTitle;

  /// No description provided for @reportsExcelTopProductsSectionHeader.
  ///
  /// In ru, this message translates to:
  /// **'=== Топ товары ==='**
  String get reportsExcelTopProductsSectionHeader;

  /// No description provided for @reportsExcelDeadStockSectionHeader.
  ///
  /// In ru, this message translates to:
  /// **'=== Залёжные товары ==='**
  String get reportsExcelDeadStockSectionHeader;

  /// No description provided for @reportsStockValueLabel.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость склада'**
  String get reportsStockValueLabel;

  /// No description provided for @reportsPageTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отчёты'**
  String get reportsPageTitle;

  /// No description provided for @reportsChannelAll.
  ///
  /// In ru, this message translates to:
  /// **'Все каналы'**
  String get reportsChannelAll;

  /// No description provided for @reportsChannelInStore.
  ///
  /// In ru, this message translates to:
  /// **'В магазине'**
  String get reportsChannelInStore;

  /// No description provided for @reportsChannelOnline.
  ///
  /// In ru, this message translates to:
  /// **'Онлайн'**
  String get reportsChannelOnline;

  /// No description provided for @reportsSalesDataSectionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Данные по продажам'**
  String get reportsSalesDataSectionTitle;

  /// Abbreviated column header — distinct from the full-word `avgCheck` ("Средний чек") used in the PDF/Excel export headers
  ///
  /// In ru, this message translates to:
  /// **'Ср. чек'**
  String get reportsAvgCheckColumnLabel;

  /// No description provided for @reportsTop5ByRevenueChartTitle.
  ///
  /// In ru, this message translates to:
  /// **'Топ-5 товаров по выручке'**
  String get reportsTop5ByRevenueChartTitle;

  /// No description provided for @reportsExpensesByCategoryChartTitle.
  ///
  /// In ru, this message translates to:
  /// **'Расходы по категориям'**
  String get reportsExpensesByCategoryChartTitle;

  /// No description provided for @reportsDetailsSectionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Детализация'**
  String get reportsDetailsSectionTitle;

  /// No description provided for @reportsIncomeVsExpensesChartTitle.
  ///
  /// In ru, this message translates to:
  /// **'Доход vs Расходы по месяцам'**
  String get reportsIncomeVsExpensesChartTitle;

  /// No description provided for @reportsTopSalesSectionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Топ продажи'**
  String get reportsTopSalesSectionTitle;

  /// No description provided for @reportsQuantityUnitsLine.
  ///
  /// In ru, this message translates to:
  /// **'{qty} шт'**
  String reportsQuantityUnitsLine(String qty);

  /// No description provided for @reportsDeadStockSectionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Залёжные товары (30+ дней)'**
  String get reportsDeadStockSectionTitle;

  /// No description provided for @reportsSalesByCashierChartTitle.
  ///
  /// In ru, this message translates to:
  /// **'Продажи по кассирам'**
  String get reportsSalesByCashierChartTitle;

  /// No description provided for @reportsSalesCountTooltip.
  ///
  /// In ru, this message translates to:
  /// **'{count} продаж'**
  String reportsSalesCountTooltip(String count);

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

  /// No description provided for @financeDashboardPeriodHalfYear.
  ///
  /// In ru, this message translates to:
  /// **'6 мес'**
  String get financeDashboardPeriodHalfYear;

  /// No description provided for @financeTotalIncome.
  ///
  /// In ru, this message translates to:
  /// **'Общий доход'**
  String get financeTotalIncome;

  /// No description provided for @financeTotalExpenses.
  ///
  /// In ru, this message translates to:
  /// **'Общие расходы'**
  String get financeTotalExpenses;

  /// No description provided for @financeGrossProfit.
  ///
  /// In ru, this message translates to:
  /// **'Валовая прибыль'**
  String get financeGrossProfit;

  /// Finance-dashboard KPI card label. Same value as `reportsNetProfitLabel` ("Чистая прибыль") on the reports screen; each is feature-scoped to its own screen and they may be worded differently per locale. Do not merge.
  ///
  /// In ru, this message translates to:
  /// **'Чистая прибыль'**
  String get financeNetProfit;

  /// Top-products list row — quantity sold with the abbreviated units suffix; quantity is pre-formatted to a string at the call site
  ///
  /// In ru, this message translates to:
  /// **'{quantity} шт'**
  String financeDashboardQuantityUnit(String quantity);

  /// Finance-dashboard grid tile linking to the currency-rates screen. Same value as `subscriptionFeatureCurrencies` ("Валюты"), which is a bullet in a subscription plan's feature list — a navigation label vs. a feature name. Do not merge.
  ///
  /// In ru, this message translates to:
  /// **'Валюты'**
  String get financeDashboardCurrencies;

  /// No description provided for @financeDashboardDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Доставка'**
  String get financeDashboardDelivery;

  /// No description provided for @financeDashboardReport.
  ///
  /// In ru, this message translates to:
  /// **'Отчёт'**
  String get financeDashboardReport;

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

  /// Abbreviated sales-count label — the bare genitive-plural noun used directly under or beside a numeral (stat tiles, table/PDF/Excel column headers). Distinct from `sales` ("Продажи", nominative plural, a tab/section name) and from `salesCount` ("Кол-во продаж", the full 'number of sales' phrase). Promoted from `reportsSalesCountColumnLabel` once a second consumer outside the reports page (the shared StatSummaryRow widget) appeared, since a `reports*` prefix disagreed with that scope.
  ///
  /// In ru, this message translates to:
  /// **'Продаж'**
  String get salesCountAbbrev;

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

  /// Generic capitalised "Today" period label/chip. Distinct from `staffCardTodayLabel` ("сегодня", lowercase), the caption under the staff card's today-sales amount
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

  /// No description provided for @monthJanuary.
  ///
  /// In ru, this message translates to:
  /// **'Январь'**
  String get monthJanuary;

  /// No description provided for @monthFebruary.
  ///
  /// In ru, this message translates to:
  /// **'Февраль'**
  String get monthFebruary;

  /// No description provided for @monthMarch.
  ///
  /// In ru, this message translates to:
  /// **'Март'**
  String get monthMarch;

  /// No description provided for @monthApril.
  ///
  /// In ru, this message translates to:
  /// **'Апрель'**
  String get monthApril;

  /// No description provided for @monthMay.
  ///
  /// In ru, this message translates to:
  /// **'Май'**
  String get monthMay;

  /// No description provided for @monthJune.
  ///
  /// In ru, this message translates to:
  /// **'Июнь'**
  String get monthJune;

  /// No description provided for @monthJuly.
  ///
  /// In ru, this message translates to:
  /// **'Июль'**
  String get monthJuly;

  /// No description provided for @monthAugust.
  ///
  /// In ru, this message translates to:
  /// **'Август'**
  String get monthAugust;

  /// No description provided for @monthSeptember.
  ///
  /// In ru, this message translates to:
  /// **'Сентябрь'**
  String get monthSeptember;

  /// No description provided for @monthOctober.
  ///
  /// In ru, this message translates to:
  /// **'Октябрь'**
  String get monthOctober;

  /// No description provided for @monthNovember.
  ///
  /// In ru, this message translates to:
  /// **'Ноябрь'**
  String get monthNovember;

  /// No description provided for @monthDecember.
  ///
  /// In ru, this message translates to:
  /// **'Декабрь'**
  String get monthDecember;

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

  /// Generic validation error when an amount field is left empty — deliberately unprefixed and shared across screens (close-shift dialog, add-expense, add-investment, payroll adjustment).
  ///
  /// In ru, this message translates to:
  /// **'Введите сумму'**
  String get amountRequired;

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

  /// Generic placeholder shown in a date-picker slot when no date has been chosen yet — deliberately unprefixed and shared across screens (zakat haul-start field, investment end-date field). Feminine short-form adjective agreeing with "дата".
  ///
  /// In ru, this message translates to:
  /// **'Не выбрана'**
  String get dateNotSelected;

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

  /// Customer-debts screen — section heading above the list of that customer's sales that still carry an outstanding debt
  ///
  /// In ru, this message translates to:
  /// **'Продажи с долгом'**
  String get customerDebtsSalesTitle;

  /// Customer-debts screen — shown in place of the sales list when the customer has no sales with an outstanding debt; distinct from `noDebts` ("Нет активных долгов"), the store-wide debts empty state
  ///
  /// In ru, this message translates to:
  /// **'Нет продаж с долгом'**
  String get customerDebtsEmptyState;

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

  /// Badge text marking an item as past its due date (e.g. a debt-bearing sale older than the overdue threshold). Deliberately unprefixed — the same badge wording fits any overdue item. Neuter short-form adjective; distinct from `notificationSettingsDebtReminderSubtitle`, which contains the plural adjective "Просроченные" inside a longer sentence.
  ///
  /// In ru, this message translates to:
  /// **'Просрочено'**
  String get overdueLabel;

  /// Button label and form heading for taking a payment against an outstanding debt — used on the customer-debts screen's per-sale action button and as the heading and submit button of the debt payment form. Distinct from `creditsAcceptPayment` ("Принять платёж"): same intent but different Russian noun (оплата vs платёж), and that key is the credits screen's receivables-tab button and dialog title; the two literals differ in the source design, so they must not be merged.
  ///
  /// In ru, this message translates to:
  /// **'Принять оплату'**
  String get acceptDebtPayment;

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

  /// Debt payment form — caption under the heading stating the largest payment that may be entered (the remaining debt). Full-sentence composite (label + separator + value) so the colon stays translatable. Distinct from `amountExceedsMax` ("Сумма не может превышать {maxAmount}"), the validation error raised once that ceiling is exceeded. Placeholder is a pre-formatted String; the TJS suffix is baked in.
  ///
  /// In ru, this message translates to:
  /// **'Максимум: {amount} TJS'**
  String paymentFormMaxAmountLine(String amount);

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

  /// Cash-payment screen — header title. Distinct from `cash` ("Наличные", the bare payment-method name) — this is the full screen title.
  ///
  /// In ru, this message translates to:
  /// **'Оплата наличными'**
  String get cashPaymentPageTitle;

  /// Cash-payment screen — caption above the amount due, in its own layout slot above the large amount value (kept as a standalone label rather than a composite key, since the label and value have different type scales). Same wording as the `cardPaymentConfirmMessage` dialog body but that key is a full sentence with the amount interpolated, so they are not interchangeable.
  ///
  /// In ru, this message translates to:
  /// **'Сумма к оплате'**
  String get cashPaymentAmountToPayLabel;

  /// Cash-payment screen — field label above the input for the cash amount handed over by the customer
  ///
  /// In ru, this message translates to:
  /// **'Получено от клиента'**
  String get cashPaymentReceivedFromCustomerLabel;

  /// Cash-payment screen — visible label on the quick-amount chip that fills in the exact total so no change is due. Same Russian value as `a11yWithoutChange`, which is the Semantics label wrapping this same chip; kept as a separate key because this codebase keeps visible copy out of the `a11y*` block (cf. `share` vs `a11yShare`) so the accessibility string can be reworded independently.
  ///
  /// In ru, this message translates to:
  /// **'Без сдачи'**
  String get cashPaymentNoChangeButton;

  /// Cash-payment screen — caption on the change card when the amount received is less than the total (the shortfall is shown below). The positive branch of the same ternary uses `change` ("Сдача").
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно'**
  String get cashPaymentInsufficientLabel;

  /// Cash-payment screen — primary button that completes the sale and prints the receipt (shows `processing` instead while the request is in flight)
  ///
  /// In ru, this message translates to:
  /// **'Завершить и печатать чек'**
  String get cashPaymentCompleteButton;

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

  /// No description provided for @zakatCalculatorAssetsSection.
  ///
  /// In ru, this message translates to:
  /// **'АКТИВЫ МАГАЗИНА'**
  String get zakatCalculatorAssetsSection;

  /// Zakat-calculator asset-card title. Distinct from zakat_settings_page.dart's `zakatSettingsStockValueToggleTitle` ("Товарные остатки магазина", with a 'магазина' suffix) — different text, do not merge.
  ///
  /// In ru, this message translates to:
  /// **'Товарные остатки'**
  String get zakatCalculatorStockValueLabel;

  /// No description provided for @zakatCalculatorAutoFromCatalog.
  ///
  /// In ru, this message translates to:
  /// **'Автоматически из каталога'**
  String get zakatCalculatorAutoFromCatalog;

  /// No description provided for @zakatCalculatorAutoBadge.
  ///
  /// In ru, this message translates to:
  /// **'Авто'**
  String get zakatCalculatorAutoBadge;

  /// Zakat-calculator asset-card title. Distinct from zakat_settings_page.dart's `zakatSettingsSupplierDebtsToggleTitle` ("Долги поставщикам (вычет)", with a '(вычет)' suffix) — different text, do not merge. Also shares its exact value with the pre-existing `dashboardSupplierOwedSubtitle` ("Долги поставщикам"), a dashboard card subtitle; kept separate as a row label vs. a card subtitle. Do not merge.
  ///
  /// In ru, this message translates to:
  /// **'Долги поставщикам'**
  String get zakatCalculatorSupplierDebtsLabel;

  /// No description provided for @zakatCalculatorAutoFromSupplierModule.
  ///
  /// In ru, this message translates to:
  /// **'Автоматически из модуля'**
  String get zakatCalculatorAutoFromSupplierModule;

  /// No description provided for @zakatCalculatorDeductionsSection.
  ///
  /// In ru, this message translates to:
  /// **'ВЫЧЕТЫ'**
  String get zakatCalculatorDeductionsSection;

  /// No description provided for @zakatCalculatorTaxableAmountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Облагаемая сумма:'**
  String get zakatCalculatorTaxableAmountLabel;

  /// No description provided for @zakatCalculatorNisabLabel.
  ///
  /// In ru, this message translates to:
  /// **'Нисаб (85г золота):'**
  String get zakatCalculatorNisabLabel;

  /// No description provided for @zakatCalculatorNisabExceededBadge.
  ///
  /// In ru, this message translates to:
  /// **'Превышен'**
  String get zakatCalculatorNisabExceededBadge;

  /// No description provided for @zakatCalculatorZakatAmountLabel.
  ///
  /// In ru, this message translates to:
  /// **'СУММА ЗАКЯТА ({rate}%):'**
  String zakatCalculatorZakatAmountLabel(String rate);

  /// No description provided for @zakatCalculatorMarkPaidButton.
  ///
  /// In ru, this message translates to:
  /// **'Отметить как оплачено'**
  String get zakatCalculatorMarkPaidButton;

  /// No description provided for @zakatCalculatorInfoBanner.
  ///
  /// In ru, this message translates to:
  /// **'Закят — {rate}% от имущества, хранящегося 1 лунный год'**
  String zakatCalculatorInfoBanner(String rate);

  /// Full multi-line text passed to the OS share sheet — combines what were three separate concatenated string literals into one full-sentence key per the label+separator+value composite convention
  ///
  /// In ru, this message translates to:
  /// **'Закят: {due} сом.\nНисаб: {nisab} сом.\nЧистые активы: {netAssets} сом.'**
  String zakatCalculatorShareText(String due, String nisab, String netAssets);

  /// No description provided for @zakatCalculatorShareButton.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться расчётом'**
  String get zakatCalculatorShareButton;

  /// Zakat asset-breakdown card — card title. Distinct from `salesBreakdown` ("Разбивка продаж"), the Z-report sales breakdown heading.
  ///
  /// In ru, this message translates to:
  /// **'Разбивка активов'**
  String get zakatBreakdownTitle;

  /// Zakat asset-breakdown card — stock/inventory asset row label. Distinct from `stockValue` ("Стоимость товаров"), `zakatCalculatorStockValueLabel` ("Товарные остатки") and `includeStock` ("Включить товарные запасы") — three different wordings for the same concept, do not merge.
  ///
  /// In ru, this message translates to:
  /// **'Товарные запасы'**
  String get zakatBreakdownStockLabel;

  /// Zakat asset-breakdown card — bare 'Nisab' row label. Distinct from `nisabAmount` ("Сумма нисаба"), `nisabThreshold` ("Порог нисаба") and `zakatCalculatorNisabLabel` ("Нисаб (85г золота):"): this one is the bare noun with no qualifier.
  ///
  /// In ru, this message translates to:
  /// **'Нисаб'**
  String get zakatBreakdownNisabLabel;

  /// Zakat asset-breakdown card — zakat-owed row label with the rate baked into the literal. Distinct from `zakatDue` ("Сумма закята"), the bare amount label, and from `zakatCalculatorZakatAmountLabel` ("СУММА ЗАКЯТА ({rate}%):"), which is upper-case and interpolates the configured rate; this widget hardcodes 2.5%.
  ///
  /// In ru, this message translates to:
  /// **'Закят (2.5%)'**
  String get zakatBreakdownDueLabel;

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

  /// Zakat payment-history page — header title. Distinct from `zakatHistory` ("История выплат", literally 'payment history'), a differently-worded label used elsewhere for the same screen concept.
  ///
  /// In ru, this message translates to:
  /// **'История закята'**
  String get zakatHistoryPageTitle;

  /// Zakat payment-history page — empty-state title shown when the store has no zakat calculations/payments yet.
  ///
  /// In ru, this message translates to:
  /// **'Нет расчётов закята'**
  String get zakatHistoryEmptyTitle;

  /// Zakat payment-history page — empty-state subtitle pointing the user at the calculator.
  ///
  /// In ru, this message translates to:
  /// **'Рассчитайте закят в калькуляторе, чтобы история появилась здесь'**
  String get zakatHistoryEmptySubtitle;

  /// Zakat payment-history page — stats card label above the total-paid amount. Kept as a standalone colon-suffixed label key (not collapsed into a composite with the amount) because the amount sits in its own vertically-stacked slot at a larger type scale.
  ///
  /// In ru, this message translates to:
  /// **'Всего выплачено:'**
  String get zakatHistoryTotalPaidLabel;

  /// Zakat payment-history page — stats card caption under the total amount, e.g. 'за 47 выплат'; placeholder is a pre-formatted String
  ///
  /// In ru, this message translates to:
  /// **'за {count} выплат'**
  String zakatHistoryPaymentsCountLine(String count);

  /// Zakat payment-history page — title on each payment row. Distinct from `recordZakatPayment` ("Записать выплату закята"), the imperative action label.
  ///
  /// In ru, this message translates to:
  /// **'Выплата закята'**
  String get zakatHistoryPaymentTitle;

  /// Zakat payment-history page — payment row subtitle giving the payment date; placeholder is a pre-formatted date String
  ///
  /// In ru, this message translates to:
  /// **'Оплачен {date}'**
  String zakatHistoryPaidOnLine(String date);

  /// Zakat payment-history page — payment row trailing caption giving the taxable asset base. Full-sentence composite (label + separator + value) so the colon stays translatable; distinct from `zakatCalculatorTaxableAmountLabel` ("Облагаемая сумма:"), the calculator's standalone label. Placeholder is a pre-formatted String.
  ///
  /// In ru, this message translates to:
  /// **'Облагаемая: {amount}'**
  String zakatHistoryTaxableLine(String amount);

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

  /// Notice shown when net assets fall below the nisab threshold, so no zakat is owed. Promoted from `zakatCalculatorBelowNisabNotice` (value unchanged) once the shared ZakatBreakdownCard widget became a second consumer alongside zakat_calculator_page.dart — a `zakatCalculator*` page prefix disagreed with a page-independent widget's scope. Distinct from `belowNisab` ("Ниже нисаба"), the bare status badge label.
  ///
  /// In ru, this message translates to:
  /// **'Активы ниже нисаба. Закят не обязателен.'**
  String get belowNisabNotice;

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

  /// No description provided for @zakatSettingsMethodSection.
  ///
  /// In ru, this message translates to:
  /// **'МЕТОД РАСЧЁТА'**
  String get zakatSettingsMethodSection;

  /// No description provided for @zakatSettingsNisabStandardLabel.
  ///
  /// In ru, this message translates to:
  /// **'Стандарт нисаба'**
  String get zakatSettingsNisabStandardLabel;

  /// No description provided for @zakatSettingsNisabGoldOption.
  ///
  /// In ru, this message translates to:
  /// **'По золоту (85g)'**
  String get zakatSettingsNisabGoldOption;

  /// No description provided for @zakatSettingsNisabSilverOption.
  ///
  /// In ru, this message translates to:
  /// **'По серебру (595g)'**
  String get zakatSettingsNisabSilverOption;

  /// No description provided for @zakatSettingsGoldPriceLabel.
  ///
  /// In ru, this message translates to:
  /// **'Курс золота (за 1g)'**
  String get zakatSettingsGoldPriceLabel;

  /// Generic required-field form validation message — deliberately unprefixed, reusable across any form field in the app
  ///
  /// In ru, this message translates to:
  /// **'Обязательное поле'**
  String get requiredFieldError;

  /// Generic 'enter a valid number' form validation message — deliberately unprefixed
  ///
  /// In ru, this message translates to:
  /// **'Введите число'**
  String get requiredNumberError;

  /// Generic 'value cannot be negative' form validation message — deliberately unprefixed
  ///
  /// In ru, this message translates to:
  /// **'Не может быть отрицательным'**
  String get cannotBeNegativeError;

  /// No description provided for @zakatSettingsCashOnHandLabel.
  ///
  /// In ru, this message translates to:
  /// **'Наличные в кассе'**
  String get zakatSettingsCashOnHandLabel;

  /// No description provided for @zakatSettingsCashHelperText.
  ///
  /// In ru, this message translates to:
  /// **'Учитывается в активах при расчёте закята'**
  String get zakatSettingsCashHelperText;

  /// No description provided for @zakatSettingsHaulSection.
  ///
  /// In ru, this message translates to:
  /// **'ЛУННЫЙ ГОД (ХАВЛЬ)'**
  String get zakatSettingsHaulSection;

  /// Haul (lunar year) start-date field label. NOTE: spelled 'хавля' here, matching this screen's current source text exactly — the existing `haulStartDate` key holds a differently-spelled 'хауля'. This discrepancy is pre-existing in the app and out of scope to reconcile in this migration; do not merge the two keys.
  ///
  /// In ru, this message translates to:
  /// **'Дата начала хавля'**
  String get zakatSettingsHaulStartDateLabel;

  /// No description provided for @zakatSettingsReminderTitle.
  ///
  /// In ru, this message translates to:
  /// **'Напоминание'**
  String get zakatSettingsReminderTitle;

  /// No description provided for @zakatSettingsReminderSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'За 30 дней до окончания хавля'**
  String get zakatSettingsReminderSubtitle;

  /// No description provided for @zakatSettingsAutoDataSection.
  ///
  /// In ru, this message translates to:
  /// **'АВТОМАТИЧЕСКИЕ ДАННЫЕ'**
  String get zakatSettingsAutoDataSection;

  /// Zakat-settings toggle row title. Distinct from zakat_calculator_page.dart's `zakatCalculatorStockValueLabel` ("Товарные остатки", no 'магазина' suffix, to be minted in a later task) — different text, do not merge.
  ///
  /// In ru, this message translates to:
  /// **'Товарные остатки магазина'**
  String get zakatSettingsStockValueToggleTitle;

  /// No description provided for @zakatSettingsStockAutoSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Авто из каталога'**
  String get zakatSettingsStockAutoSubtitle;

  /// Zakat-settings toggle row title. Distinct from zakat_calculator_page.dart's `zakatCalculatorSupplierDebtsLabel` ("Долги поставщикам", no '(вычет)' suffix, to be minted in a later task) — different text, do not merge.
  ///
  /// In ru, this message translates to:
  /// **'Долги поставщикам (вычет)'**
  String get zakatSettingsSupplierDebtsToggleTitle;

  /// No description provided for @zakatSettingsSupplierDebtsAutoSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Авто из модуля поставщиков'**
  String get zakatSettingsSupplierDebtsAutoSubtitle;

  /// Generic in-flight 'Saving...' button label — deliberately unprefixed, reusable on any save-button loading state. Consumers so far: zakat_settings_page.dart and edit_profile_page.dart (whose non-saving counterpart is `editProfileSaveChangesButton`)
  ///
  /// In ru, this message translates to:
  /// **'Сохранение...'**
  String get savingEllipsis;

  /// No description provided for @editProfile.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать профиль'**
  String get editProfile;

  /// Edit-profile screen — tappable caption under the avatar that opens the photo picker
  ///
  /// In ru, this message translates to:
  /// **'Изменить фото'**
  String get editProfileChangePhotoLabel;

  /// Edit-profile screen — surname field label; its given-name counterpart on the same form is the generic `name` ("Имя")
  ///
  /// In ru, this message translates to:
  /// **'Фамилия'**
  String get editProfileLastNameLabel;

  /// Edit-profile screen — section header above the change-password row
  ///
  /// In ru, this message translates to:
  /// **'Безопасность'**
  String get editProfileSecuritySectionLabel;

  /// Edit-profile screen — bottom full-width save button's default (non-saving) label; its in-flight counterpart is the generic `savingEllipsis`, the other branch of the same ternary. Distinct from `save` ("Сохранить"), the bare header action button on the same screen
  ///
  /// In ru, this message translates to:
  /// **'Сохранить изменения'**
  String get editProfileSaveChangesButton;

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

  /// Delete-confirmation dialog title on the expense list page
  ///
  /// In ru, this message translates to:
  /// **'Удалить расход?'**
  String get expenseListDeleteTitle;

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

  /// Generic 'Order' label — delivery detail screen's info row label for the order number, supplier detail screen's place-order action button caption, and the create-delivery screen's sale-selection field label (formerly `deliveryDetailOrderLabel`, renamed/generalized when reused on a second screen)
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

  /// Create-delivery screen — AppBar title; distinct from `deliveryDetailTitle` ("Детали доставки") and `deliveryListTitle` ("Доставки")
  ///
  /// In ru, this message translates to:
  /// **'Новая доставка'**
  String get createDeliveryTitle;

  /// Create-delivery screen — form field label for the delivery address; distinct from `address` ("Адрес") and `deliveryDetailAddressLabel` ("Адрес", an info-row label on the delivery detail screen)
  ///
  /// In ru, this message translates to:
  /// **'Адрес доставки'**
  String get createDeliveryAddressLabel;

  /// Create-delivery screen — address field placeholder text, also reused as the field's required-value validation error
  ///
  /// In ru, this message translates to:
  /// **'Введите адрес'**
  String get createDeliveryAddressHint;

  /// Create-delivery screen — form field label above the courier-selection dropdown
  ///
  /// In ru, this message translates to:
  /// **'Курьер'**
  String get createDeliveryCourierLabel;

  /// Create-delivery screen — form field label for the optional notes field; distinct from `creditSaleNoteLabel` ("Примечание", singular) and `notes` ("Заметки")
  ///
  /// In ru, this message translates to:
  /// **'Примечания'**
  String get createDeliveryNotesLabel;

  /// Create-delivery screen — notes field placeholder indicating the field is optional
  ///
  /// In ru, this message translates to:
  /// **'Необязательно'**
  String get createDeliveryNotesHint;

  /// Create-delivery screen — submit button label
  ///
  /// In ru, this message translates to:
  /// **'Создать доставку'**
  String get createDeliveryButton;

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

  /// Generic connected-status label (printer settings screen and the settings page's Telegram-bot tile badge both reuse this — same meaning, different UI locations)
  ///
  /// In ru, this message translates to:
  /// **'Подключён'**
  String get printerSettingsConnected;

  /// Generic not-connected-status label (printer settings screen and the settings page's Telegram-bot tile badge both reuse this); distinct from `snackPrinterNotConnected`, which is a full sentence with instructions
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

  /// Line printed on the raw ESC/POS test ticket bytes — includes a literal trailing newline; distinct from settingsTileKkm ("ККМ / Фискализация", with spaces, no newline), used in UI text
  ///
  /// In ru, this message translates to:
  /// **'ККМ/Фискализация\n'**
  String get kkmTicketHeaderLine;

  /// Line printed on the raw ESC/POS test ticket bytes — includes a literal trailing newline; distinct from printerSettingsTestPrintButton ("Тестовая печать", no newline), the visible button label
  ///
  /// In ru, this message translates to:
  /// **'Тестовая печать\n'**
  String get kkmTestPrintTicketLine;

  /// KKM / fiscalisation settings screen — info banner above the printer controls
  ///
  /// In ru, this message translates to:
  /// **'Фискализация чеков через подключённый ККМ-принтер. Убедитесь, что устройство зарегистрировано в налоговой.'**
  String get kkmFiscalNoteBody;

  /// KKM / fiscalisation settings screen — section header above the Bluetooth printer connection status
  ///
  /// In ru, this message translates to:
  /// **'Bluetooth принтер'**
  String get kkmBluetoothPrinterSectionLabel;

  /// KKM / fiscalisation settings screen — label for the toggle that prints a fiscal receipt automatically after each sale
  ///
  /// In ru, this message translates to:
  /// **'Автопечать при продаже'**
  String get kkmAutoPrintLabel;

  /// Barcode scanner settings screen — AppBar title
  ///
  /// In ru, this message translates to:
  /// **'Сканер штрихкодов'**
  String get scannerPageTitle;

  /// Barcode scanner settings screen — section header above the front/back camera choice. Distinct from `subscriptionCameraSource` ("Камера"), which is the take-a-photo action in an image-source picker sheet
  ///
  /// In ru, this message translates to:
  /// **'Камера'**
  String get scannerCameraSectionLabel;

  /// No description provided for @scannerBackCameraLabel.
  ///
  /// In ru, this message translates to:
  /// **'Задняя камера'**
  String get scannerBackCameraLabel;

  /// Barcode scanner settings screen — subtitle recommending the rear camera for scanning
  ///
  /// In ru, this message translates to:
  /// **'Рекомендуется для сканирования'**
  String get scannerBackCameraHint;

  /// No description provided for @scannerFrontCameraLabel.
  ///
  /// In ru, this message translates to:
  /// **'Передняя камера'**
  String get scannerFrontCameraLabel;

  /// Barcode scanner settings screen — subtitle of the front-camera option. Deliberately a near-synonym of `scannerFrontCameraLabel` ("Передняя камера"): the tile title and its subtitle are two different phrasings of the same camera, so translations must stay distinct too
  ///
  /// In ru, this message translates to:
  /// **'Фронтальная камера'**
  String get scannerFrontCameraHint;

  /// Barcode scanner settings screen — section header above the sound/vibration/auto-add toggles
  ///
  /// In ru, this message translates to:
  /// **'Поведение'**
  String get scannerBehaviorSectionLabel;

  /// No description provided for @scannerSoundLabel.
  ///
  /// In ru, this message translates to:
  /// **'Звук при сканировании'**
  String get scannerSoundLabel;

  /// No description provided for @scannerVibrationLabel.
  ///
  /// In ru, this message translates to:
  /// **'Вибрация при сканировании'**
  String get scannerVibrationLabel;

  /// Barcode scanner settings screen — label for the toggle that adds a scanned product straight to the cart
  ///
  /// In ru, this message translates to:
  /// **'Авто-добавление в корзину'**
  String get scannerAutoAddToCartLabel;

  /// Barcode scanner settings screen — section header above the barcode-format checkboxes
  ///
  /// In ru, this message translates to:
  /// **'Форматы штрихкодов'**
  String get scannerFormatsSectionLabel;

  /// Barcode scanner settings screen — full-width save button at the bottom of the page; distinct from `save` ("Сохранить"), the bare AppBar action button on the same screen
  ///
  /// In ru, this message translates to:
  /// **'Сохранить настройки'**
  String get scannerSaveSettingsButton;

  /// Receipt template settings screen — AppBar title
  ///
  /// In ru, this message translates to:
  /// **'Шаблон чека'**
  String get receiptTemplatePageTitle;

  /// Receipt template settings screen — full-width save button at the bottom of the page; distinct from `save` ("Сохранить"), the bare AppBar action button on the same screen
  ///
  /// In ru, this message translates to:
  /// **'Сохранить шаблон'**
  String get receiptTemplateSaveButton;

  /// Receipt template settings screen — section header above the live receipt mockup preview
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр'**
  String get receiptTemplatePreviewLabel;

  /// Receipt template settings screen — section header above the header/footer text fields
  ///
  /// In ru, this message translates to:
  /// **'Текст'**
  String get receiptTemplateTextSectionLabel;

  /// Receipt template settings screen — label for the receipt header text field
  ///
  /// In ru, this message translates to:
  /// **'Заголовок чека'**
  String get receiptTemplateHeaderFieldLabel;

  /// Receipt template settings screen — hint text for the receipt header field
  ///
  /// In ru, this message translates to:
  /// **'Название магазина или приветствие'**
  String get receiptTemplateHeaderFieldHint;

  /// Receipt template settings screen — label for the receipt footer text field
  ///
  /// In ru, this message translates to:
  /// **'Подвал чека'**
  String get receiptTemplateFooterFieldLabel;

  /// Default receipt-footer text, five consumers. On the receipt-template settings screen it is both the preview fallback when the footer field is empty and, verbatim, that field's hint (the hint suggests exactly this fallback value). It is also the footer rendered by widgets/pos/receipt_widget.dart and by the two service-layer receipt renderers, core/services/thermal_printer_service.dart and core/services/receipt_pdf_service.dart
  ///
  /// In ru, this message translates to:
  /// **'Спасибо за покупку!'**
  String get receiptPreviewDefaultFooter;

  /// Receipt template settings screen — section header above the font-size selector
  ///
  /// In ru, this message translates to:
  /// **'Размер шрифта'**
  String get receiptTemplateFontSizeLabel;

  /// Receipt template settings screen — abbreviated "small" font-size segment label
  ///
  /// In ru, this message translates to:
  /// **'Мал.'**
  String get receiptTemplateFontSizeSmall;

  /// Receipt template settings screen — abbreviated "medium" font-size segment label
  ///
  /// In ru, this message translates to:
  /// **'Ср.'**
  String get receiptTemplateFontSizeMedium;

  /// Receipt template settings screen — abbreviated "large" font-size segment label
  ///
  /// In ru, this message translates to:
  /// **'Бол.'**
  String get receiptTemplateFontSizeLarge;

  /// Receipt template settings screen — section header above the paper-width selector
  ///
  /// In ru, this message translates to:
  /// **'Ширина бумаги'**
  String get receiptTemplatePaperWidthLabel;

  /// Receipt template settings screen — 58mm paper-width segment label
  ///
  /// In ru, this message translates to:
  /// **'58 мм'**
  String get receiptTemplatePaperWidth58mm;

  /// Receipt template settings screen — 80mm paper-width segment label
  ///
  /// In ru, this message translates to:
  /// **'80 мм'**
  String get receiptTemplatePaperWidth80mm;

  /// Receipt template settings screen — section header above the show/hide toggles list
  ///
  /// In ru, this message translates to:
  /// **'Показывать на чеке'**
  String get receiptTemplateShowOnReceiptLabel;

  /// Receipt template settings screen — toggle label for showing a QR code on the receipt
  ///
  /// In ru, this message translates to:
  /// **'QR-код'**
  String get receiptTemplateQrToggleLabel;

  /// Receipt template settings screen — toggle label for showing the date and time on the receipt
  ///
  /// In ru, this message translates to:
  /// **'Дата и время'**
  String get receiptTemplateDateTimeToggleLabel;

  /// Receipt template settings screen — fallback header text shown in the preview when the user hasn't typed a custom header
  ///
  /// In ru, this message translates to:
  /// **'Ваш магазин'**
  String get receiptPreviewDefaultHeader;

  /// Fixed demo content for the receipt-mockup preview, monospace-aligned — not real transaction data, no placeholders needed
  ///
  /// In ru, this message translates to:
  /// **'Товар 1                 50.00 TJS'**
  String get receiptPreviewItemLine1;

  /// Fixed demo content for the receipt-mockup preview, monospace-aligned — not real transaction data, no placeholders needed
  ///
  /// In ru, this message translates to:
  /// **'Товар 2                 30.00 TJS'**
  String get receiptPreviewItemLine2;

  /// Fixed demo content for the receipt-mockup preview, monospace-aligned — not real transaction data, no placeholders needed
  ///
  /// In ru, this message translates to:
  /// **'Скидка                  -5.00 TJS'**
  String get receiptPreviewDiscountLine;

  /// Fixed demo content for the receipt-mockup preview, monospace-aligned — not real transaction data, no placeholders needed
  ///
  /// In ru, this message translates to:
  /// **'ИТОГО                   75.00 TJS'**
  String get receiptPreviewTotalLine;

  /// Fixed demo content for the receipt-mockup preview — not real transaction data, no placeholders needed
  ///
  /// In ru, this message translates to:
  /// **'Кассир: Иванов И.'**
  String get receiptPreviewCashierLine;

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

  /// Telegram-bot settings screen — label of the stat row counting customers who have linked their Telegram account to the store
  ///
  /// In ru, this message translates to:
  /// **'Подключённых клиентов'**
  String get telegramLinkedCustomersLabel;

  /// Telegram-bot settings screen — section header above the numbered connection instructions
  ///
  /// In ru, this message translates to:
  /// **'Как подключить клиентов'**
  String get telegramHowToConnectTitle;

  /// Telegram-bot settings screen — connection instruction step 1; username is the bot handle, e.g. @dukonpro_bot
  ///
  /// In ru, this message translates to:
  /// **'Клиент находит бота {username} в Telegram'**
  String telegramStep1Text(String username);

  /// Telegram-bot settings screen — connection instruction step 2
  ///
  /// In ru, this message translates to:
  /// **'Нажимает /start и вводит свой номер телефона'**
  String get telegramStep2Text;

  /// Telegram-bot settings screen — connection instruction step 3
  ///
  /// In ru, this message translates to:
  /// **'Бот проверяет номер в базе клиентов и связывает аккаунт'**
  String get telegramStep3Text;

  /// Telegram-bot settings screen — connection instruction step 4
  ///
  /// In ru, this message translates to:
  /// **'Клиент получает уведомления о продажах и долгах'**
  String get telegramStep4Text;

  /// Telegram-bot settings screen — test-message button label while the message is in flight
  ///
  /// In ru, this message translates to:
  /// **'Отправка...'**
  String get telegramSendingButton;

  /// Telegram-bot settings screen — test-message button's default (non-sending) label; its in-flight counterpart is `telegramSendingButton`, the other branch of the same ternary. Distinct from `snackTestMessageSent` ("Тестовое сообщение отправлено"), the confirmation snackbar
  ///
  /// In ru, this message translates to:
  /// **'Тестовое сообщение'**
  String get telegramTestMessageButton;

  /// Language settings screen — AppBar title
  ///
  /// In ru, this message translates to:
  /// **'Язык интерфейса'**
  String get languageSettingsPageTitle;

  /// Language settings screen — section header above the list of selectable UI languages
  ///
  /// In ru, this message translates to:
  /// **'Выберите язык'**
  String get languageSettingsChooseLabel;

  /// Language settings screen — info banner telling the user to restart the app for the newly picked language to take effect
  ///
  /// In ru, this message translates to:
  /// **'Для применения языка перезапустите приложение.'**
  String get languageSettingsRestartNotice;

  /// No description provided for @employees.
  ///
  /// In ru, this message translates to:
  /// **'Сотрудники'**
  String get employees;

  /// Fallback shown in place of a staff member's name when the record has none — the bare noun 'Employee'. Deliberately unprefixed and shared by the current-shift card and the shift history card. Distinct from `shiftsUnknownCashier` ("Не указан", literally 'not specified'), the differently-worded fallback used inside `shiftsCashierLine`, and from `employees` ("Сотрудники", plural).
  ///
  /// In ru, this message translates to:
  /// **'Сотрудник'**
  String get unknownStaffLabel;

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

  /// Short warehouse-role badge label on the staff list page ("Склад"). Distinct from `warehouse` ("Складовщик"), the person-noun form of the same role used on the staff card/detail badges, and from `addProductStepStock` (literally the same word "Склад" but meaning the add-product wizard's stock/quantity step, not a staff role)
  ///
  /// In ru, this message translates to:
  /// **'Склад'**
  String get staffRoleWarehouseShort;

  /// Staff detail page — label under the on-shift/off-shift stat column. Distinct from `salesFilterStatusSectionLabel` ("Статус"), which is the sales-filter bottom sheet's section header above the order-status chips
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get staffStatusLabel;

  /// Staff detail page — value of the status stat column when the employee has no open shift ("Нет смены", literally 'no shift'). Distinct from `notOnShift` ("Не на смене", literally 'not on shift'), the differently-worded form the staff list page shows next to its status dot
  ///
  /// In ru, this message translates to:
  /// **'Нет смены'**
  String get staffNotOnShiftStatusDetail;

  /// Staff detail page — title of the statistics tab, alongside the shifts tab (`shifts`)
  ///
  /// In ru, this message translates to:
  /// **'Статистика'**
  String get staffStatsTabLabel;

  /// Staff detail page statistics tab — row label for the employee's sales total today. Distinct from `todaySales` ("Продажи за сегодня"), the fuller wording with the preposition "за" used elsewhere
  ///
  /// In ru, this message translates to:
  /// **'Продажи сегодня'**
  String get staffTodaySalesLabel;

  /// Staff detail page statistics tab — row label for the date the employee record was created
  ///
  /// In ru, this message translates to:
  /// **'Дата регистрации'**
  String get staffRegistrationDateLabel;

  /// Staff list page empty-state title shown when the store has no employees yet. Distinct from `noEmployees` ("Нет сотрудников"), the shorter wording used elsewhere
  ///
  /// In ru, this message translates to:
  /// **'Сотрудников пока нет'**
  String get staffListEmptyTitle;

  /// Staff list page empty-state subtitle explaining why to add employees (shift and payroll tracking)
  ///
  /// In ru, this message translates to:
  /// **'Добавьте сотрудников для учёта смен и зарплаты'**
  String get staffListEmptySubtitle;

  /// Staff list page — inline "today's sales" line next to an on-shift employee's status dot; a single contiguous text run, so label and pre-formatted amount share one key
  ///
  /// In ru, this message translates to:
  /// **'Сегодня: {amount}'**
  String staffListTodaySalesLine(String amount);

  /// Staff card widget — lowercase caption under the employee's today-sales amount ("сегодня"). Distinct from `today` ("Сегодня", capitalised), which is used as a standalone period label/chip
  ///
  /// In ru, this message translates to:
  /// **'сегодня'**
  String get staffCardTodayLabel;

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

  /// Warehouse-keeper role label as a person noun ("Складовщик"), used on the staff card and staff detail badges. Distinct from `staffRoleWarehouseShort` ("Склад"), the shortened form the staff list page's badge uses
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

  /// Off-shift status text next to the staff list page's status dot ("Не на смене"). Distinct from `staffNotOnShiftStatusDetail` ("Нет смены"), the differently-worded value the staff detail page's status stat column shows
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

  /// Open-shift page — hero card heading ('Start of shift'). Distinct from `openShift` ("Открыть смену"), the imperative AppBar title / submit button on the same screen.
  ///
  /// In ru, this message translates to:
  /// **'Начало смены'**
  String get openShiftHeading;

  /// Open-shift page — hero card subtitle asking for the opening cash amount. Distinct from `shiftsCloseCashPrompt` ("Введите сумму наличных в кассе:"), the close-shift dialog's prompt.
  ///
  /// In ru, this message translates to:
  /// **'Укажите сумму наличных в кассе на начало смены'**
  String get openShiftSubtitle;

  /// Open-shift page — opening cash field label with currency suffix. Distinct from `shiftsCashAmountLabel` ("Сумма наличных"), the same label without the '(TJS)' suffix; same pattern as `baseSalaryTjs` vs `baseSalary`.
  ///
  /// In ru, this message translates to:
  /// **'Сумма наличных (TJS)'**
  String get openShiftCashLabel;

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

  /// Close-shift dialog — prompt above the closing cash amount field
  ///
  /// In ru, this message translates to:
  /// **'Введите сумму наличных в кассе:'**
  String get shiftsCloseCashPrompt;

  /// No description provided for @shiftsCashAmountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сумма наличных'**
  String get shiftsCashAmountLabel;

  /// No description provided for @shiftsCashAmountNegative.
  ///
  /// In ru, this message translates to:
  /// **'Сумма не может быть отрицательной'**
  String get shiftsCashAmountNegative;

  /// Elapsed shift duration, e.g. '3ч 15м'
  ///
  /// In ru, this message translates to:
  /// **'{hours}ч {minutes}м'**
  String shiftsDurationFormat(String hours, String minutes);

  /// No description provided for @shiftsEmptySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Откройте смену, чтобы начать приём платежей'**
  String get shiftsEmptySubtitle;

  /// Active-shift status badge on the current-shift card — near-duplicate value to `loyaltySettingsActive` ("Активна", the loyalty-toggle label on a different screen); kept separate since that key is feature-prefixed to loyalty settings
  ///
  /// In ru, this message translates to:
  /// **'Активна'**
  String get shiftsActiveStatus;

  /// Current-shift card — cashier name line; label+value composite, distinct from the bare `cashier` label
  ///
  /// In ru, this message translates to:
  /// **'Кассир: {name}'**
  String shiftsCashierLine(String name);

  /// Fallback shown in shiftsCashierLine when the shift has no staff name recorded
  ///
  /// In ru, this message translates to:
  /// **'Не указан'**
  String get shiftsUnknownCashier;

  /// Current-shift card — opened-at time and elapsed duration line
  ///
  /// In ru, this message translates to:
  /// **'Открыта: {time}  •  Время работы: {duration}'**
  String shiftsOpenedLine(String time, String duration);

  /// Current-shift card — sales count and total amount line
  ///
  /// In ru, this message translates to:
  /// **'Продаж: {count}  |  Сумма: {amount}'**
  String shiftsSalesLine(String count, String amount);

  /// Shift history list row — opened/closed time range, sales count, and total amount
  ///
  /// In ru, this message translates to:
  /// **'{openedTime}–{closedTime}  •  {count} продаж  •  {amount}'**
  String shiftsHistoryRowLine(
    String openedTime,
    String closedTime,
    String count,
    String amount,
  );

  /// Shift history row status badge for a closed shift
  ///
  /// In ru, this message translates to:
  /// **'Сдано'**
  String get shiftsClosedStatus;

  /// Shift history row status badge for a still-open shift — distinct from `shiftsActiveStatus` ("Активна"), different wording used in the history list vs. the current-shift card
  ///
  /// In ru, this message translates to:
  /// **'Открыта'**
  String get shiftsOpenStatus;

  /// Shift history card status badge for a closed shift — the adjective 'Closed', paired with `shiftsOpenStatus` ("Открыта") in the same ternary. Distinct from `shiftsClosedStatus` ("Сдано", literally 'handed over'), a differently-worded closed-shift badge, and from `close`/`closeShift` action labels.
  ///
  /// In ru, this message translates to:
  /// **'Закрыта'**
  String get shiftCardClosedStatus;

  /// Shift history card — trailing sales-count caption, e.g. '12 продаж'. Shares its value with `dashboardSalesCountLabel` and `reportsSalesCountTooltip`, but those prefixes are scoped to the dashboard and the reports page respectively, so neither can be reused here; a generic promotion would have to repoint all three at once. Distinct from `salesCountAbbrev` ("Продаж"), the bare noun with no numeral. Placeholder is a pre-formatted String.
  ///
  /// In ru, this message translates to:
  /// **'{count} продаж'**
  String shiftCardSalesCountLine(String count);

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

  /// Z-report line — aggregate total of all refunds in the shift (plural genitive "возвратов"). Distinct from `refundTotalLabel` ("Сумма возврата:", singular) on the refund page, which is one individual refund's total.
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

  /// No description provided for @payrollPayAllTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выплатить всем'**
  String get payrollPayAllTitle;

  /// No description provided for @payrollPayAllConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите выплатить зарплату всем сотрудникам?'**
  String get payrollPayAllConfirmBody;

  /// Confirm button inside the pay-all dialog (bare verb) — distinct from `payAll` ("Оплатить всем") and `pay` ("Оплатить"), and from `payrollPayAllTitle`, which is the same text used for the dialog title and the button that opens it
  ///
  /// In ru, this message translates to:
  /// **'Выплатить'**
  String get payrollPayAllConfirm;

  /// Pay button on an individual staff member's payroll card — same word as `payrollPayAllConfirm` but pays only this one employee's entry, not all staff, so kept as a separate key
  ///
  /// In ru, this message translates to:
  /// **'Выплатить'**
  String get payrollStaffCardPayButton;

  /// No description provided for @payrollDeleteAdjustmentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить корректировку?'**
  String get payrollDeleteAdjustmentTitle;

  /// Compact toolbar button label on the payroll page — distinct from `calculatePayroll` ("Рассчитать зарплату"), a longer label used elsewhere
  ///
  /// In ru, this message translates to:
  /// **'Рассчитать'**
  String get payrollCalculateButton;

  /// No description provided for @payrollCalculateEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Расчёт зарплаты'**
  String get payrollCalculateEmptyTitle;

  /// No description provided for @payrollCalculateEmptySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите месяц и нажмите \"Рассчитать\" для расчёта зарплаты сотрудников'**
  String get payrollCalculateEmptySubtitle;

  /// No description provided for @payrollNoDataTitle.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных по зарплате'**
  String get payrollNoDataTitle;

  /// No description provided for @payrollNoDataSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите месяц и нажмите \"Рассчитать\"'**
  String get payrollNoDataSubtitle;

  /// No description provided for @payrollAddAdjustmentTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Добавить корректировку'**
  String get payrollAddAdjustmentTooltip;

  /// No description provided for @payrollNoStaffData.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных по сотрудникам'**
  String get payrollNoStaffData;

  /// No description provided for @payrollStatusCalculated.
  ///
  /// In ru, this message translates to:
  /// **'Рассчитано'**
  String get payrollStatusCalculated;

  /// No description provided for @payrollStatusPartiallyPaid.
  ///
  /// In ru, this message translates to:
  /// **'Частично оплачено'**
  String get payrollStatusPartiallyPaid;

  /// Payroll period card — disbursed-amount column label; distinct from `paid`/`paidAmount` ("Оплачено", an adjective/status word) — this labels the actual paid-out sum
  ///
  /// In ru, this message translates to:
  /// **'Выплачено'**
  String get payrollPaidLabel;

  /// AppBar title of the add-payroll-adjustment screen. Do not merge with `adjustment` ("Корректировка"), despite the identical Russian: `adjustment` is an enum-member label bound to the ADJUSTMENT stock-movement type, used in product_detail_page.dart's _typeLabel() switch alongside `intakeType`/`outflowType`. Its meaning is tied to that closed {IN, OUT, ADJUSTMENT} classification, so disambiguating or shortening that inventory badge must not silently retitle this payroll screen.
  ///
  /// In ru, this message translates to:
  /// **'Корректировка'**
  String get payrollAdjustmentPageTitle;

  /// No description provided for @payrollAdjustmentInstructions.
  ///
  /// In ru, this message translates to:
  /// **'Укажите тип, сумму и описание корректировки'**
  String get payrollAdjustmentInstructions;

  /// No description provided for @payrollAdjustmentTypeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Тип корректировки'**
  String get payrollAdjustmentTypeLabel;

  /// Add-adjustment form's deduction-type toggle label; distinct from `deduction` ("Вычет"), a different Russian word used elsewhere for the same underlying concept — do not merge, values differ character-for-character
  ///
  /// In ru, this message translates to:
  /// **'Удержание'**
  String get payrollDeductionTypeLabel;

  /// No description provided for @payrollAdjustmentStaffIdLabel.
  ///
  /// In ru, this message translates to:
  /// **'ID сотрудника (необязательно)'**
  String get payrollAdjustmentStaffIdLabel;

  /// No description provided for @payrollAdjustmentStaffIdHint.
  ///
  /// In ru, this message translates to:
  /// **'Оставьте пустым для всех'**
  String get payrollAdjustmentStaffIdHint;

  /// No description provided for @payrollAdjustmentDescriptionRequiredError.
  ///
  /// In ru, this message translates to:
  /// **'Введите описание'**
  String get payrollAdjustmentDescriptionRequiredError;

  /// No description provided for @payrollAdjustmentAmountMustBePositiveError.
  ///
  /// In ru, this message translates to:
  /// **'Сумма должна быть больше 0'**
  String get payrollAdjustmentAmountMustBePositiveError;

  /// Add-adjustment form's bare submit button label; same bare verb as `customerListAddConfirm` ("Добавить"), which is scoped to the add-customer dialog — no unprefixed generic `add` key exists in this ARB, so each bare-"Добавить" confirm button stays feature-scoped
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get payrollAdjustmentSubmit;

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

  /// Permission label "Управление клиентами" (clients). Distinct from `permissionManageCustomersLabel` ("Управление покупателями", buyers/shoppers) — the roles screen's permission matrix uses that differently-worded variant for the same underlying `manage_customers` permission
  ///
  /// In ru, this message translates to:
  /// **'Управление клиентами'**
  String get manageCustomers;

  /// Permission label "Управление сотрудниками" (employees). Distinct from `permissionManageStaffLabel` ("Управление персоналом", personnel) — the roles screen's permission matrix uses that differently-worded variant for the same underlying `manage_staff` permission
  ///
  /// In ru, this message translates to:
  /// **'Управление сотрудниками'**
  String get manageStaff;

  /// No description provided for @viewReports.
  ///
  /// In ru, this message translates to:
  /// **'Просмотр отчётов'**
  String get viewReports;

  /// Roles screen permission-matrix label for the `manage_staff` permission ("Управление персоналом", personnel). Distinct from `manageStaff` ("Управление сотрудниками", employees), the wording used by the older staff-permissions UI for the same permission
  ///
  /// In ru, this message translates to:
  /// **'Управление персоналом'**
  String get permissionManageStaffLabel;

  /// Roles screen permission-matrix label for the `manage_expenses` permission. Distinct from `addExpenses` ("Добавление расходов"), which names only the add-expense capability
  ///
  /// In ru, this message translates to:
  /// **'Управление расходами'**
  String get permissionManageExpensesLabel;

  /// Roles screen permission-matrix label for the `manage_customers` permission ("Управление покупателями", buyers/shoppers). Distinct from `manageCustomers` ("Управление клиентами", clients), the wording used by the older staff-permissions UI for the same permission
  ///
  /// In ru, this message translates to:
  /// **'Управление покупателями'**
  String get permissionManageCustomersLabel;

  /// Roles screen permission-matrix label for the `manage_suppliers` permission
  ///
  /// In ru, this message translates to:
  /// **'Управление поставщиками'**
  String get permissionManageSuppliersLabel;

  /// Roles screen permission-matrix label for the `manage_stock` permission
  ///
  /// In ru, this message translates to:
  /// **'Управление складом'**
  String get permissionManageStockLabel;

  /// Roles screen permission-matrix label for the `manage_debts` permission
  ///
  /// In ru, this message translates to:
  /// **'Управление долгами'**
  String get permissionManageDebtsLabel;

  /// Roles screen permission-matrix label for the `manage_settings` permission — worded as "Настройки магазина" (store settings) rather than as a manage-* phrase
  ///
  /// In ru, this message translates to:
  /// **'Настройки магазина'**
  String get permissionManageSettingsLabel;

  /// Roles screen permission-matrix label for the `open_close_shift` permission
  ///
  /// In ru, this message translates to:
  /// **'Открытие/закрытие смены'**
  String get permissionOpenCloseShiftLabel;

  /// Roles screen permission-matrix label for the `apply_discounts` permission
  ///
  /// In ru, this message translates to:
  /// **'Применение скидок'**
  String get permissionApplyDiscountsLabel;

  /// Roles screen permission-matrix label for the `manage_payroll` permission
  ///
  /// In ru, this message translates to:
  /// **'Управление зарплатой'**
  String get permissionManagePayrollLabel;

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

  /// Discounts list screen — AppBar title
  ///
  /// In ru, this message translates to:
  /// **'Скидки'**
  String get discountsPageTitle;

  /// No description provided for @discountsEmptyState.
  ///
  /// In ru, this message translates to:
  /// **'Нет скидок. Нажмите + для создания.'**
  String get discountsEmptyState;

  /// Delete-confirmation dialog title on the discounts list page — distinct from `a11yEditDiscount`/`a11yDeleteDiscount` above, which label the row's edit/delete icon buttons (tooltips), not this dialog's title text
  ///
  /// In ru, this message translates to:
  /// **'Удалить скидку?'**
  String get discountsDeleteTitle;

  /// Discount create/edit bottom sheet header when editing an existing discount — same wording as the `a11yEditDiscount` tooltip but a different UI role (sheet header vs. icon-button tooltip), kept as a separate key
  ///
  /// In ru, this message translates to:
  /// **'Редактировать скидку'**
  String get discountsEditTitle;

  /// Discount create/edit bottom sheet header when creating a new discount
  ///
  /// In ru, this message translates to:
  /// **'Новая скидка'**
  String get discountsNewTitle;

  /// No description provided for @discountsTypePercent.
  ///
  /// In ru, this message translates to:
  /// **'% Процент'**
  String get discountsTypePercent;

  /// No description provided for @discountsTypeFixed.
  ///
  /// In ru, this message translates to:
  /// **'Сум Фиксированная'**
  String get discountsTypeFixed;

  /// No description provided for @discountsValuePercentLabel.
  ///
  /// In ru, this message translates to:
  /// **'Значение (%)'**
  String get discountsValuePercentLabel;

  /// No description provided for @discountsValueFixedLabel.
  ///
  /// In ru, this message translates to:
  /// **'Значение (TJS)'**
  String get discountsValueFixedLabel;

  /// No description provided for @discountsMinOrderLabel.
  ///
  /// In ru, this message translates to:
  /// **'Мин. сумма заказа (условие, необязательно)'**
  String get discountsMinOrderLabel;

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

  /// Generic load-failure snackbar, mirrors snackSaveError but for a failed data load instead of a failed save
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки'**
  String get snackLoadError;

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

  /// No description provided for @investmentAddPageTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавить вложение'**
  String get investmentAddPageTitle;

  /// No description provided for @investmentInvestorNameRequiredError.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя инвестора'**
  String get investmentInvestorNameRequiredError;

  /// No description provided for @investmentStartDateLabel.
  ///
  /// In ru, this message translates to:
  /// **'Дата начала'**
  String get investmentStartDateLabel;

  /// No description provided for @investmentEndDateLabel.
  ///
  /// In ru, this message translates to:
  /// **'Дата окончания (необязательно)'**
  String get investmentEndDateLabel;

  /// No description provided for @investmentInvestorNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Имя инвестора *'**
  String get investmentInvestorNameLabel;

  /// No description provided for @investmentAmountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сумма *'**
  String get investmentAmountLabel;

  /// Add-investment form field label — the amount to be returned to the investor. Bare label with no trailing punctuation. Distinct from `refundTotalLabel` ("Сумма возврата:", with a trailing colon) which is a sale-refund total display label on the refund page — same words, different domain, and the values differ character-for-character, so the two must not be merged.
  ///
  /// In ru, this message translates to:
  /// **'Сумма возврата'**
  String get investmentReturnAmountLabel;

  /// No description provided for @investmentInvestorPhoneLabel.
  ///
  /// In ru, this message translates to:
  /// **'Телефон инвестора'**
  String get investmentInvestorPhoneLabel;

  /// Generic 'Investments' label — the investments list page's AppBar title and the finance-dashboard section-grid item. Promoted from `financeDashboardInvestments` once the investments page itself needed it, since a `financeDashboard*` prefix disagreed with a page-level title scope.
  ///
  /// In ru, this message translates to:
  /// **'Вложения'**
  String get investments;

  /// Empty state shown when the investments list has no items
  ///
  /// In ru, this message translates to:
  /// **'Вложений пока нет'**
  String get investmentEmptyState;

  /// Investment status label for ACTIVE — used both as a filter chip and as the per-row status badge
  ///
  /// In ru, this message translates to:
  /// **'Активно'**
  String get investmentStatusActive;

  /// Investment status label for COMPLETED — neuter gender ("Завершено") agreeing with 'вложение'. Distinct from `completed` ("Завершена", feminine); the two differ character-for-character and must not be merged.
  ///
  /// In ru, this message translates to:
  /// **'Завершено'**
  String get investmentStatusCompleted;

  /// Investment status label for CANCELLED — neuter gender ("Отменено") agreeing with 'вложение'. Distinct from `cancelled` ("Отменена", feminine); the two differ character-for-character and must not be merged.
  ///
  /// In ru, this message translates to:
  /// **'Отменено'**
  String get investmentStatusCancelled;

  /// Exchange-rates page AppBar title
  ///
  /// In ru, this message translates to:
  /// **'Курсы валют'**
  String get currenciesPageTitle;

  /// Title above the 30-day exchange-rate history line chart — distinct from the bare generic `dynamics` ("Динамика")
  ///
  /// In ru, this message translates to:
  /// **'Динамика за 30 дней'**
  String get currenciesHistoryChartTitle;

  /// Empty state shown inside an expanded currency card when no 30-day rate history is available
  ///
  /// In ru, this message translates to:
  /// **'Нет данных за 30 дней'**
  String get currenciesNoHistoryData;

  /// Section title of the currency-converter card at the bottom of the exchange-rates page
  ///
  /// In ru, this message translates to:
  /// **'Конвертер'**
  String get currenciesConverterTitle;

  /// Label above the converter's result figure. The result is always expressed in TJS, so the currency code is part of the string; kept as a standalone colon-suffixed label because layout puts the value in its own filled container below, not in the same text run.
  ///
  /// In ru, this message translates to:
  /// **'Результат (в TJS):'**
  String get currenciesConvertedResultLabel;

  /// Full name of the National Bank of Tajikistan (NBT), shown as the rate-source attribution line above the exchange-rate list. Generic (unprefixed) since the same attribution plausibly belongs anywhere a NBT-sourced rate is displayed.
  ///
  /// In ru, this message translates to:
  /// **'НБТ — Национальный банк Таджикистана'**
  String get nbtBankLabel;

  /// Currency display name — US Dollar. Deliberately generic (unprefixed) so a future currency picker can reuse it. These four names were once duplicated as a hardcoded Russian map in lib/data/datasources/remote/currency_remote_datasource.dart; that map is gone — CurrencyRate now carries only code/rate/flag and the display name is resolved from these keys at the render site (currencies_page.dart's _currencyLabel).
  ///
  /// In ru, this message translates to:
  /// **'Доллар США'**
  String get currencyUsd;

  /// Currency display name — Russian Ruble
  ///
  /// In ru, this message translates to:
  /// **'Российский рубль'**
  String get currencyRub;

  /// Currency display name — Euro
  ///
  /// In ru, this message translates to:
  /// **'Евро'**
  String get currencyEur;

  /// Currency display name — Chinese Yuan
  ///
  /// In ru, this message translates to:
  /// **'Китайский юань'**
  String get currencyCny;
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
