# Broken/Hidden/Incomplete Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 8 non-functional, hidden, or incomplete features in the Dukon app before launch.

**Architecture:** Four sprints — Auth & Quick Fixes → Finance Module → Excel Import → Polish. Each sprint produces working, testable software. Backend uses NestJS + Prisma, frontend uses Flutter + BLoC + GetIt DI.

**Tech Stack:** Flutter (BLoC, GoRouter, GetIt, Dio), NestJS (Prisma, class-validator, Passport), PostgreSQL, exceljs

---

## File Structure

### Sprint 1 — Auth & Quick Fixes
| Action | File |
|--------|------|
| Modify | `app/lib/presentation/pages/dashboard/dashboard_page.dart` (profile tap + calendar fix) |
| Modify | `api/prisma/schema.prisma` (OtpCode model) |
| Create | `api/src/modules/auth/otp.service.ts` |
| Create | `api/src/modules/auth/sms-provider.interface.ts` |
| Create | `api/src/modules/auth/console-sms.provider.ts` |
| Create | `api/src/modules/auth/dto/send-otp.dto.ts` |
| Create | `api/src/modules/auth/dto/verify-otp.dto.ts` |
| Create | `api/src/modules/auth/dto/forgot-password.dto.ts` |
| Create | `api/src/modules/auth/dto/reset-password.dto.ts` |
| Modify | `api/src/modules/auth/auth.controller.ts` |
| Modify | `api/src/modules/auth/auth.module.ts` |
| Modify | `app/lib/data/datasources/remote/auth_remote_datasource.dart` |
| Modify | `app/lib/presentation/blocs/auth/auth_bloc.dart` |
| Modify | `app/lib/presentation/blocs/auth/auth_event.dart` |
| Modify | `app/lib/presentation/blocs/auth/auth_state.dart` |
| Modify | `app/lib/presentation/pages/auth/otp_page.dart` |
| Modify | `app/lib/presentation/pages/auth/forgot_password_page.dart` |
| Modify | `app/lib/presentation/pages/auth/create_password_page.dart` |

### Sprint 2 — Finance Module
| Action | File |
|--------|------|
| Modify | `api/prisma/schema.prisma` (Investment model + InvestmentStatus enum) |
| Create | `api/src/modules/investments/investments.module.ts` |
| Create | `api/src/modules/investments/investments.controller.ts` |
| Create | `api/src/modules/investments/investments.service.ts` |
| Create | `api/src/modules/investments/dto/create-investment.dto.ts` |
| Create | `api/src/modules/investments/dto/update-investment.dto.ts` |
| Create | `api/src/modules/investments/dto/investment-query.dto.ts` |
| Create | `app/lib/domain/entities/investment.dart` |
| Create | `app/lib/data/datasources/remote/investment_remote_datasource.dart` |
| Create | `app/lib/domain/repositories/investment_repository.dart` |
| Create | `app/lib/data/repositories/investment_repository_impl.dart` |
| Create | `app/lib/presentation/blocs/investment/investment_bloc.dart` |
| Create | `app/lib/presentation/blocs/investment/investment_event.dart` |
| Create | `app/lib/presentation/blocs/investment/investment_state.dart` |
| Create | `app/lib/presentation/pages/finance/investment_list_page.dart` |
| Create | `app/lib/presentation/pages/finance/add_investment_page.dart` |
| Modify | `app/lib/injection.dart` (register investment DI) |
| Modify | `app/lib/core/router/app_router.dart` (investment routes) |
| Modify | `app/lib/presentation/pages/finance/finance_dashboard_page.dart` (remove stub) |
| Modify | `app/lib/presentation/pages/finance/currencies_page.dart` (backend integration) |
| Create | `app/lib/data/datasources/remote/currency_remote_datasource.dart` |
| Create | `app/lib/presentation/blocs/currency/currency_bloc.dart` |
| Create | `app/lib/presentation/blocs/currency/currency_event.dart` |
| Create | `app/lib/presentation/blocs/currency/currency_state.dart` |
| Modify | `app/lib/presentation/pages/settings/settings_page.dart` (notification toggle) |

### Sprint 3 — Excel Import
| Action | File |
|--------|------|
| Create | `api/src/modules/products/import-products.service.ts` |
| Create | `api/src/modules/products/templates/product-import-template.ts` |
| Modify | `api/src/modules/products/products.controller.ts` (import endpoints) |
| Modify | `api/src/modules/products/products.module.ts` |
| Create | `app/lib/presentation/blocs/import/import_bloc.dart` |
| Create | `app/lib/presentation/blocs/import/import_event.dart` |
| Create | `app/lib/presentation/blocs/import/import_state.dart` |
| Modify | `app/lib/data/datasources/remote/product_remote_datasource.dart` (import methods) |
| Modify | `app/lib/presentation/pages/product/import_products_page.dart` (full rewrite) |
| Modify | `app/lib/presentation/pages/product/product_list_page.dart` (import menu item) |
| Modify | `app/lib/injection.dart` (register import bloc) |

---

## Sprint 1 — Auth & Quick Fixes

### Task 1: Fix Profile Button Navigation

**Files:**
- Modify: `app/lib/presentation/pages/dashboard/dashboard_page.dart:268`

- [ ] **Step 1: Fix the empty onProfileTap handler**

In `app/lib/presentation/pages/dashboard/dashboard_page.dart`, replace line 268:

```dart
// OLD:
onProfileTap: () {},

// NEW:
onProfileTap: () => context.push(RouteNames.settings),
```

Ensure `RouteNames` is already imported (it should be — check top of file for `import '../../../core/router/route_names.dart'`). If not, add it.

- [ ] **Step 2: Verify the fix**

Run the app and tap the profile avatar ("S" circle) in the top right corner. It should navigate to the Settings page.

- [ ] **Step 3: Commit**

```bash
git add app/lib/presentation/pages/dashboard/dashboard_page.dart
git commit -m "fix: wire profile button to settings page"
```

---

### Task 2: Fix Calendar Date Range Persistence

**Files:**
- Modify: `app/lib/presentation/pages/dashboard/dashboard_page.dart:331-343`

- [ ] **Step 1: Add state variables for custom date range**

In `dashboard_page.dart`, find the state variables section (around line 63). Add:

```dart
DateTimeRange? _customDateRange;
```

- [ ] **Step 2: Update the calendar handler to persist the range**

Replace the calendar `GestureDetector` `onTap` handler (lines ~331-343):

```dart
// OLD:
onTap: () async {
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2024),
    lastDate: DateTime.now(),
    locale: const Locale('ru'),
  );
  if (picked != null) {
    // Custom date range — for now reload with 'month'
    _onPeriodChanged('month');
  }
},

// NEW:
onTap: () async {
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2024),
    lastDate: DateTime.now(),
    initialDateRange: _customDateRange,
    locale: const Locale('ru'),
  );
  if (picked != null) {
    setState(() {
      _selectedPeriod = 'custom';
      _customDateRange = picked;
    });
    context.read<DashboardBloc>().add(DashboardPeriodChanged(
      storeId: _getStoreId(),
      period: 'custom',
      startDate: picked.start,
      endDate: picked.end,
    ));
  }
},
```

- [ ] **Step 3: Update the period chip UI to reflect custom selection**

Find where period chips are rendered. Update the selected state to handle 'custom':

```dart
// In the period chip builder, after 'month' chip:
// The calendar icon should appear selected when _selectedPeriod == 'custom'
Container(
  decoration: BoxDecoration(
    color: _selectedPeriod == 'custom' ? AppColors.primary : Colors.transparent,
    borderRadius: BorderRadius.circular(20),
  ),
  // ... existing calendar icon
)
```

- [ ] **Step 4: Verify**

Run the app, tap the calendar icon, select a date range, confirm it loads filtered data and the calendar icon appears selected.

- [ ] **Step 5: Commit**

```bash
git add app/lib/presentation/pages/dashboard/dashboard_page.dart
git commit -m "fix: persist custom date range selection in dashboard"
```

---

### Task 3: Add OtpCode Model to Prisma

**Files:**
- Modify: `api/prisma/schema.prisma`

- [ ] **Step 1: Add OtpType enum and OtpCode model to Prisma schema**

Open `api/prisma/schema.prisma`. Add after the existing enums (after the `Currency` enum block):

```prisma
enum OtpType {
  VERIFY
  RESET
}

model OtpCode {
  id        String   @id @default(uuid())
  phone     String
  code      String
  type      OtpType
  expiresAt DateTime
  used      Boolean  @default(false)
  createdAt DateTime @default(now())

  @@index([phone, type])
  @@map("otp_codes")
}
```

- [ ] **Step 2: Generate migration**

```bash
cd /Users/latifrjdev/Downloads/Dukon/api
npx prisma migrate dev --name add_otp_codes
```

Expected: Migration created successfully, Prisma Client regenerated.

- [ ] **Step 3: Verify the generated client**

```bash
cd /Users/latifrjdev/Downloads/Dukon/api
npx prisma generate
```

Expected: `✔ Generated Prisma Client`

- [ ] **Step 4: Commit**

```bash
git add api/prisma/schema.prisma api/prisma/migrations/
git commit -m "feat: add OtpCode model for OTP verification and password reset"
```

---

### Task 4: Create SMS Provider Interface and Console Implementation

**Files:**
- Create: `api/src/modules/auth/sms-provider.interface.ts`
- Create: `api/src/modules/auth/console-sms.provider.ts`

- [ ] **Step 1: Create the SMS provider interface**

Create `api/src/modules/auth/sms-provider.interface.ts`:

```typescript
export interface SmsProvider {
  sendSms(phone: string, message: string): Promise<void>;
}

export const SMS_PROVIDER = 'SMS_PROVIDER';
```

- [ ] **Step 2: Create the console SMS provider (dev/testing)**

Create `api/src/modules/auth/console-sms.provider.ts`:

```typescript
import { Injectable, Logger } from '@nestjs/common';
import { SmsProvider } from './sms-provider.interface';

@Injectable()
export class ConsoleSmsProvider implements SmsProvider {
  private readonly logger = new Logger(ConsoleSmsProvider.name);

  async sendSms(phone: string, message: string): Promise<void> {
    this.logger.log(`[SMS to ${phone}]: ${message}`);
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add api/src/modules/auth/sms-provider.interface.ts api/src/modules/auth/console-sms.provider.ts
git commit -m "feat: add SMS provider interface with console implementation"
```

---

### Task 5: Create OTP Service

**Files:**
- Create: `api/src/modules/auth/otp.service.ts`

- [ ] **Step 1: Create OTP service**

Create `api/src/modules/auth/otp.service.ts`:

