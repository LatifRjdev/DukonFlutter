# DuckonPro — Комплексный редизайн: Vibrant Gradient

**Дата:** 2026-04-09
**Статус:** Draft
**Платформы:** Flutter, Android (Compose), iOS (SwiftUI)

---

## 1. Цель

Обновить визуальный стиль всего приложения DuckonPro с текущего стандартного Material 3 (Cyan/Teal) на Vibrant Gradient стиль с glassmorphism. Подключить Dark Mode, улучшить UX, добавить accessibility. Создать единую дизайн-систему для всех трёх платформ.

### Что НЕ входит в scope
- Новые фичи и бизнес-логика
- Изменения в бэкенде (NestJS API)
- Изменения в БД (SQLDelight/Prisma)
- Изменения в архитектуре (Clean Architecture, BLoC остаются)

---

## 2. Подход: Design System First

**Порядок:** Дизайн-токены → Flutter компоненты → Compose компоненты → SwiftUI компоненты → Применить ко всем экранам

---

## 3. Дизайн-токены

### 3.1 Цветовая палитра

#### Primary Gradient
| Токен | Значение | Назначение |
|-------|----------|------------|
| `gradient.start` | `#667EEA` | Начало градиента (индиго) |
| `gradient.mid` | `#7C4DFF` | Середина (глубокий фиолетовый) |
| `gradient.end` | `#764BA2` | Конец градиента (пурпурный) |
| `primary` | `#667EEA` | Основной цвет (кнопки, ссылки) |
| `primary.dark` | `#5468d4` | Pressed state |
| `onPrimary` | `#FFFFFF` | Текст на primary |

#### Светлая тема — Surfaces
| Токен | Значение | Назначение |
|-------|----------|------------|
| `light.background` | `#F4F0FA` | Фон экрана |
| `light.surface` | `#FFFFFF` | Карточки, модалы |
| `light.surfaceElevated` | `#EDE7F6` | Приподнятые элементы |
| `light.border` | `#E8E0F0` | Границы |
| `light.text.primary` | `#1E1B4B` | Основной текст |
| `light.text.secondary` | `#64748B` | Вторичный текст |
| `light.text.hint` | `#94A3B8` | Подсказки |

#### Тёмная тема — Surfaces
| Токен | Значение | Назначение |
|-------|----------|------------|
| `dark.background` | `#0F0A1A` | Фон экрана |
| `dark.surface` | `#1A1128` | Карточки (glass) |
| `dark.surfaceElevated` | `#241B36` | Приподнятые элементы |
| `dark.border` | `#2D2640` | Границы |
| `dark.text.primary` | `#F0ECF8` | Основной текст |
| `dark.text.secondary` | `#A09CB0` | Вторичный текст |
| `dark.text.hint` | `#7C7A8E` | Подсказки |

#### Status Colors
| Токен | Light | Dark | Назначение |
|-------|-------|------|------------|
| `success` | `#00C853` | `#69F0AE` | Успех |
| `success.bg` | `#E8F5E9` | `rgba(0,200,83,0.1)` | Фон успеха |
| `warning` | `#FFAB00` | `#FFD740` | Предупреждение |
| `warning.bg` | `#FFF8E1` | `rgba(255,171,0,0.1)` | Фон предупреждения |
| `error` | `#FF1744` | `#FF5252` | Ошибка |
| `error.bg` | `#FCE4EC` | `rgba(255,23,68,0.1)` | Фон ошибки |
| `info` | `#2979FF` | `#82B1FF` | Информация |
| `info.bg` | `#E3F2FD` | `rgba(41,121,255,0.1)` | Фон информации |

### 3.2 Типографика

Шрифт остаётся **Inter** (уже подключён).

