# Sprint 1: Theme Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix theme infrastructure so both light and dark themes work correctly, driven by user preference from SettingsBloc.

**Architecture:** Wrap `MaterialApp.router` in a `BlocBuilder<SettingsBloc, SettingsState>` that provides `themeMode` based on the stored preference. Add a `darkTheme` to `MaterialApp`. Extend `GlassCard` with an `accentColor` prop for the new KPI pattern. Introduce `theme_extensions.dart` for `context.bg`, `context.textPrimary`, etc. Update `AppTheme.light` / `AppTheme.dark` and `AppColors` to match the approved design tokens. Bundle Plus Jakarta Sans as app fonts.

**Tech Stack:** Flutter, flutter_bloc, SharedPreferences, Plus Jakarta Sans (bundled), mocktail + bloc_test for tests

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `app/lib/core/constants/app_colors.dart` | Update brand palette to design-spec values |
| Create | `app/lib/core/theme/theme_extensions.dart` | `BuildContext` getters for theme-aware colors |
| Modify | `app/lib/core/theme/app_theme.dart` | Plus Jakarta Sans font, updated colors |
| Modify | `app/lib/presentation/widgets/common/glass_card.dart` | Add optional `accentColor` border-left |
| Modify | `app/lib/app.dart` | Wrap `MaterialApp.router` with `BlocBuilder`, add `darkTheme` |
| Modify | `app/pubspec.yaml` | Add Plus Jakarta Sans font files |
| Create | `app/assets/fonts/PlusJakartaSans-*.ttf` | 4 font weight files (download) |
| Create | `app/test/core/theme/theme_extensions_test.dart` | Unit tests for context getters |
| Create | `app/test/presentation/widgets/common/glass_card_test.dart` | Widget tests for light/dark rendering |
| Create | `app/test/app_test.dart` | Integration test: SettingsBloc state → MaterialApp themeMode |

---

### Task 1: Download and Bundle Plus Jakarta Sans

**Files:**
- Create: `app/assets/fonts/PlusJakartaSans-Regular.ttf`
- Create: `app/assets/fonts/PlusJakartaSans-Medium.ttf`
- Create: `app/assets/fonts/PlusJakartaSans-SemiBold.ttf`
- Create: `app/assets/fonts/PlusJakartaSans-Bold.ttf`
- Create: `app/assets/fonts/PlusJakartaSans-ExtraBold.ttf`
- Modify: `app/pubspec.yaml`

- [ ] **Step 1: Download font files**

Download from Google Fonts GitHub source (version tagged, not CDN):

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
mkdir -p assets/fonts
cd assets/fonts

BASE="https://github.com/tokotype/PlusJakartaSans/raw/master/fonts/ttf"
curl -sSL -o PlusJakartaSans-Regular.ttf   "$BASE/PlusJakartaSans-Regular.ttf"
curl -sSL -o PlusJakartaSans-Medium.ttf    "$BASE/PlusJakartaSans-Medium.ttf"
curl -sSL -o PlusJakartaSans-SemiBold.ttf  "$BASE/PlusJakartaSans-SemiBold.ttf"
curl -sSL -o PlusJakartaSans-Bold.ttf      "$BASE/PlusJakartaSans-Bold.ttf"
curl -sSL -o PlusJakartaSans-ExtraBold.ttf "$BASE/PlusJakartaSans-ExtraBold.ttf"
ls -l
```

Expected: 5 `.ttf` files, each > 40 KB (if any file is < 10 KB it failed — redownload).

- [ ] **Step 2: Register fonts in pubspec.yaml**

Find the existing `fonts:` block (after Inter definitions) in `app/pubspec.yaml` and add:

```yaml
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
    - family: PlusJakartaSans
      fonts:
        - asset: assets/fonts/PlusJakartaSans-Regular.ttf
          weight: 400
        - asset: assets/fonts/PlusJakartaSans-Medium.ttf
          weight: 500
        - asset: assets/fonts/PlusJakartaSans-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/PlusJakartaSans-Bold.ttf
          weight: 700
        - asset: assets/fonts/PlusJakartaSans-ExtraBold.ttf
          weight: 800