```typescript
import {
  Injectable,
  BadRequestException,
  Inject,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { OtpType } from '@prisma/client';
import { SmsProvider, SMS_PROVIDER } from './sms-provider.interface';

@Injectable()
export class OtpService {
  constructor(
    private prisma: PrismaService,
    @Inject(SMS_PROVIDER) private smsProvider: SmsProvider,
  ) {}

  async sendOtp(phone: string, type: OtpType): Promise<void> {
    // Rate limiting: max 3 per minute
    const recentCount = await this.prisma.otpCode.count({
      where: {
        phone,
        type,
        createdAt: { gte: new Date(Date.now() - 60_000) },
      },
    });

    if (recentCount >= 3) {
      throw new BadRequestException(
        'Слишком много запросов. Попробуйте через минуту.',
      );
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 60_000); // 60 seconds

    await this.prisma.otpCode.create({
      data: { phone, code, type, expiresAt },
    });

    await this.smsProvider.sendSms(
      phone,
      `DukonPro: Ваш код подтверждения: ${code}`,
    );
  }

  async verifyOtp(phone: string, code: string, type: OtpType): Promise<boolean> {
    const otp = await this.prisma.otpCode.findFirst({
      where: {
        phone,
        code,
        type,
        used: false,
        expiresAt: { gte: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otp) {
      throw new BadRequestException('Неверный или истёкший код');
    }

    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: { used: true },
    });

    return true;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add api/src/modules/auth/otp.service.ts
git commit -m "feat: add OTP service with rate limiting and verification"
```

---

### Task 6: Create OTP DTOs

**Files:**
- Create: `api/src/modules/auth/dto/send-otp.dto.ts`
- Create: `api/src/modules/auth/dto/verify-otp.dto.ts`
- Create: `api/src/modules/auth/dto/forgot-password.dto.ts`
- Create: `api/src/modules/auth/dto/reset-password.dto.ts`

- [ ] **Step 1: Create send-otp DTO**

Create `api/src/modules/auth/dto/send-otp.dto.ts`:

```typescript
import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches } from 'class-validator';

export class SendOtpDto {
  @ApiProperty({ example: '+992901234567' })
  @IsString()
  @Matches(/^\+992\d{9}$/, { message: 'Неверный формат номера телефона (+992XXXXXXXXX)' })
  phone: string;
}
```

- [ ] **Step 2: Create verify-otp DTO**

Create `api/src/modules/auth/dto/verify-otp.dto.ts`:

```typescript
import { ApiProperty } from '@nestjs/swagger';
import { IsString, Length, Matches } from 'class-validator';

export class VerifyOtpDto {
  @ApiProperty({ example: '+992901234567' })
  @IsString()
  @Matches(/^\+992\d{9}$/, { message: 'Неверный формат номера телефона' })
  phone: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  @Length(6, 6, { message: 'Код должен содержать 6 цифр' })
  code: string;
}
```

- [ ] **Step 3: Create forgot-password DTO**

Create `api/src/modules/auth/dto/forgot-password.dto.ts`:

```typescript
import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches } from 'class-validator';

export class ForgotPasswordDto {
  @ApiProperty({ example: '+992901234567' })
  @IsString()
  @Matches(/^\+992\d{9}$/, { message: 'Неверный формат номера телефона' })
  phone: string;
}
```

- [ ] **Step 4: Create reset-password DTO**

Create `api/src/modules/auth/dto/reset-password.dto.ts`:

```typescript
import { ApiProperty } from '@nestjs/swagger';
import { IsString, Length, Matches, MinLength } from 'class-validator';

export class ResetPasswordDto {
  @ApiProperty({ example: '+992901234567' })
  @IsString()
  @Matches(/^\+992\d{9}$/, { message: 'Неверный формат номера телефона' })
  phone: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  @Length(6, 6, { message: 'Код должен содержать 6 цифр' })
  code: string;

  @ApiProperty({ example: 'newPassword123' })
  @IsString()
  @MinLength(6, { message: 'Пароль должен содержать минимум 6 символов' })
  newPassword: string;
}
```

- [ ] **Step 5: Commit**

```bash
git add api/src/modules/auth/dto/send-otp.dto.ts api/src/modules/auth/dto/verify-otp.dto.ts api/src/modules/auth/dto/forgot-password.dto.ts api/src/modules/auth/dto/reset-password.dto.ts
git commit -m "feat: add OTP and password reset DTOs with validation"
```

---

### Task 7: Wire OTP Endpoints into Auth Controller and Module

**Files:**
- Modify: `api/src/modules/auth/auth.controller.ts`
- Modify: `api/src/modules/auth/auth.service.ts`
- Modify: `api/src/modules/auth/auth.module.ts`

- [ ] **Step 1: Add OTP methods to auth.service.ts**

Add these methods to `AuthService` in `api/src/modules/auth/auth.service.ts` (after the existing `logoutAll` method):

```typescript
import * as bcrypt from 'bcrypt';
import { OtpService } from './otp.service';
import { OtpType } from '@prisma/client';

// Add to constructor:
// constructor(
//   private prisma: PrismaService,
//   private jwtService: JwtService,
//   private configService: ConfigService,
//   private otpService: OtpService,  // <-- ADD THIS
// ) {}

async sendOtp(phone: string) {
  const user = await this.prisma.user.findUnique({ where: { phone } });
  if (!user) {
    throw new BadRequestException('Пользователь с таким номером не найден');
  }
  await this.otpService.sendOtp(phone, OtpType.VERIFY);
  return { message: 'Код отправлен' };
}

async verifyOtp(phone: string, code: string) {
  await this.otpService.verifyOtp(phone, code, OtpType.VERIFY);
  const user = await this.prisma.user.findUnique({ where: { phone } });
  return this.issueTokens(user.id, user.phone);
}

async forgotPassword(phone: string) {
  const user = await this.prisma.user.findUnique({ where: { phone } });
  if (!user) {
    throw new BadRequestException('Пользователь с таким номером не найден');
  }
  await this.otpService.sendOtp(phone, OtpType.RESET);
  return { message: 'Код для сброса пароля отправлен' };
}

async resetPassword(phone: string, code: string, newPassword: string) {
  await this.otpService.verifyOtp(phone, code, OtpType.RESET);
  const hashed = await bcrypt.hash(newPassword, 12);
  await this.prisma.user.update({
    where: { phone },
    data: { password: hashed },
  });
  return { message: 'Пароль успешно изменён' };
}
```

- [ ] **Step 2: Add OTP endpoints to auth.controller.ts**

Add these endpoints to `AuthController` in `api/src/modules/auth/auth.controller.ts` (after the existing `logoutAll` endpoint):

```typescript
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';

@Throttle({ default: { ttl: 60000, limit: 3 } })
@Post('send-otp')
@ApiOperation({ summary: 'Send OTP code to phone number' })
async sendOtp(@Body() dto: SendOtpDto) {
  return this.authService.sendOtp(dto.phone);
}

@Throttle({ default: { ttl: 60000, limit: 5 } })
@Post('verify-otp')
@ApiOperation({ summary: 'Verify OTP code and issue tokens' })
async verifyOtp(@Body() dto: VerifyOtpDto) {
  return this.authService.verifyOtp(dto.phone, dto.code);
}

@Throttle({ default: { ttl: 60000, limit: 3 } })
@Post('forgot-password')
@ApiOperation({ summary: 'Send password reset OTP' })
async forgotPassword(@Body() dto: ForgotPasswordDto) {
  return this.authService.forgotPassword(dto.phone);
}

@Throttle({ default: { ttl: 60000, limit: 3 } })
@Post('reset-password')
@ApiOperation({ summary: 'Reset password using OTP code' })
async resetPassword(@Body() dto: ResetPasswordDto) {
  return this.authService.resetPassword(dto.phone, dto.code, dto.newPassword);
}
```

- [ ] **Step 3: Register OTP service and SMS provider in auth.module.ts**

Update `api/src/modules/auth/auth.module.ts`:

```typescript
import { OtpService } from './otp.service';
import { ConsoleSmsProvider } from './console-sms.provider';
import { SMS_PROVIDER } from './sms-provider.interface';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt-access' }),
    JwtModule.register({}),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    OtpService,
    { provide: SMS_PROVIDER, useClass: ConsoleSmsProvider },
    JwtAccessStrategy,
    JwtRefreshStrategy,
  ],
  exports: [AuthService],
})
export class AuthModule {}
```

- [ ] **Step 4: Verify backend builds**

```bash
cd /Users/latifrjdev/Downloads/Dukon/api
npm run build
```

Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add api/src/modules/auth/
git commit -m "feat: add OTP send/verify and password reset endpoints"
```

---

### Task 8: Wire OTP Flow in Flutter Frontend

**Files:**
- Modify: `app/lib/data/datasources/remote/auth_remote_datasource.dart`
- Modify: `app/lib/presentation/blocs/auth/auth_event.dart`
- Modify: `app/lib/presentation/blocs/auth/auth_state.dart`
- Modify: `app/lib/presentation/blocs/auth/auth_bloc.dart`

- [ ] **Step 1: Add OTP methods to AuthRemoteDatasource**

In `app/lib/data/datasources/remote/auth_remote_datasource.dart`, add to the abstract class:

```dart
// Add to abstract class AuthRemoteDatasource:
Future<void> sendOtp(String phone);
Future<({User user, String accessToken, String refreshToken})> verifyOtp(String phone, String code);
Future<void> forgotPassword(String phone);
Future<void> resetPassword(String phone, String code, String newPassword);
```

Add implementations to `AuthRemoteDatasourceImpl`:

```dart
@override
Future<void> sendOtp(String phone) async {
  try {
    await _dioClient.post(ApiEndpoints.sendOtp, data: {'phone': phone});
  } on DioException catch (e) {
    throw _handleDioError(e);
  }
}