| Токен | Размер | Вес | Назначение |
|-------|--------|-----|------------|
| `heading.xl` | 28px | 800 | Главный заголовок |
| `heading.lg` | 24px | 700 | Заголовок секции |
| `heading.md` | 20px | 700 | Подзаголовок |
| `title.lg` | 18px | 600 | Заголовок карточки |
| `title.md` | 16px | 600 | Подзаголовок карточки |
| `title.sm` | 14px | 600 | Мелкий заголовок |
| `body.lg` | 16px | 400 | Основной текст |
| `body.md` | 14px | 400 | Текст по умолчанию |
| `body.sm` | 12px | 400 | Мелкий текст |
| `label.lg` | 16px | 600 | Кнопки крупные |
| `label.md` | 14px | 500 | Кнопки, чипы |
| `label.sm` | 12px | 500 | Бейджи, хинты |
| `label.xs` | 10px | 600 | Bottom nav labels |
| `number.xl` | 32px | 800 | Большие числа (KPI) |
| `number.lg` | 22px | 700 | Числа в stat cards |
| `number.md` | 14px | 700 | Числа в списках |

### 3.3 Spacing & Layout

Без изменений — текущая 8px grid система хорошая:

| Токен | Значение |
|-------|----------|
| `space.xs` | 4px |
| `space.sm` | 8px |
| `space.md` | 16px |
| `space.lg` | 24px |
| `space.xl` | 32px |
| `space.xxl` | 48px |

### 3.4 Border Radius

| Токен | Значение | Назначение |
|-------|----------|------------|
| `radius.sm` | 8px | Мелкие элементы, бейджи |
| `radius.md` | 12px | Кнопки, инпуты, иконки |
| `radius.lg` | 16px | Карточки, модалы |
| `radius.xl` | 20px | Крупные карточки, хедер |
| `radius.round` | 100px | Чипы, аватары |

### 3.5 Shadows

| Токен | Light | Dark |
|-------|-------|------|
| `shadow.sm` | `0 1px 4px rgba(102,126,234,0.06)` | none (используем border) |
| `shadow.md` | `0 4px 16px rgba(102,126,234,0.1)` | none |
| `shadow.lg` | `0 4px 20px rgba(102,126,234,0.12)` | none |
| `shadow.button` | `0 4px 16px rgba(102,126,234,0.35)` | `0 4px 16px rgba(102,126,234,0.4)` |

### 3.6 Glassmorphism (Dark Theme Only)

| Свойство | Значение |
|----------|----------|
| Background | `rgba(255,255,255,0.06)` |
| Border | `1px solid rgba(255,255,255,0.1)` |
| Backdrop filter | `blur(12px)` |
| Card elevated bg | `rgba(255,255,255,0.04)` |

---

## 4. Компоненты

### 4.1 Кнопки