```

- [ ] **Step 3: Verify pubspec parses**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter pub get
```

Expected: `Got dependencies!` with no errors.

- [ ] **Step 4: Commit**

```bash
git add app/assets/fonts/ app/pubspec.yaml app/pubspec.lock
git commit -m "feat(theme): bundle Plus Jakarta Sans font family"
```

---

### Task 2: Update AppColors to Design-Spec Tokens

**Files:**
- Modify: `app/lib/core/constants/app_colors.dart`

- [ ] **Step 1: Replace brand and semantic colors with spec values**

Open `app/lib/core/constants/app_colors.dart`. Replace the `class AppColors` contents as follows. Keep existing constant names (many files reference them), but update color values to match the spec.

```dart
import 'package:flutter/material.dart';

class AppColors {
  // Brand gradient (aligned with design spec: indigo-500 → violet-500)
  static const Color gradientStart = Color(0xFF6366F1);
  static const Color gradientMid = Color(0xFF7C6AF0);
  static const Color gradientEnd = Color(0xFF8B5CF6);

  // Primary brand
  static const Color primary = Color(0xFF6366F1);       // indigo-500
  static const Color primaryDark = Color(0xFF818CF8);   // indigo-400 for dark theme
  static const Color onPrimary = Colors.white;

  // Secondary (gradient partner / accents)
  static const Color secondary = Color(0xFF8B5CF6);     // violet-500
  static const Color secondaryDark = Color(0xFFA78BFA); // violet-400

  // Light theme surfaces
  static const Color lightBackground = Color(0xFFF4F0FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF9F5FC);
  static const Color lightBorder = Color(0xFFE8E0F0);
  static const Color lightTextPrimary = Color(0xFF1E1B4B);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextHint = Color(0xFF94A3B8);

  // Dark theme surfaces (not pure black — prevents OLED smear)
  static const Color darkBackground = Color(0xFF0F0A1A);
  static const Color darkSurface = Color(0xFF1A1128);
  static const Color darkSurfaceElevated = Color(0xFF241937);
  static const Color darkBorder = Color(0xFF2D2042);
  static const Color darkTextPrimary = Color(0xFFF0ECF8);
  static const Color darkTextSecondary = Color(0xFFC4B5FD);
  static const Color darkTextHint = Color(0xFFA09CB0);

  // Semantic accents (light theme values; dark variants via context.* extensions)
  static const Color success = Color(0xFF10B981);       // emerald-500
  static const Color successDark = Color(0xFF34D399);   // emerald-400 for dark
  static const Color successBg = Color(0xFFD1FAE5);

  static const Color warning = Color(0xFFF59E0B);       // amber-500
  static const Color warningDark = Color(0xFFFBBF24);   // amber-400 for dark
  static const Color warningBg = Color(0xFFFEF3C7);

  static const Color error = Color(0xFFEF4444);         // red-500
  static const Color errorDark = Color(0xFFF87171);     // red-400 for dark
  static const Color errorBg = Color(0xFFFEE2E2);

  static const Color info = Color(0xFF3B82F6);          // blue-500
  static const Color infoDark = Color(0xFF60A5FA);      // blue-400 for dark
  static const Color infoBg = Color(0xFFDBEAFE);

  // Accent tints for icon backgrounds (light mode)
  static const Color primaryTint = Color(0xFFEDE9FE);   // violet-100
  static const Color successTint = Color(0xFFD1FAE5);
  static const Color dangerTint = Color(0xFFFEE2E2);
  static const Color warningTint = Color(0xFFFEF3C7);
  static const Color infoTint = Color(0xFFDBEAFE);

  // Utility
  static const Color disabled = Color(0xFFCBD5E1);
  static const Color overlay = Color(0x80000000);

  // Glassmorphism (dark theme only)
  static const Color glassBg = Color(0x14B387F5);       // rgba(139,92,246,0.08)
  static const Color glassBorder = Color(0x1FFFFFFF);   // rgba(255,255,255,0.12)
  static const Color glassElevated = Color(0x1FB387F5); // rgba(139,92,246,0.12)
}
```