@override
Future<({User user, String accessToken, String refreshToken})> verifyOtp(
    String phone, String code) async {
  try {
    final response = await _dioClient.post(
      ApiEndpoints.verifyOtp,
      data: {'phone': phone, 'code': code},
    );
    final data = response.data as Map<String, dynamic>;
    return (
      user: _mapUser(data['user'] as Map<String, dynamic>),
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  } on DioException catch (e) {
    throw _handleDioError(e);
  }
}

@override
Future<void> forgotPassword(String phone) async {
  try {
    await _dioClient.post(ApiEndpoints.forgotPassword, data: {'phone': phone});
  } on DioException catch (e) {
    throw _handleDioError(e);
  }
}

@override
Future<void> resetPassword(String phone, String code, String newPassword) async {
  try {
    await _dioClient.post(ApiEndpoints.resetPassword, data: {
      'phone': phone,
      'code': code,
      'newPassword': newPassword,
    });
  } on DioException catch (e) {
    throw _handleDioError(e);
  }
}
```

Also add the endpoint constants to `app/lib/core/constants/api_endpoints.dart`:

```dart
static const String sendOtp = '/auth/send-otp';
static const String verifyOtp = '/auth/verify-otp';
static const String forgotPassword = '/auth/forgot-password';
static const String resetPassword = '/auth/reset-password';
```

- [ ] **Step 2: Add new auth events**

In `app/lib/presentation/blocs/auth/auth_event.dart`, add:

```dart
class AuthSendOtpRequested extends AuthEvent {
  final String phone;
  const AuthSendOtpRequested({required this.phone});
  @override
  List<Object?> get props => [phone];
}

class AuthVerifyOtpRequested extends AuthEvent {
  final String phone;
  final String code;
  const AuthVerifyOtpRequested({required this.phone, required this.code});
  @override
  List<Object?> get props => [phone, code];
}

class AuthForgotPasswordRequested extends AuthEvent {
  final String phone;
  const AuthForgotPasswordRequested({required this.phone});
  @override
  List<Object?> get props => [phone];
}

class AuthResetPasswordRequested extends AuthEvent {
  final String phone;
  final String code;
  final String newPassword;
  const AuthResetPasswordRequested({
    required this.phone,
    required this.code,
    required this.newPassword,
  });
  @override
  List<Object?> get props => [phone, code, newPassword];
}
```

- [ ] **Step 3: Add new auth states**

In `app/lib/presentation/blocs/auth/auth_state.dart`, add:

```dart
class AuthOtpSent extends AuthState {
  final String phone;
  const AuthOtpSent({required this.phone});
  @override
  List<Object?> get props => [phone];
}

class AuthPasswordResetSuccess extends AuthState {}
```

- [ ] **Step 4: Add OTP event handlers to AuthBloc**

In `app/lib/presentation/blocs/auth/auth_bloc.dart`, register new handlers in constructor and add methods:

```dart
// In constructor, add:
on<AuthSendOtpRequested>(_onSendOtp);
on<AuthVerifyOtpRequested>(_onVerifyOtp);
on<AuthForgotPasswordRequested>(_onForgotPassword);
on<AuthResetPasswordRequested>(_onResetPassword);

// Add methods:
Future<void> _onSendOtp(AuthSendOtpRequested event, Emitter<AuthState> emit) async {
  emit(AuthLoading());
  try {
    await _authRepository.sendOtp(event.phone);
    emit(AuthOtpSent(phone: event.phone));
  } catch (e) {
    emit(AuthFailure(mapErrorToUserMessage(e)));
  }
}

Future<void> _onVerifyOtp(AuthVerifyOtpRequested event, Emitter<AuthState> emit) async {
  emit(AuthLoading());
  try {
    final result = await _authRepository.verifyOtp(event.phone, event.code);
    emit(AuthAuthenticated(result.user));
  } catch (e) {
    emit(AuthFailure(mapErrorToUserMessage(e)));
  }
}

Future<void> _onForgotPassword(AuthForgotPasswordRequested event, Emitter<AuthState> emit) async {
  emit(AuthLoading());
  try {
    await _authRepository.forgotPassword(event.phone);
    emit(AuthOtpSent(phone: event.phone));
  } catch (e) {
    emit(AuthFailure(mapErrorToUserMessage(e)));
  }
}

Future<void> _onResetPassword(AuthResetPasswordRequested event, Emitter<AuthState> emit) async {
  emit(AuthLoading());
  try {
    await _authRepository.resetPassword(event.phone, event.code, event.newPassword);
    emit(AuthPasswordResetSuccess());
  } catch (e) {
    emit(AuthFailure(mapErrorToUserMessage(e)));
  }
}
```

Note: You will also need to add `sendOtp`, `verifyOtp`, `forgotPassword`, `resetPassword` methods to the `AuthRepository` interface and its implementation, following the same pattern as the existing methods.

- [ ] **Step 5: Commit**

```bash
git add app/lib/data/datasources/remote/auth_remote_datasource.dart app/lib/presentation/blocs/auth/ app/lib/core/constants/api_endpoints.dart app/lib/domain/repositories/ app/lib/data/repositories/
git commit -m "feat: add OTP and password reset to Flutter auth layer"
```

---

### Task 9: Update OTP and Password Reset Pages

**Files:**
- Modify: `app/lib/presentation/pages/auth/otp_page.dart`
- Modify: `app/lib/presentation/pages/auth/forgot_password_page.dart`
- Modify: `app/lib/presentation/pages/auth/create_password_page.dart`

- [ ] **Step 1: Wire OTP page to BLoC**

In `app/lib/presentation/pages/auth/otp_page.dart`, replace the stub comments at lines 68 and 75 with actual BLoC calls:

```dart
// Replace line 68 area (OTP verification):
// OLD: // OTP verification — backend endpoint not yet available
// NEW:
context.read<AuthBloc>().add(
  AuthVerifyOtpRequested(phone: widget.phone, code: _otpController.text),
);

// Replace line 75 area (Resend OTP):
// OLD: // Resend OTP — backend endpoint not yet available
// NEW:
context.read<AuthBloc>().add(
  AuthSendOtpRequested(phone: widget.phone),
);
```

Add a `BlocListener` to handle state changes:

```dart
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthAuthenticated) {
      context.go(RouteNames.home);
    } else if (state is AuthFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message)),
      );
    }
  },
  // ... child
)
```

- [ ] **Step 2: Wire forgot password page**

In `app/lib/presentation/pages/auth/forgot_password_page.dart`, replace line 31:

```dart
// OLD: // Forgot password — backend endpoint not yet available
// NEW:
context.read<AuthBloc>().add(
  AuthForgotPasswordRequested(phone: _phoneController.text),
);
```

Add `BlocListener` to navigate to OTP page on success:

```dart
listener: (context, state) {
  if (state is AuthOtpSent) {
    context.push(RouteNames.otp, extra: state.phone);
  } else if (state is AuthFailure) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(state.message)),
    );
  }
},
```

- [ ] **Step 3: Wire create password page (for reset)**

In `app/lib/presentation/pages/auth/create_password_page.dart`, replace line 39:

```dart
// OLD: // Reset password — backend endpoint not yet available
// NEW:
context.read<AuthBloc>().add(
  AuthResetPasswordRequested(
    phone: widget.phone,
    code: widget.otpCode,
    newPassword: _passwordController.text,
  ),
);
```

- [ ] **Step 4: Verify full auth flow**

Test manually: Login → forgot password → enter phone → receive OTP (check server console logs) → enter code → set new password.

- [ ] **Step 5: Commit**

```bash
git add app/lib/presentation/pages/auth/
git commit -m "feat: wire OTP and password reset pages to auth BLoC"
```

---

## Sprint 2 — Finance Module

### Task 10: Add Investment Model to Prisma

**Files:**
- Modify: `api/prisma/schema.prisma`

- [ ] **Step 1: Add InvestmentStatus enum and Investment model**

In `api/prisma/schema.prisma`, add after the `OtpType` enum:

```prisma
enum InvestmentStatus {
  ACTIVE
  COMPLETED
  CANCELLED
}

model Investment {
  id            String           @id @default(uuid())
  storeId       String
  store         Store            @relation(fields: [storeId], references: [id], onDelete: Cascade)
  name          String
  description   String?
  amount        Decimal          @db.Decimal(12, 2)
  returnAmount  Decimal?         @db.Decimal(12, 2)
  investorName  String
  investorPhone String?
  status        InvestmentStatus @default(ACTIVE)
  startDate     DateTime
  endDate       DateTime?
  createdAt     DateTime         @default(now())
  updatedAt     DateTime         @updatedAt

  @@index([storeId])
  @@index([status])
  @@map("investments")
}
```

Add `investments Investment[]` to the Store model's relations list.

- [ ] **Step 2: Run migration**

```bash
cd /Users/latifrjdev/Downloads/Dukon/api
npx prisma migrate dev --name add_investments
```

- [ ] **Step 3: Commit**

```bash
git add api/prisma/schema.prisma api/prisma/migrations/
git commit -m "feat: add Investment model with status enum"
```

---

### Task 11: Create Investments Backend Module

**Files:**
- Create: `api/src/modules/investments/investments.module.ts`
- Create: `api/src/modules/investments/investments.service.ts`
- Create: `api/src/modules/investments/investments.controller.ts`
- Create: `api/src/modules/investments/dto/create-investment.dto.ts`
- Create: `api/src/modules/investments/dto/update-investment.dto.ts`
- Create: `api/src/modules/investments/dto/investment-query.dto.ts`
- Modify: `api/src/app.module.ts`

- [ ] **Step 1: Create DTOs**

Create `api/src/modules/investments/dto/create-investment.dto.ts`:

```typescript
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsNumber,
  IsOptional,
  IsEnum,
  IsDateString,
  MaxLength,
} from 'class-validator';
import { InvestmentStatus } from '@prisma/client';

export class CreateInvestmentDto {
  @ApiProperty({ example: 'Закупка оборудования' })
  @IsString()
  @MaxLength(255)
  name: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ example: 50000 })
  @IsNumber({ maxDecimalPlaces: 2 })
  amount: number;

  @ApiPropertyOptional({ example: 60000 })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  returnAmount?: number;

  @ApiProperty({ example: 'Иванов Иван' })
  @IsString()
  investorName: string;

  @ApiPropertyOptional({ example: '+992901234567' })
  @IsOptional()
  @IsString()
  investorPhone?: string;

  @ApiPropertyOptional({ enum: InvestmentStatus, default: 'ACTIVE' })
  @IsOptional()
  @IsEnum(InvestmentStatus)
  status?: InvestmentStatus;

  @ApiProperty({ example: '2026-04-16T00:00:00.000Z' })
  @IsDateString()
  startDate: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  endDate?: string;
}
```

Create `api/src/modules/investments/dto/update-investment.dto.ts`:

```typescript
import { PartialType } from '@nestjs/swagger';
import { CreateInvestmentDto } from './create-investment.dto';

export class UpdateInvestmentDto extends PartialType(CreateInvestmentDto) {}
```

Create `api/src/modules/investments/dto/investment-query.dto.ts`:

```typescript
import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsEnum, IsDateString, IsNumber } from 'class-validator';
import { Type } from 'class-transformer';
import { InvestmentStatus } from '@prisma/client';

export class InvestmentQueryDto {
  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  page?: number = 1;

  @ApiPropertyOptional({ default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  limit?: number = 20;

  @ApiPropertyOptional({ enum: InvestmentStatus })
  @IsOptional()
  @IsEnum(InvestmentStatus)
  status?: InvestmentStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  startDate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  endDate?: string;

  get skip(): number {
    return ((this.page || 1) - 1) * (this.limit || 20);
  }
}
```

- [ ] **Step 2: Create service**

Create `api/src/modules/investments/investments.service.ts`:

```typescript
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateInvestmentDto } from './dto/create-investment.dto';
import { UpdateInvestmentDto } from './dto/update-investment.dto';
import { InvestmentQueryDto } from './dto/investment-query.dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class InvestmentsService {
  constructor(private prisma: PrismaService) {}