**Primary (Gradient):**
- Background: linear-gradient(135deg, #667EEA, #764BA2)
- Text: белый, 15px, weight 700
- Padding: 16px 32px
- Radius: 14px
- Shadow: shadow.button
- Height: 56px (full), 40px (small)

**Outlined:**
- Border: 2px solid #667EEA
- Text: #667EEA
- Background: transparent

**Danger:**
- Background: rgba(255,23,68,0.08) / dark: rgba(255,23,68,0.12)
- Text: #FF1744 / dark: #FF5252

**Text/Small:**
- Background: rgba(102,126,234,0.1)
- Text: #667EEA

### 4.2 Поля ввода

- Background: light.surface / dark.surface
- Border default: 1.5px solid light.border / dark.border
- Border focused: 2px solid primary + shadow `0 0 0 4px rgba(102,126,234,0.1)`
- Border error: 2px solid error + shadow `0 0 0 4px rgba(255,23,68,0.08)`
- Radius: 14px
- Padding: 14px 16px
- Label: 12px, primary (focused) / hint (default)

### 4.3 Карточки

**Light:**
- Background: #FFFFFF
- Radius: 16px (стандарт) / 20px (крупные)
- Shadow: shadow.md
- Фиолетовый оттенок теней

**Dark (Glassmorphism):**
- Background: rgba(255,255,255,0.06)
- Backdrop-filter: blur(12px)
- Border: 1px solid rgba(255,255,255,0.1)
- Radius: 16px / 20px
- No shadow

### 4.4 Чипы и бейджи

**Active chip:** gradient background, white text
**Inactive chip:** rgba(102,126,234,0.08), primary text
**Status badge:** соответствующий status.bg + status color

### 4.5 Search Bar

- Background: light.surface / dark.surface
- Radius: 14px
- Shadow: shadow.sm (light only)
- Icon: hint color
- Keyboard shortcut badge: gradient mini-pill

### 4.6 Bottom Navigation

- 5 табов: Главная, Товары, **Касса** (центр), Финансы, Ещё
- Касса — выступающая кнопка: 52x52px, radius 16px, gradient, shadow.button, поднята на -20px
- Active tab: primary color text
- Inactive tab: hint color text
- Light bg: #FFFFFF, border-top light.border
- Dark bg: rgba(255,255,255,0.04), border-top rgba(255,255,255,0.06)

### 4.7 App Header (Gradient)

- Background: linear-gradient(135deg, #667EEA, #764BA2)
- Extended: padding-bottom 60px для overlap с контентом
- Store selector: полупрозрачная pill внутри хедера
- Icon buttons: 36x36, radius 12px, rgba(255,255,255,0.15)
- Приветствие + имя пользователя

### 4.8 Stat Cards

- Overlap с gradient header (margin-top: -36px)
- 2 в ряд
- Числа: number.lg weight 800
- Trend badge: success.bg + success цвет
- Label: hint цвет, 11px

### 4.9 List Items

- Background: light.surfaceElevated / dark card elevated
- Radius: 12px
- Padding: 10px
- Icon container: 40x40, radius 12px, gradient tint
- Title: 13px, weight 600
- Subtitle: 11px, hint
- Amount: number.md, weight 700

---

## 5. Экраны для обновления

### Все 55 экранов Flutter + KMP нативные экраны

**Фаза 1 — Core (дизайн-система + 10 ключевых экранов):**
1. Dashboard (home_page.dart)
2. POS Checkout (pos_checkout_page.dart)
3. Product List (product_list_page.dart)
4. Sales History (sales_history_page.dart)
5. Login (login_page.dart)
6. Settings (settings_page.dart) — включая Dark Mode toggle
7. Add Product Step 1 (add_product_step1_page.dart)
8. Finance Dashboard (finance_dashboard_page.dart)
9. Customer Debts (customer_debts_page.dart)
10. Receipt Preview (receipt_preview_page.dart)

**Фаза 2 — Remaining Flutter (оставшиеся 45 экранов)**

**Фаза 3 — Android Compose (все экраны)**

**Фаза 4 — iOS SwiftUI (все экраны)**

---

## 6. Dark Mode

### Реализация

**Flutter:**
- Подключить ThemeMode к MaterialApp через BLoC/Provider
- Settings toggle → сохранять в SharedPreferences
- Поддержка системной темы (ThemeMode.system)
- Все цвета через Theme.of(context) — не хардкодить

**Android Compose:**
- MaterialTheme с динамическими colorSchemes
- isSystemInDarkTheme() + пользовательский override
- Все цвета через MaterialTheme.colorScheme

**iOS SwiftUI:**
- @Environment(\.colorScheme) для системной темы
- UserDefaults для пользовательского override
- Color assets в Asset Catalog

### Glassmorphism в Dark Mode
- Карточки: `rgba(255,255,255,0.06)` с `backdrop-filter: blur(12px)`
- Границы: `rgba(255,255,255,0.1)`
- Вложенные элементы: `rgba(255,255,255,0.04)`
- **Flutter:** `BackdropFilter` + `ClipRRect`
- **Compose:** нет нативного backdrop-filter → имитация через полупрозрачные слои + blur modifier (Android 12+)
- **SwiftUI:** `.ultraThinMaterial` или `.regularMaterial`

---

## 7. UX-улучшения

### 7.1 Анимации (минимальные)
- Переходы между экранами: fade + slide (300ms)
- Появление карточек: fade-in (200ms)
- Bottom sheet: slide-up (300ms)
- Skeleton loading вместо спиннеров
- Нет Lottie, нет confetti, нет сложных анимаций

### 7.2 Пустые состояния
- Заменить текущие Material Icons 80px на стилизованные SVG-иллюстрации
- Каждый пустой список: иллюстрация + заголовок + описание + CTA кнопка
- В градиентных тонах (#667EEA, #764BA2)

### 7.3 Локализация
- Убрать все хардкод русские строки из виджетов (bottom nav, settings)
- Все строки через l10n/ARB файлы
- Поддержка: ru, tg, uz, en

---

## 8. Accessibility

- Semantic labels на все интерактивные элементы
- Контрастность текста: минимум WCAG AA (4.5:1 для body, 3:1 для large text)
- Touch target: минимум 44x44px
- Поддержка Dynamic Type (iOS) / Font Scale (Android)
- Focus indicators для keyboard navigation
- Screen reader announcements на ключевых действиях (продажа завершена, ошибка)

---

## 9. Файлы для модификации

### Flutter (`app/lib/`)
| Файл | Изменение |
|------|-----------|
| `core/constants/app_colors.dart` | Полная замена палитры |
| `core/theme/app_theme.dart` | Новые light/dark темы + glassmorphism |
| `core/constants/app_constants.dart` | Обновить radius (12→14 для кнопок) |
| `presentation/widgets/common/*` | Все 17 компонентов |
| `presentation/widgets/dashboard/*` | Stat cards, chart styles |
| `presentation/widgets/pos/*` | POS-специфичные виджеты |
| `presentation/pages/**/*.dart` | Все 55 экранов |
| `presentation/blocs/app/` | Добавить ThemeMode в AppBloc |
| `app.dart` | Подключить ThemeMode к MaterialApp |
| `l10n/*.arb` | Убрать хардкод строки |

### Android Compose (`androidApp/`)
| Файл | Изменение |
|------|-----------|
| `ui/theme/Color.kt` | Новая палитра |
| `ui/theme/Theme.kt` | Light/Dark schemes |
| `ui/theme/Type.kt` | Typography tokens |
| `ui/components/*` | Новые компоненты |
| `ui/**/*Screen.kt` | Все экраны |

### iOS SwiftUI (`iosApp/`)
| Файл | Изменение |
|------|-----------|
| `UI/Theme/Colors.swift` | Новая палитра |
| `UI/Theme/Typography.swift` | Typography tokens |
| `UI/Components/*` | Новые компоненты |
| `UI/**/*View.swift` | Все экраны |
| `Assets.xcassets` | Color assets для light/dark |

---

## 10. Верификация

### Тестирование
- Визуальная проверка каждого экрана в light + dark mode
- Accessibility audit: Xcode Accessibility Inspector (iOS), TalkBack (Android)
- Контрастность: проверить все комбинации текст/фон
- Проверить на реальных устройствах: маленький экран (SE), большой (Pro Max), Android 720p/1080p
- Проверить landscape если поддерживается
- Убедиться что все строки локализованы (нет хардкод текста)

### Критерии готовности
- [ ] Все 55 Flutter экранов обновлены
- [ ] Dark mode работает с toggle в Settings
- [ ] System theme detection работает
- [ ] Все Compose экраны обновлены
- [ ] Все SwiftUI экраны обновлены
- [ ] Нет хардкод строк
- [ ] WCAG AA контрастность на всех экранах
- [ ] Touch targets ≥ 44px
- [ ] Skeleton loading на всех списках