- [ ] **Step 2: Verify no breakage**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/core/constants/app_colors.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/core/constants/app_colors.dart
git commit -m "feat(theme): update AppColors to match design-spec tokens"
```

---

### Task 3: Update AppTheme to Use Plus Jakarta Sans

**Files:**
- Modify: `app/lib/core/theme/app_theme.dart`

- [ ] **Step 1: Replace font source**

Open `app/lib/core/theme/app_theme.dart`. Remove the `google_fonts` import (if any) and replace all `GoogleFonts.inter(...)` / `GoogleFonts.interTextTheme(...)` calls with `TextStyle(fontFamily: 'PlusJakartaSans', ...)`.

Find the existing `TextTheme` construction (usually toward the bottom of the file). Replace with:

```dart
static const String _font = 'PlusJakartaSans';

static final TextTheme _textTheme = const TextTheme(
  displayLarge:  TextStyle(fontFamily: _font, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
  displayMedium: TextStyle(fontFamily: _font, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
  displaySmall:  TextStyle(fontFamily: _font, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3),
  headlineLarge: TextStyle(fontFamily: _font, fontSize: 22, fontWeight: FontWeight.w700),
  headlineMedium:TextStyle(fontFamily: _font, fontSize: 20, fontWeight: FontWeight.w700),
  headlineSmall: TextStyle(fontFamily: _font, fontSize: 18, fontWeight: FontWeight.w700),
  titleLarge:    TextStyle(fontFamily: _font, fontSize: 17, fontWeight: FontWeight.w700),
  titleMedium:   TextStyle(fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w600),
  titleSmall:    TextStyle(fontFamily: _font, fontSize: 14, fontWeight: FontWeight.w600),
  bodyLarge:     TextStyle(fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w500, height: 1.5),
  bodyMedium:    TextStyle(fontFamily: _font, fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
  bodySmall:     TextStyle(fontFamily: _font, fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
  labelLarge:    TextStyle(fontFamily: _font, fontSize: 14, fontWeight: FontWeight.w600),
  labelMedium:   TextStyle(fontFamily: _font, fontSize: 12, fontWeight: FontWeight.w600),
  labelSmall:    TextStyle(fontFamily: _font, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0),
);
```

Wire `_textTheme` into both `AppTheme.light` and `AppTheme.dark`:

```dart
static ThemeData get light => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.lightBackground,
  colorScheme: ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.secondary,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightTextPrimary,
    error: AppColors.error,
  ),
  textTheme: _textTheme.apply(
    bodyColor: AppColors.lightTextPrimary,
    displayColor: AppColors.lightTextPrimary,
  ),
  // ...keep existing cardTheme, elevatedButtonTheme, etc. — do NOT remove them
);

static ThemeData get dark => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.darkBackground,
  colorScheme: ColorScheme.dark(
    primary: AppColors.primaryDark,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.secondaryDark,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkTextPrimary,
    error: AppColors.errorDark,
  ),
  textTheme: _textTheme.apply(
    bodyColor: AppColors.darkTextPrimary,
    displayColor: AppColors.darkTextPrimary,
  ),
  // ...keep existing cardTheme, elevatedButtonTheme, etc.
);
```

Keep every non-text section of the existing theme (cardTheme, buttons, inputDecoration, etc.). Only the text/color parts change here.

- [ ] **Step 2: Verify fonts load**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/core/theme/app_theme.dart
```

Expected: `No issues found!`.

- [ ] **Step 3: Commit**

```bash
git add app/lib/core/theme/app_theme.dart
git commit -m "feat(theme): switch typography to bundled Plus Jakarta Sans"
```

---

### Task 4: Create Theme Extensions

**Files:**
- Create: `app/lib/core/theme/theme_extensions.dart`

- [ ] **Step 1: Write the failing test first**

Create `app/test/core/theme/theme_extensions_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokonpro/core/constants/app_colors.dart';
import 'package:dokonpro/core/theme/app_theme.dart';
import 'package:dokonpro/core/theme/theme_extensions.dart';

Widget _wrap(ThemeData theme, Widget child) =>
    MaterialApp(theme: theme, home: Scaffold(body: Builder(builder: (_) => child)));

void main() {
  group('ThemeColors extension', () {
    testWidgets('context.bg returns scaffoldBackgroundColor (light)', (tester) async {
      late Color bg;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { bg = ctx.bg; return const SizedBox(); }),
      ));
      expect(bg, AppColors.lightBackground);
    });

    testWidgets('context.bg returns darkBackground (dark)', (tester) async {
      late Color bg;
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { bg = ctx.bg; return const SizedBox(); }),
      ));
      expect(bg, AppColors.darkBackground);
    });

    testWidgets('context.success differs between themes', (tester) async {
      late Color lightSuccess;
      late Color darkSuccess;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { lightSuccess = ctx.success; return const SizedBox(); }),
      ));
      await tester.pumpWidget(_wrap(
        AppTheme.dark,
        Builder(builder: (ctx) { darkSuccess = ctx.success; return const SizedBox(); }),
      ));
      expect(lightSuccess, AppColors.success);
      expect(darkSuccess, AppColors.successDark);
      expect(lightSuccess, isNot(darkSuccess));
    });

    testWidgets('context.textPrimary uses colorScheme.onSurface', (tester) async {
      late Color t;
      await tester.pumpWidget(_wrap(
        AppTheme.light,
        Builder(builder: (ctx) { t = ctx.textPrimary; return const SizedBox(); }),
      ));
      expect(t, AppColors.lightTextPrimary);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter test test/core/theme/theme_extensions_test.dart
```

Expected: FAIL with "Target of URI doesn't exist: 'package:dokonpro/core/theme/theme_extensions.dart'".

- [ ] **Step 3: Create theme_extensions.dart**

Create `app/lib/core/theme/theme_extensions.dart`:

```dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Theme-aware color accessors. Call from widget `build` methods only
/// (requires a valid `Theme.of(context)`).
extension ThemeColors on BuildContext {
  ThemeData get _theme => Theme.of(this);
  bool get _isDark => _theme.brightness == Brightness.dark;

  /// Scaffold background.
  Color get bg => _theme.scaffoldBackgroundColor;

  /// Card / elevated surface.
  Color get surface => _isDark ? AppColors.darkSurface : AppColors.lightSurface;

  /// Secondary muted surface.
  Color get surfaceMuted =>
      _isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated;

  /// Divider / border color.
  Color get border => _isDark ? AppColors.darkBorder : AppColors.lightBorder;

  /// Primary body text.
  Color get textPrimary => _theme.colorScheme.onSurface;

  /// Secondary text (captions, sub-labels).
  Color get textSecondary =>
      _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  /// Hint / placeholder text.
  Color get textMuted =>
      _isDark ? AppColors.darkTextHint : AppColors.lightTextHint;

  /// Brand primary (adapted for contrast per theme).
  Color get primary => _theme.colorScheme.primary;

  /// Brand secondary / violet.
  Color get secondary => _theme.colorScheme.secondary;

  /// Semantic success.
  Color get success => _isDark ? AppColors.successDark : AppColors.success;

  /// Semantic danger / error.
  Color get danger => _isDark ? AppColors.errorDark : AppColors.error;

  /// Semantic warning.
  Color get warning => _isDark ? AppColors.warningDark : AppColors.warning;

  /// Semantic info.
  Color get info => _isDark ? AppColors.infoDark : AppColors.info;
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/core/theme/theme_extensions_test.dart
```

Expected: `All tests passed!` (4 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/theme/theme_extensions.dart app/test/core/theme/theme_extensions_test.dart
git commit -m "feat(theme): add ThemeColors context extension with tests"
```

---

### Task 5: Add accentColor Prop to GlassCard

**Files:**
- Modify: `app/lib/presentation/widgets/common/glass_card.dart`

- [ ] **Step 1: Write the failing widget test first**

Create `app/test/presentation/widgets/common/glass_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokonpro/core/constants/app_colors.dart';
import 'package:dokonpro/core/theme/app_theme.dart';
import 'package:dokonpro/presentation/widgets/common/glass_card.dart';

Widget _host(ThemeData theme, Widget child) =>
    MaterialApp(theme: theme, home: Scaffold(body: child));

void main() {
  group('GlassCard', () {
    testWidgets('light theme renders opaque white surface', (tester) async {
      await tester.pumpWidget(_host(
        AppTheme.light,
        const GlassCard(child: Text('hello')),
      ));
      expect(find.text('hello'), findsOneWidget);
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(GlassCard), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.lightSurface);
    });

    testWidgets('dark theme renders glass background', (tester) async {
      await tester.pumpWidget(_host(
        AppTheme.dark,
        const GlassCard(child: Text('hello')),
      ));
      // Dark mode uses ClipRRect + BackdropFilter
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('accentColor adds left border in light theme', (tester) async {
      await tester.pumpWidget(_host(
        AppTheme.light,
        GlassCard(accentColor: AppColors.primary, child: const Text('x')),
      ));
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(GlassCard), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      final border = decoration.border as Border;
      expect(border.left.color, AppColors.primary);
      expect(border.left.width, 3);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/presentation/widgets/common/glass_card_test.dart
```

Expected: FAIL — the `accentColor` parameter does not exist yet.

- [ ] **Step 3: Add accentColor prop and border logic**

Open `app/lib/presentation/widgets/common/glass_card.dart`. Find the current widget definition (~72 lines). Add `accentColor` to the constructor and adjust the light-mode container decoration.

Replace the class with:

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final bool elevated;
  final Color? accentColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 14,
    this.elevated = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final body = Padding(padding: padding, child: child);

    if (!isDark) {
      // Light: solid surface with shadow and optional left accent border
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.lightSurface,
              borderRadius: BorderRadius.circular(radius),
              border: accentColor != null
                  ? Border(left: BorderSide(color: accentColor!, width: 3))
                  : null,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: body,
          ),
        ),
      );
    }

    // Dark: glass surface (backdrop blur + violet tint + white hairline border)
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: elevated ? AppColors.glassElevated : AppColors.glassBg,
                borderRadius: BorderRadius.circular(radius),
                border: Border(
                  left: accentColor != null
                      ? BorderSide(color: accentColor!, width: 3)
                      : BorderSide(color: AppColors.glassBorder, width: 1),
                  right: accentColor != null
                      ? BorderSide(color: AppColors.glassBorder, width: 1)
                      : BorderSide(color: AppColors.glassBorder, width: 1),
                  top: BorderSide(color: AppColors.glassBorder, width: 1),
                  bottom: BorderSide(color: AppColors.glassBorder, width: 1),
                ),
              ),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/presentation/widgets/common/glass_card_test.dart
```

Expected: `All tests passed!` (3 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/presentation/widgets/common/glass_card.dart app/test/presentation/widgets/common/glass_card_test.dart
git commit -m "feat(ui): add accentColor border-left to GlassCard"
```

---

### Task 6: Wire SettingsBloc to MaterialApp.router

**Files:**
- Modify: `app/lib/app.dart`

- [ ] **Step 1: Write the failing integration test first**

Create `app/test/app_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dokonpro/core/theme/app_theme.dart';
import 'package:dokonpro/presentation/blocs/settings/settings_bloc.dart';
import 'package:dokonpro/presentation/blocs/settings/settings_state.dart';
import 'package:dokonpro/domain/entities/user.dart';

class MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _FakeEvent extends Fake implements SettingsEvent {}

// Smallest possible harness: only the BlocBuilder + MaterialApp segment from app.dart.
// We're testing the wiring, not the full app.
Widget _underTest(SettingsBloc bloc) {
  return BlocProvider<SettingsBloc>.value(
    value: bloc,
    child: BlocBuilder<SettingsBloc, SettingsState>(
      buildWhen: (prev, curr) {
        final prevTheme = prev is SettingsLoaded ? prev.themeMode : ThemeMode.system;
        final currTheme = curr is SettingsLoaded ? curr.themeMode : ThemeMode.system;
        return prevTheme != currTheme;
      },
      builder: (context, state) {
        final themeMode =
            state is SettingsLoaded ? state.themeMode : ThemeMode.system;
        return MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          home: const Scaffold(body: Text('home')),
        );
      },
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
  });

  group('App theme wiring', () {
    late MockSettingsBloc bloc;

    final dummyUser = const User(
      id: 'id', phone: '+9920000', name: 'T', email: null, role: 'OWNER',
    );

    setUp(() {
      bloc = MockSettingsBloc();
    });

    testWidgets('defaults to system when state is not SettingsLoaded', (tester) async {
      when(() => bloc.state).thenReturn(SettingsInitial());
      whenListen(bloc, Stream<SettingsState>.fromIterable([SettingsInitial()]),
          initialState: SettingsInitial());

      await tester.pumpWidget(_underTest(bloc));
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
    });

    testWidgets('uses dark when SettingsLoaded emits themeMode=dark', (tester) async {
      final loaded = SettingsLoaded(dummyUser, themeMode: ThemeMode.dark);
      when(() => bloc.state).thenReturn(loaded);
      whenListen(bloc, Stream<SettingsState>.fromIterable([loaded]),
          initialState: loaded);

      await tester.pumpWidget(_underTest(bloc));
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });

    testWidgets('uses light when SettingsLoaded emits themeMode=light', (tester) async {
      final loaded = SettingsLoaded(dummyUser, themeMode: ThemeMode.light);
      when(() => bloc.state).thenReturn(loaded);
      whenListen(bloc, Stream<SettingsState>.fromIterable([loaded]),
          initialState: loaded);

      await tester.pumpWidget(_underTest(bloc));
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/app_test.dart
```

Expected: FAIL — `User` constructor mismatch or SettingsLoaded import errors (depending on project). If the User entity constructor differs, look at `app/lib/domain/entities/user.dart` and adjust the `dummyUser` call in the test to match required fields (keep it minimal).

- [ ] **Step 3: Update app.dart to read SettingsBloc state and add darkTheme**

Open `app/lib/app.dart`. Replace the current `child: MaterialApp.router(...)` section inside `MultiBlocProvider` with a `BlocBuilder`:

```dart
child: BlocBuilder<SettingsBloc, SettingsState>(
  buildWhen: (prev, curr) {
    final prevTheme = prev is SettingsLoaded ? prev.themeMode : ThemeMode.system;
    final currTheme = curr is SettingsLoaded ? curr.themeMode : ThemeMode.system;
    return prevTheme != currTheme;
  },
  builder: (context, state) {
    final themeMode =
        state is SettingsLoaded ? state.themeMode : ThemeMode.system;
    return MaterialApp.router(
      title: 'DukonPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: AppRouter.router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
    );
  },
),
```

Key changes:
- Wraps `MaterialApp.router` in `BlocBuilder<SettingsBloc, SettingsState>`
- Adds `darkTheme: AppTheme.dark`
- `themeMode` is now dynamic
- `buildWhen` prevents navigation reset on unrelated SettingsBloc state transitions (fixes the bug from previous session)

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/app_test.dart
```

Expected: `All tests passed!` (3 tests).

- [ ] **Step 5: Full app analyze**

```bash
flutter analyze lib/app.dart
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/app.dart app/test/app_test.dart
git commit -m "feat(theme): bind MaterialApp.router to SettingsBloc theme state"
```

---

### Task 7: Trigger Settings Load on App Startup

**Files:**
- Modify: `app/lib/app.dart`

The `BlocBuilder` from Task 6 only reflects state — it doesn't make the bloc load. Without a `SettingsProfileRequested` dispatch, `state` stays `SettingsInitial` forever and theme falls back to `system`.

- [ ] **Step 1: Dispatch SettingsProfileRequested inside a BlocProvider create**

In `app/lib/app.dart`, find the `BlocProvider(create: (_) => sl<SettingsBloc>())` line in the `providers: [...]` list and change it to:

```dart
BlocProvider(
  create: (_) => sl<SettingsBloc>()..add(SettingsProfileRequested()),
),
```

Make sure `SettingsProfileRequested` is imported at the top of `app.dart`:

```dart
import 'presentation/blocs/settings/settings_event.dart';
```

- [ ] **Step 2: Verify analyze is clean**

```bash
flutter analyze lib/app.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Verify theme tests still pass**

```bash
flutter test test/app_test.dart test/core/theme/ test/presentation/widgets/common/glass_card_test.dart
```

Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add app/lib/app.dart
git commit -m "feat(theme): dispatch SettingsProfileRequested to load theme preference"
```

---

### Task 8: Manual Verification on Device / Emulator

**Files:**
- None — manual QA only

- [ ] **Step 1: Run the app**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter run -d <device-id>
```

Use a real device or emulator where SharedPreferences persists across sessions.

- [ ] **Step 2: Verify light theme is default**

Expected: app launches with the lilac `#F4F0FA` background, Plus Jakarta Sans visible throughout.

- [ ] **Step 3: Toggle dark mode in Settings**

Navigate: Ещё → Настройки → Тёмная тема toggle ON.

Expected:
- Entire app switches to dark background `#0F0A1A`
- Text becomes readable (light text on dark)
- GlassCard widgets now show blur + violet tint (not white rectangles)
- Navigation stack is preserved (no redirect to home/splash)

- [ ] **Step 4: Kill and relaunch the app**

Kill the app fully (swipe from recents), then relaunch.

Expected: app opens directly in dark mode — preference persisted.

- [ ] **Step 5: Toggle back to light**

Verify the toggle also works in reverse (dark → light) and persists on restart.

- [ ] **Step 6: Run full test suite**

```bash
flutter test
```

Expected: all tests pass (existing + new ones from this sprint).

- [ ] **Step 7: Commit any test fixes found during manual QA**

If manual QA revealed any test gaps, write the failing test now, fix the code, and commit.

```bash
git commit -m "chore: sprint 1 manual QA — theme toggle verified on device"
```

(Commit can be empty with `--allow-empty` if no code changes were needed — just to mark the QA checkpoint in history.)

---

## Self-Review Checklist

- [x] Spec coverage — all Sprint 1 acceptance criteria mapped to tasks above (theme toggle → Tasks 6+7, no dark cards in light → Task 5, no light surfaces in dark → Task 3, Plus Jakarta Sans default → Tasks 1+3)
- [x] No placeholders — every step has executable code or command
- [x] Type consistency — `ThemeColors` extension names match between `theme_extensions.dart` and its test; `GlassCard.accentColor` signature matches across Task 5 steps
- [x] Tests match spec — `theme_extensions_test.dart`, `glass_card_test.dart`, `app_test.dart` all listed in the Testing Strategy section of the design spec