  async create(storeId: string, dto: CreateInvestmentDto) {
    return this.prisma.investment.create({
      data: {
        storeId,
        name: dto.name,
        description: dto.description,
        amount: dto.amount,
        returnAmount: dto.returnAmount,
        investorName: dto.investorName,
        investorPhone: dto.investorPhone,
        status: dto.status || 'ACTIVE',
        startDate: new Date(dto.startDate),
        endDate: dto.endDate ? new Date(dto.endDate) : null,
      },
    });
  }

  async findAll(storeId: string, query: InvestmentQueryDto) {
    const where: Prisma.InvestmentWhereInput = {
      storeId,
      ...(query.status && { status: query.status }),
      ...(query.startDate && { startDate: { gte: new Date(query.startDate) } }),
      ...(query.endDate && { startDate: { lte: new Date(query.endDate) } }),
    };

    const [data, total] = await Promise.all([
      this.prisma.investment.findMany({
        where,
        skip: query.skip,
        take: query.limit || 20,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.investment.count({ where }),
    ]);

    return {
      data,
      total,
      page: query.page || 1,
      totalPages: Math.ceil(total / (query.limit || 20)),
    };
  }

  async findOne(storeId: string, id: string) {
    const investment = await this.prisma.investment.findFirst({
      where: { id, storeId },
    });
    if (!investment) throw new NotFoundException('Вложение не найдено');
    return investment;
  }

  async update(storeId: string, id: string, dto: UpdateInvestmentDto) {
    await this.findOne(storeId, id);
    return this.prisma.investment.update({
      where: { id },
      data: {
        ...dto,
        ...(dto.startDate && { startDate: new Date(dto.startDate) }),
        ...(dto.endDate && { endDate: new Date(dto.endDate) }),
      },
    });
  }

  async remove(storeId: string, id: string) {
    await this.findOne(storeId, id);
    return this.prisma.investment.delete({ where: { id } });
  }

  async summary(storeId: string) {
    const [all, active, completed] = await Promise.all([
      this.prisma.investment.aggregate({
        where: { storeId },
        _sum: { amount: true },
        _count: true,
      }),
      this.prisma.investment.aggregate({
        where: { storeId, status: 'ACTIVE' },
        _sum: { amount: true },
        _count: true,
      }),
      this.prisma.investment.aggregate({
        where: { storeId, status: 'COMPLETED' },
        _sum: { amount: true, returnAmount: true },
        _count: true,
      }),
    ]);

    return {
      totalAmount: all._sum.amount || 0,
      totalCount: all._count,
      activeAmount: active._sum.amount || 0,
      activeCount: active._count,
      completedAmount: completed._sum.amount || 0,
      completedReturnAmount: completed._sum.returnAmount || 0,
      completedCount: completed._count,
    };
  }
}
```

- [ ] **Step 3: Create controller**

Create `api/src/modules/investments/investments.controller.ts`:

```typescript
import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../stores/guards/store-access.guard';
import { InvestmentsService } from './investments.service';
import { CreateInvestmentDto } from './dto/create-investment.dto';
import { UpdateInvestmentDto } from './dto/update-investment.dto';
import { InvestmentQueryDto } from './dto/investment-query.dto';

@ApiTags('Investments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard)
@Controller('stores/:storeId/investments')
export class InvestmentsController {
  constructor(private readonly investmentsService: InvestmentsService) {}

  @Post()
  @ApiOperation({ summary: 'Create investment' })
  create(@Param('storeId') storeId: string, @Body() dto: CreateInvestmentDto) {
    return this.investmentsService.create(storeId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List investments' })
  findAll(@Param('storeId') storeId: string, @Query() query: InvestmentQueryDto) {
    return this.investmentsService.findAll(storeId, query);
  }

  @Get('summary')
  @ApiOperation({ summary: 'Get investment summary' })
  summary(@Param('storeId') storeId: string) {
    return this.investmentsService.summary(storeId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get investment by ID' })
  findOne(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.investmentsService.findOne(storeId, id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update investment' })
  update(
    @Param('storeId') storeId: string,
    @Param('id') id: string,
    @Body() dto: UpdateInvestmentDto,
  ) {
    return this.investmentsService.update(storeId, id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete investment' })
  remove(@Param('storeId') storeId: string, @Param('id') id: string) {
    return this.investmentsService.remove(storeId, id);
  }
}
```

- [ ] **Step 4: Create module and register in app**

Create `api/src/modules/investments/investments.module.ts`:

```typescript
import { Module } from '@nestjs/common';
import { InvestmentsController } from './investments.controller';
import { InvestmentsService } from './investments.service';

@Module({
  controllers: [InvestmentsController],
  providers: [InvestmentsService],
  exports: [InvestmentsService],
})
export class InvestmentsModule {}
```

In `api/src/app.module.ts`, add to imports:

```typescript
import { InvestmentsModule } from './modules/investments/investments.module';

// In @Module imports array, add:
InvestmentsModule,
```

- [ ] **Step 5: Verify backend builds**

```bash
cd /Users/latifrjdev/Downloads/Dukon/api
npm run build
```

- [ ] **Step 6: Commit**

```bash
git add api/src/modules/investments/ api/src/app.module.ts
git commit -m "feat: add investments CRUD module with summary endpoint"
```

---

### Task 12: Create Investment Flutter Entity, Repository, Datasource

**Files:**
- Create: `app/lib/domain/entities/investment.dart`
- Create: `app/lib/data/datasources/remote/investment_remote_datasource.dart`
- Create: `app/lib/domain/repositories/investment_repository.dart`
- Create: `app/lib/data/repositories/investment_repository_impl.dart`

- [ ] **Step 1: Create Investment entity**

Create `app/lib/domain/entities/investment.dart`:

```dart
import 'package:equatable/equatable.dart';

class Investment extends Equatable {
  final String id;
  final String storeId;
  final String name;
  final String? description;
  final double amount;
  final double? returnAmount;
  final String investorName;
  final String? investorPhone;
  final String status; // ACTIVE, COMPLETED, CANCELLED
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  const Investment({
    required this.id,
    required this.storeId,
    required this.name,
    this.description,
    required this.amount,
    this.returnAmount,
    required this.investorName,
    this.investorPhone,
    required this.status,
    required this.startDate,
    this.endDate,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, storeId, name, amount, status];
}

class InvestmentSummary extends Equatable {
  final double totalAmount;
  final int totalCount;
  final double activeAmount;
  final int activeCount;
  final double completedAmount;
  final double completedReturnAmount;
  final int completedCount;

  const InvestmentSummary({
    required this.totalAmount,
    required this.totalCount,
    required this.activeAmount,
    required this.activeCount,
    required this.completedAmount,
    required this.completedReturnAmount,
    required this.completedCount,
  });

  @override
  List<Object?> get props => [totalAmount, totalCount, activeCount];
}
```

- [ ] **Step 2: Create remote datasource**

Create `app/lib/data/datasources/remote/investment_remote_datasource.dart`:

```dart
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/investment.dart';

abstract class InvestmentRemoteDatasource {
  Future<({List<Investment> data, int total, int totalPages})> getInvestments(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<Investment> getInvestment(String storeId, String id);
  Future<Investment> createInvestment(String storeId, Map<String, dynamic> data);
  Future<Investment> updateInvestment(String storeId, String id, Map<String, dynamic> data);
  Future<void> deleteInvestment(String storeId, String id);
  Future<InvestmentSummary> getSummary(String storeId);
}

class InvestmentRemoteDatasourceImpl implements InvestmentRemoteDatasource {
  final DioClient _dioClient;

  InvestmentRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<({List<Investment> data, int total, int totalPages})> getInvestments(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _dioClient.get(
      '/stores/$storeId/investments',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (status != null) 'status': status,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );
    final responseData = response.data as Map<String, dynamic>;
    final list = responseData['data'] as List;
    return (
      data: list.map((j) => _mapInvestment(j as Map<String, dynamic>)).toList(),
      total: responseData['total'] as int? ?? 0,
      totalPages: responseData['totalPages'] as int? ?? 1,
    );
  }

  @override
  Future<Investment> getInvestment(String storeId, String id) async {
    final response = await _dioClient.get('/stores/$storeId/investments/$id');
    return _mapInvestment(response.data as Map<String, dynamic>);
  }

  @override
  Future<Investment> createInvestment(String storeId, Map<String, dynamic> data) async {
    final response = await _dioClient.post('/stores/$storeId/investments', data: data);
    return _mapInvestment(response.data as Map<String, dynamic>);
  }

  @override
  Future<Investment> updateInvestment(String storeId, String id, Map<String, dynamic> data) async {
    final response = await _dioClient.put('/stores/$storeId/investments/$id', data: data);
    return _mapInvestment(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteInvestment(String storeId, String id) async {
    await _dioClient.delete('/stores/$storeId/investments/$id');
  }

  @override
  Future<InvestmentSummary> getSummary(String storeId) async {
    final response = await _dioClient.get('/stores/$storeId/investments/summary');
    final d = response.data as Map<String, dynamic>;
    return InvestmentSummary(
      totalAmount: (d['totalAmount'] as num?)?.toDouble() ?? 0,
      totalCount: d['totalCount'] as int? ?? 0,
      activeAmount: (d['activeAmount'] as num?)?.toDouble() ?? 0,
      activeCount: d['activeCount'] as int? ?? 0,
      completedAmount: (d['completedAmount'] as num?)?.toDouble() ?? 0,
      completedReturnAmount: (d['completedReturnAmount'] as num?)?.toDouble() ?? 0,
      completedCount: d['completedCount'] as int? ?? 0,
    );
  }

  Investment _mapInvestment(Map<String, dynamic> json) {
    return Investment(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      amount: (json['amount'] as num).toDouble(),
      returnAmount: (json['returnAmount'] as num?)?.toDouble(),
      investorName: json['investorName'] as String,
      investorPhone: json['investorPhone'] as String?,
      status: json['status'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
```

- [ ] **Step 3: Create repository interface and implementation**

Create `app/lib/domain/repositories/investment_repository.dart`:

```dart
import '../entities/investment.dart';

abstract class InvestmentRepository {
  Future<({List<Investment> data, int total, int totalPages})> getInvestments(
    String storeId, {
    int page,
    int limit,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<Investment> getInvestment(String storeId, String id);
  Future<Investment> createInvestment(String storeId, Map<String, dynamic> data);
  Future<Investment> updateInvestment(String storeId, String id, Map<String, dynamic> data);
  Future<void> deleteInvestment(String storeId, String id);
  Future<InvestmentSummary> getSummary(String storeId);
}
```

Create `app/lib/data/repositories/investment_repository_impl.dart`:

```dart
import '../../domain/entities/investment.dart';
import '../../domain/repositories/investment_repository.dart';
import '../datasources/remote/investment_remote_datasource.dart';

class InvestmentRepositoryImpl implements InvestmentRepository {
  final InvestmentRemoteDatasource _remoteDatasource;

  InvestmentRepositoryImpl({required InvestmentRemoteDatasource remoteDatasource})
      : _remoteDatasource = remoteDatasource;

  @override
  Future<({List<Investment> data, int total, int totalPages})> getInvestments(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _remoteDatasource.getInvestments(storeId,
          page: page, limit: limit, status: status, startDate: startDate, endDate: endDate);

  @override
  Future<Investment> getInvestment(String storeId, String id) =>
      _remoteDatasource.getInvestment(storeId, id);

  @override
  Future<Investment> createInvestment(String storeId, Map<String, dynamic> data) =>
      _remoteDatasource.createInvestment(storeId, data);

  @override
  Future<Investment> updateInvestment(String storeId, String id, Map<String, dynamic> data) =>
      _remoteDatasource.updateInvestment(storeId, id, data);

  @override
  Future<void> deleteInvestment(String storeId, String id) =>
      _remoteDatasource.deleteInvestment(storeId, id);

  @override
  Future<InvestmentSummary> getSummary(String storeId) =>
      _remoteDatasource.getSummary(storeId);
}
```

- [ ] **Step 4: Commit**

```bash
git add app/lib/domain/entities/investment.dart app/lib/data/datasources/remote/investment_remote_datasource.dart app/lib/domain/repositories/investment_repository.dart app/lib/data/repositories/investment_repository_impl.dart
git commit -m "feat: add investment entity, datasource, and repository"
```

---

### Task 13: Create Investment BLoC

**Files:**
- Create: `app/lib/presentation/blocs/investment/investment_event.dart`
- Create: `app/lib/presentation/blocs/investment/investment_state.dart`
- Create: `app/lib/presentation/blocs/investment/investment_bloc.dart`

- [ ] **Step 1: Create events**

Create `app/lib/presentation/blocs/investment/investment_event.dart`:

```dart
import 'package:equatable/equatable.dart';

abstract class InvestmentEvent extends Equatable {
  const InvestmentEvent();
  @override
  List<Object?> get props => [];
}

class InvestmentListRequested extends InvestmentEvent {
  final String storeId;
  final int page;
  final String? status;
  const InvestmentListRequested({required this.storeId, this.page = 1, this.status});
  @override
  List<Object?> get props => [storeId, page, status];
}

class InvestmentSummaryRequested extends InvestmentEvent {
  final String storeId;
  const InvestmentSummaryRequested({required this.storeId});
  @override
  List<Object?> get props => [storeId];
}

class InvestmentCreateRequested extends InvestmentEvent {
  final String storeId;
  final Map<String, dynamic> data;
  const InvestmentCreateRequested({required this.storeId, required this.data});
  @override
  List<Object?> get props => [storeId, data];
}

class InvestmentUpdateRequested extends InvestmentEvent {
  final String storeId;
  final String id;
  final Map<String, dynamic> data;
  const InvestmentUpdateRequested({required this.storeId, required this.id, required this.data});
  @override
  List<Object?> get props => [storeId, id, data];
}

class InvestmentDeleteRequested extends InvestmentEvent {
  final String storeId;
  final String id;
  const InvestmentDeleteRequested({required this.storeId, required this.id});
  @override
  List<Object?> get props => [storeId, id];
}
```

- [ ] **Step 2: Create states**

Create `app/lib/presentation/blocs/investment/investment_state.dart`:

```dart
import 'package:equatable/equatable.dart';
import '../../../domain/entities/investment.dart';

abstract class InvestmentState extends Equatable {
  const InvestmentState();
  @override
  List<Object?> get props => [];
}

class InvestmentInitial extends InvestmentState {}

class InvestmentLoading extends InvestmentState {}

class InvestmentLoaded extends InvestmentState {
  final List<Investment> investments;
  final int total;
  final int totalPages;
  final int currentPage;
  final String? selectedStatus;

  const InvestmentLoaded({
    required this.investments,
    required this.total,
    required this.totalPages,
    required this.currentPage,
    this.selectedStatus,
  });

  @override
  List<Object?> get props => [investments, total, currentPage, selectedStatus];
}

class InvestmentSummaryLoaded extends InvestmentState {
  final InvestmentSummary summary;
  const InvestmentSummaryLoaded({required this.summary});
  @override
  List<Object?> get props => [summary];
}

class InvestmentActionSuccess extends InvestmentState {
  final String message;
  const InvestmentActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class InvestmentError extends InvestmentState {
  final String message;
  const InvestmentError(this.message);
  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 3: Create BLoC**

Create `app/lib/presentation/blocs/investment/investment_bloc.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../domain/repositories/investment_repository.dart';
import 'investment_event.dart';
import 'investment_state.dart';

class InvestmentBloc extends Bloc<InvestmentEvent, InvestmentState> {
  final InvestmentRepository _investmentRepository;

  InvestmentBloc({required InvestmentRepository investmentRepository})
      : _investmentRepository = investmentRepository,
        super(InvestmentInitial()) {
    on<InvestmentListRequested>(_onListRequested);
    on<InvestmentSummaryRequested>(_onSummaryRequested);
    on<InvestmentCreateRequested>(_onCreateRequested);
    on<InvestmentUpdateRequested>(_onUpdateRequested);
    on<InvestmentDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onListRequested(
      InvestmentListRequested event, Emitter<InvestmentState> emit) async {
    emit(InvestmentLoading());
    try {
      final result = await _investmentRepository.getInvestments(
        event.storeId,
        page: event.page,
        status: event.status,
      );
      emit(InvestmentLoaded(
        investments: result.data,
        total: result.total,
        totalPages: result.totalPages,
        currentPage: event.page,
        selectedStatus: event.status,
      ));
    } catch (e) {
      emit(InvestmentError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onSummaryRequested(
      InvestmentSummaryRequested event, Emitter<InvestmentState> emit) async {
    try {
      final summary = await _investmentRepository.getSummary(event.storeId);
      emit(InvestmentSummaryLoaded(summary: summary));
    } catch (e) {
      emit(InvestmentError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onCreateRequested(
      InvestmentCreateRequested event, Emitter<InvestmentState> emit) async {
    emit(InvestmentLoading());
    try {
      await _investmentRepository.createInvestment(event.storeId, event.data);
      emit(const InvestmentActionSuccess('Вложение добавлено'));
      add(InvestmentListRequested(storeId: event.storeId));
    } catch (e) {
      emit(InvestmentError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onUpdateRequested(
      InvestmentUpdateRequested event, Emitter<InvestmentState> emit) async {
    emit(InvestmentLoading());
    try {
      await _investmentRepository.updateInvestment(event.storeId, event.id, event.data);
      emit(const InvestmentActionSuccess('Вложение обновлено'));
      add(InvestmentListRequested(storeId: event.storeId));
    } catch (e) {
      emit(InvestmentError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onDeleteRequested(
      InvestmentDeleteRequested event, Emitter<InvestmentState> emit) async {
    emit(InvestmentLoading());
    try {
      await _investmentRepository.deleteInvestment(event.storeId, event.id);
      emit(const InvestmentActionSuccess('Вложение удалено'));
      add(InvestmentListRequested(storeId: event.storeId));
    } catch (e) {
      emit(InvestmentError(mapErrorToUserMessage(e)));
    }
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add app/lib/presentation/blocs/investment/
git commit -m "feat: add investment BLoC with CRUD and summary"
```

---

### Task 14: Register Investment DI, Routes, Remove Stub

**Files:**
- Modify: `app/lib/injection.dart`
- Modify: `app/lib/core/router/app_router.dart`
- Modify: `app/lib/core/router/route_names.dart`
- Modify: `app/lib/presentation/pages/finance/finance_dashboard_page.dart`

- [ ] **Step 1: Add route names**

In `app/lib/core/router/route_names.dart`, add:

```dart
static const String investments = '/investments';
static const String addInvestment = '/investments/add';
```

- [ ] **Step 2: Register DI in injection.dart**

In `app/lib/injection.dart`, add (follow existing datasource → repository → bloc pattern):

```dart
// Datasource
sl.registerLazySingleton<InvestmentRemoteDatasource>(
  () => InvestmentRemoteDatasourceImpl(dioClient: sl<DioClient>()),
);

// Repository
sl.registerLazySingleton<InvestmentRepository>(
  () => InvestmentRepositoryImpl(remoteDatasource: sl<InvestmentRemoteDatasource>()),
);

// BLoC
sl.registerFactory<InvestmentBloc>(
  () => InvestmentBloc(investmentRepository: sl<InvestmentRepository>()),
);
```

Add the necessary imports at the top of `injection.dart`.

- [ ] **Step 3: Add routes in app_router.dart**

In `app/lib/core/router/app_router.dart`, add routes (before any dynamic `:id` routes):

```dart
// Investments
GoRoute(
  path: RouteNames.investments,
  builder: (context, state) {
    final storeId = state.extra as String? ?? '';
    return InvestmentListPage(storeId: storeId);
  },
),
GoRoute(
  path: RouteNames.addInvestment,
  builder: (context, state) {
    final storeId = state.extra as String? ?? '';
    return AddInvestmentPage(storeId: storeId);
  },
),
```

Add imports for `InvestmentListPage` and `AddInvestmentPage`.

- [ ] **Step 4: Remove stub from finance_dashboard_page.dart**

In `app/lib/presentation/pages/finance/finance_dashboard_page.dart`, replace the Investments tile (line ~363):

```dart
// OLD:
_SectionItem('Вложения', Icons.trending_up_outlined,
    () => comingSoon('Вложения'), stub: true),

// NEW:
_SectionItem('Вложения', Icons.trending_up_outlined,
    () => context.push(RouteNames.investments, extra: storeId)),
```

- [ ] **Step 5: Commit**

```bash
git add app/lib/injection.dart app/lib/core/router/app_router.dart app/lib/core/router/route_names.dart app/lib/presentation/pages/finance/finance_dashboard_page.dart
git commit -m "feat: register investment DI, routes, remove coming soon stub"
```

---

### Task 15: Create Investment UI Pages

**Files:**
- Create: `app/lib/presentation/pages/finance/investment_list_page.dart`
- Create: `app/lib/presentation/pages/finance/add_investment_page.dart`

- [ ] **Step 1: Create InvestmentListPage**

Create `app/lib/presentation/pages/finance/investment_list_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../../../domain/entities/investment.dart';
import '../../../injection.dart';
import '../../blocs/investment/investment_bloc.dart';
import '../../blocs/investment/investment_event.dart';
import '../../blocs/investment/investment_state.dart';

class InvestmentListPage extends StatelessWidget {
  final String storeId;
  const InvestmentListPage({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<InvestmentBloc>()
        ..add(InvestmentListRequested(storeId: storeId)),
      child: _InvestmentListView(storeId: storeId),
    );
  }
}

class _InvestmentListView extends StatelessWidget {
  final String storeId;
  const _InvestmentListView({required this.storeId});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'ru');

    return Scaffold(
      appBar: AppBar(title: const Text('Вложения')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push(RouteNames.addInvestment, extra: storeId);
          if (result == true && context.mounted) {
            context.read<InvestmentBloc>().add(InvestmentListRequested(storeId: storeId));
          }
        },
        child: const Icon(Icons.add),
      ),
      body: BlocConsumer<InvestmentBloc, InvestmentState>(
        listener: (context, state) {
          if (state is InvestmentActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            context.read<InvestmentBloc>().add(InvestmentListRequested(storeId: storeId));
          } else if (state is InvestmentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is InvestmentLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is InvestmentLoaded) {
            if (state.investments.isEmpty) {
              return const Center(child: Text('Нет вложений'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.investments.length,
              itemBuilder: (context, index) {
                final inv = state.investments[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(inv.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${inv.investorName} • ${DateFormat('dd.MM.yyyy').format(inv.startDate)}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${currencyFormat.format(inv.amount)} TJS',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        _StatusChip(status: inv.status),
                      ],
                    ),
                    onTap: () {
                      // Future: navigate to detail page
                    },
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'ACTIVE' => ('Активно', AppColors.success),
      'COMPLETED' => ('Завершено', AppColors.info),
      'CANCELLED' => ('Отменено', AppColors.error),
      _ => (status, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}
```

- [ ] **Step 2: Create AddInvestmentPage**

Create `app/lib/presentation/pages/finance/add_investment_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../injection.dart';
import '../../blocs/investment/investment_bloc.dart';
import '../../blocs/investment/investment_event.dart';
import '../../blocs/investment/investment_state.dart';

class AddInvestmentPage extends StatelessWidget {
  final String storeId;
  const AddInvestmentPage({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<InvestmentBloc>(),
      child: _AddInvestmentForm(storeId: storeId),
    );
  }
}

class _AddInvestmentForm extends StatefulWidget {
  final String storeId;
  const _AddInvestmentForm({required this.storeId});

  @override
  State<_AddInvestmentForm> createState() => _AddInvestmentFormState();
}

class _AddInvestmentFormState extends State<_AddInvestmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _returnAmountController = TextEditingController();
  final _investorNameController = TextEditingController();
  final _investorPhoneController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _returnAmountController.dispose();
    _investorNameController.dispose();
    _investorPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InvestmentBloc, InvestmentState>(
      listener: (context, state) {
        if (state is InvestmentActionSuccess) {
          context.pop(true);
        } else if (state is InvestmentError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Новое вложение')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Название *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Обязательное поле' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Сумма вложения *', suffixText: 'TJS'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'Обязательное поле' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _returnAmountController,
                decoration: const InputDecoration(labelText: 'Сумма возврата', suffixText: 'TJS'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _investorNameController,
                decoration: const InputDecoration(labelText: 'Имя инвестора *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Обязательное поле' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _investorPhoneController,
                decoration: const InputDecoration(labelText: 'Телефон инвестора', prefixText: '+992 '),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Дата начала'),
                trailing: Text(DateFormat('dd.MM.yyyy').format(_startDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
              ListTile(
                title: const Text('Дата окончания'),
                trailing: Text(_endDate != null
                    ? DateFormat('dd.MM.yyyy').format(_endDate!)
                    : 'Не указана'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? _startDate,
                    firstDate: _startDate,
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _endDate = picked);
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final phone = _investorPhoneController.text.trim();
    context.read<InvestmentBloc>().add(InvestmentCreateRequested(
      storeId: widget.storeId,
      data: {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'amount': double.parse(_amountController.text.trim()),
        if (_returnAmountController.text.trim().isNotEmpty)
          'returnAmount': double.parse(_returnAmountController.text.trim()),
        'investorName': _investorNameController.text.trim(),
        if (phone.isNotEmpty) 'investorPhone': '+992$phone',
        'startDate': _startDate.toIso8601String(),
        if (_endDate != null) 'endDate': _endDate!.toIso8601String(),
      },
    ));
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add app/lib/presentation/pages/finance/investment_list_page.dart app/lib/presentation/pages/finance/add_investment_page.dart
git commit -m "feat: add investment list and add investment pages"
```

---

### Task 16: Wire Currency Page to Backend

**Files:**
- Create: `app/lib/data/datasources/remote/currency_remote_datasource.dart`
- Modify: `app/lib/presentation/pages/finance/currencies_page.dart`

- [ ] **Step 1: Create currency remote datasource**

Create `app/lib/data/datasources/remote/currency_remote_datasource.dart`:

```dart
import '../../../core/network/dio_client.dart';

class CurrencyRate {
  final String code;
  final double rate;
  final String flag;
  final String label;

  const CurrencyRate({
    required this.code,
    required this.rate,
    required this.flag,
    required this.label,
  });
}

class CurrencyRateHistory {
  final String code;
  final List<({DateTime date, double rate})> history;

  const CurrencyRateHistory({required this.code, required this.history});
}

abstract class CurrencyRemoteDatasource {
  Future<List<CurrencyRate>> getLatestRates();
  Future<CurrencyRateHistory> getRateHistory(String code);
}

class CurrencyRemoteDatasourceImpl implements CurrencyRemoteDatasource {
  final DioClient _dioClient;

  CurrencyRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  static const _flags = {'USD': '\u{1F1FA}\u{1F1F8}', 'RUB': '\u{1F1F7}\u{1F1FA}', 'EUR': '\u{1F1EA}\u{1F1FA}', 'CNY': '\u{1F1E8}\u{1F1F3}'};
  static const _labels = {'USD': 'Доллар США', 'RUB': 'Российский рубль', 'EUR': 'Евро', 'CNY': 'Китайский юань'};

  @override
  Future<List<CurrencyRate>> getLatestRates() async {
    final response = await _dioClient.get('/currencies/latest-rates');
    final data = response.data as Map<String, dynamic>;
    final rates = data['rates'] as Map<String, dynamic>;
    return rates.entries.map((e) => CurrencyRate(
      code: e.key,
      rate: (e.value as num).toDouble(),
      flag: _flags[e.key] ?? '',
      label: _labels[e.key] ?? e.key,
    )).toList();
  }

  @override
  Future<CurrencyRateHistory> getRateHistory(String code) async {
    final response = await _dioClient.get('/currencies/rate-history', queryParameters: {'code': code});
    final data = response.data as Map<String, dynamic>;
    final history = (data['history'] as List).map((item) {
      final m = item as Map<String, dynamic>;
      return (date: DateTime.parse(m['date'] as String), rate: (m['rate'] as num).toDouble());
    }).toList();
    return CurrencyRateHistory(code: code, history: history);
  }
}
```

- [ ] **Step 2: Update currencies_page.dart to use remote datasource**

In `app/lib/presentation/pages/finance/currencies_page.dart`, replace the local `_CurrencyRate` model and hardcoded data fetching with the new `CurrencyRemoteDatasource`. The page already imports `dio_client.dart` and `injection.dart`, so:

1. Replace the local `_CurrencyRate` class with an import of the new datasource
2. In the `_loadRates()` method (or equivalent init), call `sl<CurrencyRemoteDatasource>().getLatestRates()`
3. In the chart data loading, call `sl<CurrencyRemoteDatasource>().getRateHistory(code)`
4. Keep all existing UI (charts, flags, layout) — only change data source

Register in `injection.dart`:

```dart
sl.registerLazySingleton<CurrencyRemoteDatasource>(
  () => CurrencyRemoteDatasourceImpl(dioClient: sl<DioClient>()),
);
```

- [ ] **Step 3: Commit**

```bash
git add app/lib/data/datasources/remote/currency_remote_datasource.dart app/lib/presentation/pages/finance/currencies_page.dart app/lib/injection.dart
git commit -m "feat: connect currencies page to backend API"
```

---

### Task 17: Wire Notification Toggle in Settings

**Files:**
- Modify: `app/lib/presentation/pages/settings/settings_page.dart`

- [ ] **Step 1: Wire notification toggle to API**

In `app/lib/presentation/pages/settings/settings_page.dart`, update the notification toggle handler (around line 241):

```dart
// OLD:
_buildToggleTile(Icons.notifications_outlined, 'Уведомления',
  value: _notificationsEnabled,
  onChanged: (v) => setState(() => _notificationsEnabled = v)),

// NEW:
_buildToggleTile(Icons.notifications_outlined, 'Уведомления',
  value: _notificationsEnabled,
  onChanged: (v) async {
    setState(() => _notificationsEnabled = v);
    try {
      await sl<DioClient>().put(
        '/stores/${_storeId}/notification-settings',
        data: {'enabled': v},
      );
    } catch (e) {
      setState(() => _notificationsEnabled = !v);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить настройку')),
        );
      }
    }
  }),
```

Ensure `DioClient` and `injection.dart` are imported.

- [ ] **Step 2: Commit**

```bash
git add app/lib/presentation/pages/settings/settings_page.dart
git commit -m "fix: wire notification toggle to backend API"
```

---

## Sprint 3 — Excel Product Import

### Task 18: Create Backend Import Service and Endpoints

**Files:**
- Create: `api/src/modules/products/import-products.service.ts`
- Create: `api/src/modules/products/templates/product-import-template.ts`
- Modify: `api/src/modules/products/products.controller.ts`
- Modify: `api/src/modules/products/products.module.ts`

- [ ] **Step 1: Add exceljs dependency**

```bash
cd /Users/latifrjdev/Downloads/Dukon/api
npm install exceljs multer @types/multer
```

- [ ] **Step 2: Create template generator**

Create `api/src/modules/products/templates/product-import-template.ts`:

```typescript
import * as ExcelJS from 'exceljs';

export async function generateImportTemplate(): Promise<Buffer> {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Товары');

  sheet.columns = [
    { header: 'Название *', key: 'name', width: 30 },
    { header: 'Штрихкод', key: 'barcode', width: 20 },
    { header: 'Категория', key: 'category', width: 20 },
    { header: 'Цена закупки', key: 'purchasePrice', width: 15 },
    { header: 'Цена продажи *', key: 'salePrice', width: 15 },
    { header: 'Количество', key: 'quantity', width: 12 },
    { header: 'Единица', key: 'unit', width: 12 },
    { header: 'Описание', key: 'description', width: 40 },
  ];

  // Style header row
  sheet.getRow(1).font = { bold: true };
  sheet.getRow(1).fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FFE8EAF6' },
  };

  // Add example row
  sheet.addRow({
    name: 'Пример товара',
    barcode: '4901234567890',
    category: 'Одежда',
    purchasePrice: 100,
    salePrice: 150,
    quantity: 10,
    unit: 'шт',
    description: 'Описание товара',
  });

  const buffer = await workbook.xlsx.writeBuffer();
  return Buffer.from(buffer);
}
```

- [ ] **Step 3: Create import service**

Create `api/src/modules/products/import-products.service.ts`:

```typescript
import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import * as ExcelJS from 'exceljs';

interface ImportRow {
  row: number;
  name: string;
  barcode?: string;
  category?: string;
  purchasePrice?: number;
  salePrice: number;
  quantity?: number;
  unit?: string;
  description?: string;
}

interface ImportError {
  row: number;
  field: string;
  message: string;
}

interface ImportResult {
  created: number;
  skipped: number;
  errors: ImportError[];
}

@Injectable()
export class ImportProductsService {
  constructor(private prisma: PrismaService) {}

  async parseFile(buffer: Buffer): Promise<{ rows: ImportRow[]; errors: ImportError[] }> {
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(buffer);
    const sheet = workbook.worksheets[0];

    if (!sheet) {
      throw new BadRequestException('Файл не содержит листов');
    }

    const rows: ImportRow[] = [];
    const errors: ImportError[] = [];

    sheet.eachRow((row, rowNumber) => {
      if (rowNumber === 1) return; // Skip header

      const name = row.getCell(1).text?.trim();
      const salePrice = Number(row.getCell(5).value);

      if (!name) {
        errors.push({ row: rowNumber, field: 'name', message: 'Название обязательно' });
        return;
      }
      if (!salePrice || isNaN(salePrice)) {
        errors.push({ row: rowNumber, field: 'salePrice', message: 'Цена продажи обязательна' });
        return;
      }

      rows.push({
        row: rowNumber,
        name,
        barcode: row.getCell(2).text?.trim() || undefined,
        category: row.getCell(3).text?.trim() || undefined,
        purchasePrice: Number(row.getCell(4).value) || undefined,
        salePrice,
        quantity: Number(row.getCell(6).value) || undefined,
        unit: row.getCell(7).text?.trim() || undefined,
        description: row.getCell(8).text?.trim() || undefined,
      });
    });

    return { rows, errors };
  }

  async preview(buffer: Buffer) {
    const { rows, errors } = await this.parseFile(buffer);
    return {
      rows: rows.slice(0, 20),
      totalRows: rows.length,
      errors,
    };
  }

  async importProducts(storeId: string, buffer: Buffer): Promise<ImportResult> {
    const { rows, errors } = await this.parseFile(buffer);

    if (rows.length === 0) {
      throw new BadRequestException('Файл не содержит данных для импорта');
    }
    if (rows.length > 1000) {
      throw new BadRequestException('Максимум 1000 товаров за один импорт');
    }

    let created = 0;
    let skipped = 0;

    // Resolve categories by name
    const categoryNames = [...new Set(rows.filter((r) => r.category).map((r) => r.category!))];
    const categoryMap = new Map<string, string>();

    for (const name of categoryNames) {
      let category = await this.prisma.category.findFirst({
        where: { storeId, name: { equals: name, mode: 'insensitive' } },
      });
      if (!category) {
        category = await this.prisma.category.create({
          data: { storeId, name },
        });
      }
      categoryMap.set(name, category.id);
    }

    // Import in transaction
    await this.prisma.$transaction(async (tx) => {
      for (const row of rows) {
        // Check barcode uniqueness
        if (row.barcode) {
          const existing = await tx.product.findFirst({
            where: { storeId, barcode: row.barcode },
          });
          if (existing) {
            errors.push({ row: row.row, field: 'barcode', message: `Штрихкод ${row.barcode} уже существует` });
            skipped++;
            continue;
          }
        }

        await tx.product.create({
          data: {
            storeId,
            name: row.name,
            barcode: row.barcode,
            categoryId: row.category ? categoryMap.get(row.category) : null,
            purchasePrice: row.purchasePrice,
            salePrice: row.salePrice,
            quantity: row.quantity || 0,
            unit: row.unit || 'шт',
            description: row.description,
          },
        });
        created++;
      }
    });

    return { created, skipped, errors };
  }
}
```

- [ ] **Step 4: Add endpoints to products controller**

In `api/src/modules/products/products.controller.ts`, add imports and endpoints:

```typescript
import { FileInterceptor } from '@nestjs/platform-express';
import { UploadedFile, UseInterceptors, Res } from '@nestjs/common';
import { Response } from 'express';
import { ImportProductsService } from './import-products.service';
import { generateImportTemplate } from './templates/product-import-template';

// Add ImportProductsService to constructor:
// constructor(
//   private readonly productsService: ProductsService,
//   private readonly importService: ImportProductsService,  // <-- ADD
// ) {}

@Get('import/template')
@ApiOperation({ summary: 'Download import template' })
async downloadTemplate(@Res() res: Response) {
  const buffer = await generateImportTemplate();
  res.set({
    'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'Content-Disposition': 'attachment; filename="dukon-import-template.xlsx"',
  });
  res.send(buffer);
}

@Post('import/preview')
@UseInterceptors(FileInterceptor('file'))
@ApiOperation({ summary: 'Preview import file' })
async previewImport(@UploadedFile() file: Express.Multer.File) {
  if (!file) throw new BadRequestException('Файл не загружен');
  return this.importService.preview(file.buffer);
}

@Post('import')
@UseInterceptors(FileInterceptor('file'))
@ApiOperation({ summary: 'Import products from file' })
async importProducts(
  @Param('storeId') storeId: string,
  @UploadedFile() file: Express.Multer.File,
) {
  if (!file) throw new BadRequestException('Файл не загружен');
  return this.importService.importProducts(storeId, file.buffer);
}
```

- [ ] **Step 5: Register service in module**

In `api/src/modules/products/products.module.ts`, add `ImportProductsService` to providers:

```typescript
import { ImportProductsService } from './import-products.service';

@Module({
  controllers: [ProductsController],
  providers: [ProductsService, ImportProductsService],
  exports: [ProductsService],
})
```

- [ ] **Step 6: Verify backend builds**

```bash
cd /Users/latifrjdev/Downloads/Dukon/api
npm run build
```

- [ ] **Step 7: Commit**

```bash
git add api/src/modules/products/ api/package.json api/package-lock.json
git commit -m "feat: add Excel/CSV product import with template and preview"
```

---

### Task 19: Create Import BLoC and Wire Frontend

**Files:**
- Create: `app/lib/presentation/blocs/import/import_event.dart`
- Create: `app/lib/presentation/blocs/import/import_state.dart`
- Create: `app/lib/presentation/blocs/import/import_bloc.dart`
- Modify: `app/lib/data/datasources/remote/product_remote_datasource.dart`
- Modify: `app/lib/injection.dart`

- [ ] **Step 1: Add import methods to product remote datasource**

In `app/lib/data/datasources/remote/product_remote_datasource.dart`, add to the abstract class and implementation:

```dart
// Abstract class additions:
Future<String> downloadTemplatePath(String storeId);
Future<Map<String, dynamic>> importPreview(String storeId, String filePath);
Future<Map<String, dynamic>> importProducts(String storeId, String filePath);
```

Implementation:

```dart
@override
Future<String> downloadTemplatePath(String storeId) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/dukon-import-template.xlsx';
  await _dioClient.download('/stores/$storeId/products/import/template', path);
  return path;
}

@override
Future<Map<String, dynamic>> importPreview(String storeId, String filePath) async {
  final formData = FormData.fromMap({
    'file': await MultipartFile.fromFile(filePath),
  });
  final response = await _dioClient.post(
    '/stores/$storeId/products/import/preview',
    data: formData,
  );
  return response.data as Map<String, dynamic>;
}

@override
Future<Map<String, dynamic>> importProducts(String storeId, String filePath) async {
  final formData = FormData.fromMap({
    'file': await MultipartFile.fromFile(filePath),
  });
  final response = await _dioClient.post(
    '/stores/$storeId/products/import',
    data: formData,
  );
  return response.data as Map<String, dynamic>;
}
```

Add necessary imports: `import 'package:dio/dio.dart';` and `import 'package:path_provider/path_provider.dart';`

- [ ] **Step 2: Create import events**

Create `app/lib/presentation/blocs/import/import_event.dart`:

```dart
import 'package:equatable/equatable.dart';

abstract class ImportEvent extends Equatable {
  const ImportEvent();
  @override
  List<Object?> get props => [];
}

class ImportFileSelected extends ImportEvent {
  final String storeId;
  final String filePath;
  const ImportFileSelected({required this.storeId, required this.filePath});
  @override
  List<Object?> get props => [storeId, filePath];
}

class ImportConfirmed extends ImportEvent {
  final String storeId;
  final String filePath;
  const ImportConfirmed({required this.storeId, required this.filePath});
  @override
  List<Object?> get props => [storeId, filePath];
}

class ImportTemplateRequested extends ImportEvent {
  final String storeId;
  const ImportTemplateRequested({required this.storeId});
  @override
  List<Object?> get props => [storeId];
}
```

- [ ] **Step 3: Create import states**

Create `app/lib/presentation/blocs/import/import_state.dart`:

```dart
import 'package:equatable/equatable.dart';

abstract class ImportState extends Equatable {
  const ImportState();
  @override
  List<Object?> get props => [];
}

class ImportInitial extends ImportState {}

class ImportLoading extends ImportState {}

class ImportPreviewLoaded extends ImportState {
  final List<dynamic> rows;
  final int totalRows;
  final List<dynamic> errors;
  final String filePath;

  const ImportPreviewLoaded({
    required this.rows,
    required this.totalRows,
    required this.errors,
    required this.filePath,
  });

  @override
  List<Object?> get props => [totalRows, filePath];
}

class ImportSuccess extends ImportState {
  final int created;
  final int skipped;
  final List<dynamic> errors;

  const ImportSuccess({
    required this.created,
    required this.skipped,
    required this.errors,
  });

  @override
  List<Object?> get props => [created, skipped];
}

class ImportTemplateDownloaded extends ImportState {
  final String filePath;
  const ImportTemplateDownloaded({required this.filePath});
  @override
  List<Object?> get props => [filePath];
}

class ImportError extends ImportState {
  final String message;
  const ImportError(this.message);
  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 4: Create import BLoC**

Create `app/lib/presentation/blocs/import/import_bloc.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../data/datasources/remote/product_remote_datasource.dart';
import 'import_event.dart';
import 'import_state.dart';

class ImportBloc extends Bloc<ImportEvent, ImportState> {
  final ProductRemoteDatasource _productDatasource;

  ImportBloc({required ProductRemoteDatasource productDatasource})
      : _productDatasource = productDatasource,
        super(ImportInitial()) {
    on<ImportFileSelected>(_onFileSelected);
    on<ImportConfirmed>(_onConfirmed);
    on<ImportTemplateRequested>(_onTemplateRequested);
  }

  Future<void> _onFileSelected(ImportFileSelected event, Emitter<ImportState> emit) async {
    emit(ImportLoading());
    try {
      final result = await _productDatasource.importPreview(event.storeId, event.filePath);
      emit(ImportPreviewLoaded(
        rows: result['rows'] as List<dynamic>,
        totalRows: result['totalRows'] as int,
        errors: result['errors'] as List<dynamic>,
        filePath: event.filePath,
      ));
    } catch (e) {
      emit(ImportError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onConfirmed(ImportConfirmed event, Emitter<ImportState> emit) async {
    emit(ImportLoading());
    try {
      final result = await _productDatasource.importProducts(event.storeId, event.filePath);
      emit(ImportSuccess(
        created: result['created'] as int,
        skipped: result['skipped'] as int,
        errors: result['errors'] as List<dynamic>,
      ));
    } catch (e) {
      emit(ImportError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onTemplateRequested(ImportTemplateRequested event, Emitter<ImportState> emit) async {
    emit(ImportLoading());
    try {
      final path = await _productDatasource.downloadTemplatePath(event.storeId);
      emit(ImportTemplateDownloaded(filePath: path));
    } catch (e) {
      emit(ImportError(mapErrorToUserMessage(e)));
    }
  }
}
```

- [ ] **Step 5: Register import BLoC in injection.dart**

In `app/lib/injection.dart`:

```dart
sl.registerFactory<ImportBloc>(
  () => ImportBloc(productDatasource: sl<ProductRemoteDatasource>()),
);
```

- [ ] **Step 6: Commit**

```bash
git add app/lib/presentation/blocs/import/ app/lib/data/datasources/remote/product_remote_datasource.dart app/lib/injection.dart
git commit -m "feat: add import BLoC with preview and confirm flow"
```

---

### Task 20: Rewrite Import Products Page and Wire Button

**Files:**
- Modify: `app/lib/presentation/pages/product/import_products_page.dart`
- Modify: `app/lib/presentation/pages/product/product_list_page.dart`

- [ ] **Step 1: Rewrite ImportProductsPage with full flow**

Replace the entire contents of `app/lib/presentation/pages/product/import_products_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import '../../../core/constants/app_colors.dart';
import '../../../injection.dart';
import '../../blocs/import/import_bloc.dart';
import '../../blocs/import/import_event.dart';
import '../../blocs/import/import_state.dart';

class ImportProductsPage extends StatelessWidget {
  final String storeId;
  const ImportProductsPage({super.key, this.storeId = ''});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ImportBloc>(),
      child: _ImportProductsView(storeId: storeId),
    );
  }
}

class _ImportProductsView extends StatelessWidget {
  final String storeId;
  const _ImportProductsView({required this.storeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Импорт товаров')),
      body: BlocConsumer<ImportBloc, ImportState>(
        listener: (context, state) {
          if (state is ImportTemplateDownloaded) {
            OpenFile.open(state.filePath);
          } else if (state is ImportSuccess) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Импорт завершён'),
                content: Text(
                  'Создано: ${state.created}\n'
                  'Пропущено: ${state.skipped}\n'
                  'Ошибок: ${state.errors.length}',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.pop(true);
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          } else if (state is ImportError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is ImportLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ImportPreviewLoaded) {
            return _PreviewView(state: state, storeId: storeId);
          }

          return _InitialView(storeId: storeId);
        },
      ),
    );
  }
}

class _InitialView extends StatelessWidget {
  final String storeId;
  const _InitialView({required this.storeId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.upload_file, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text('Импорт товаров',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text(
            'Загрузите список товаров из Excel или CSV файла.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.lightTextSecondary),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['xlsx', 'csv'],
                );
                if (result != null && context.mounted) {
                  context.read<ImportBloc>().add(ImportFileSelected(
                    storeId: storeId,
                    filePath: result.files.single.path!,
                  ));
                }
              },
              icon: const Icon(Icons.file_upload),
              label: const Text('Выбрать файл'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                context.read<ImportBloc>().add(ImportTemplateRequested(storeId: storeId));
              },
              icon: const Icon(Icons.download),
              label: const Text('Скачать шаблон'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewView extends StatelessWidget {
  final ImportPreviewLoaded state;
  final String storeId;
  const _PreviewView({required this.state, required this.storeId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Найдено ${state.totalRows} товаров'
            '${state.errors.isNotEmpty ? ' (${state.errors.length} ошибок)' : ''}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        if (state.errors.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: state.errors.take(5).map((e) {
                final err = e as Map<String, dynamic>;
                return Text(
                  'Строка ${err['row']}: ${err['message']}',
                  style: TextStyle(color: AppColors.error, fontSize: 13),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Название')),
                DataColumn(label: Text('Штрихкод')),
                DataColumn(label: Text('Категория')),
                DataColumn(label: Text('Цена')),
                DataColumn(label: Text('Кол-во')),
              ],
              rows: state.rows.map((r) {
                final row = r as Map<String, dynamic>;
                return DataRow(cells: [
                  DataCell(Text(row['name']?.toString() ?? '')),
                  DataCell(Text(row['barcode']?.toString() ?? '')),
                  DataCell(Text(row['category']?.toString() ?? '')),
                  DataCell(Text(row['salePrice']?.toString() ?? '')),
                  DataCell(Text(row['quantity']?.toString() ?? '')),
                ]);
              }).toList(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.read<ImportBloc>().add(ImportConfirmed(
                  storeId: storeId,
                  filePath: state.filePath,
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text('Импортировать ${state.totalRows} товаров'),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Update router to pass storeId to ImportProductsPage**

In `app/lib/core/router/app_router.dart`, update the import products route:

```dart
// OLD:
GoRoute(
  path: RouteNames.importProducts,
  builder: (context, state) => const ImportProductsPage(),
),

// NEW:
GoRoute(
  path: RouteNames.importProducts,
  builder: (context, state) {
    final storeId = state.extra as String? ?? '';
    return ImportProductsPage(storeId: storeId);
  },
),
```

- [ ] **Step 3: Add import button to product list popup menu**

In `app/lib/presentation/pages/product/product_list_page.dart`, update the popup menu (around lines 97-108):

```dart
// OLD:
onSelected: (value) {
  if (value == 'categories') {
    context.push('/categories');
  }
},
itemBuilder: (context) => [
  const PopupMenuItem(
    value: 'categories',
    child: Text('Категории'),
  ),
],

// NEW:
onSelected: (value) {
  if (value == 'categories') {
    context.push('/categories');
  } else if (value == 'import') {
    context.push(RouteNames.importProducts, extra: _storeId);
  }
},
itemBuilder: (context) => [
  const PopupMenuItem(
    value: 'categories',
    child: Text('Категории'),
  ),
  const PopupMenuItem(
    value: 'import',
    child: Text('Импорт из Excel'),
  ),
],
```

Note: `_storeId` should reference the store ID available in the page. Check how other pages in the product module access storeId and follow the same pattern.

- [ ] **Step 4: Add file_picker and open_file dependencies**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter pub add file_picker open_file
```

- [ ] **Step 5: Commit**

```bash
git add app/lib/presentation/pages/product/import_products_page.dart app/lib/presentation/pages/product/product_list_page.dart app/lib/core/router/app_router.dart app/pubspec.yaml app/pubspec.lock
git commit -m "feat: implement full Excel import flow with preview and product list button"
```

---

## Sprint 4 — Polish & Stabilization

### Task 21: Verify Sync Endpoints

**Files:**
- Check: `api/src/modules/` for sync-related module

- [ ] **Step 1: Check if sync endpoints exist**

Search for sync controller/module in `api/src/modules/`. If endpoints `/sync/status` and `/sync/trigger` exist and are functional, mark as done.

If not, create minimal stubs:

```bash
# Check what exists:
ls api/src/modules/ | grep sync
```

- [ ] **Step 2: If missing, create minimal sync endpoints**

This is conditional — only if sync endpoints don't exist. Create a simple module that returns sync status from a store-level perspective. Implementation depends on what's found in step 1.

- [ ] **Step 3: Commit if changes were made**

```bash
git add api/src/modules/
git commit -m "feat: add minimal sync status and trigger endpoints"
```

---

### Task 22: Verify All Finance Dashboard Tiles

**Files:**
- Verify: `app/lib/presentation/pages/finance/finance_dashboard_page.dart`

- [ ] **Step 1: Check all 8 tiles have working navigation**

Open `finance_dashboard_page.dart` and verify each `_SectionItem` has a real `context.push(...)` call — no empty callbacks or `comingSoon` stubs remaining.

Expected working tiles:
1. Баланс → `/finance/balance`
2. Кредиты → `/finance/credits`
3. Вложения → `/investments` (fixed in Task 14)
4. Закят → `/zakat`
5. Валюты → `/finance/currencies`
6. Доставка → `/deliveries`
7. Отчёт → `/finance/reports`
8. Расходы → `/expenses`

- [ ] **Step 2: Fix any remaining empty callbacks**

If any tile still has empty callback or `comingSoon`, wire it to the appropriate route.

- [ ] **Step 3: Commit if changes were made**

```bash
git add app/lib/presentation/pages/finance/finance_dashboard_page.dart
git commit -m "fix: ensure all finance dashboard tiles have working navigation"
```

---

### Task 23: Final Integration Testing

- [ ] **Step 1: Start backend and verify all new endpoints**

```bash
cd /Users/latifrjdev/Downloads/Dukon/api
npm run start:dev
```

Test with curl:
```bash
# OTP endpoints
curl -X POST http://localhost:3000/auth/send-otp -H "Content-Type: application/json" -d '{"phone":"+992901234567"}'

# Investments (need auth token)
curl -X GET http://localhost:3000/stores/{storeId}/investments -H "Authorization: Bearer {token}"
curl -X GET http://localhost:3000/stores/{storeId}/investments/summary -H "Authorization: Bearer {token}"

# Import template
curl -X GET http://localhost:3000/stores/{storeId}/products/import/template -H "Authorization: Bearer {token}" -o template.xlsx
```

- [ ] **Step 2: Build Flutter app**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter build apk --debug
```

Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Manual testing checklist**

Run through each flow on device/emulator:
- [ ] Profile button → Settings page
- [ ] Forgot password flow (check server logs for OTP)
- [ ] Finance → Вложения → Add investment → Save → See in list
- [ ] Finance → Валюты → Rates load from backend
- [ ] Products → Menu → Импорт из Excel → Pick file → Preview → Import
- [ ] Notification toggle in settings persists

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: sprint 4 polish and integration testing complete"
```
