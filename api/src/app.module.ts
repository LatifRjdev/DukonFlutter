import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { ScheduleModule } from '@nestjs/schedule';
import { APP_GUARD } from '@nestjs/core';
import { PrismaModule } from './prisma/prisma.module';
import { RedisModule } from './redis/redis.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { StoresModule } from './modules/stores/stores.module';
import { CategoriesModule } from './modules/categories/categories.module';
import { ProductsModule } from './modules/products/products.module';
import { SalesModule } from './modules/sales/sales.module';
import { CustomersModule } from './modules/customers/customers.module';
import { SuppliersModule } from './modules/suppliers/suppliers.module';
import { ExpensesModule } from './modules/expenses/expenses.module';
import { FinancesModule } from './modules/finances/finances.module';
import { ZakatModule } from './modules/zakat/zakat.module';
import { StaffModule } from './modules/staff/staff.module';
import { RolesModule } from './modules/roles/roles.module';
import { PayrollModule } from './modules/payroll/payroll.module';
import { ShiftsModule } from './modules/shifts/shifts.module';
import { ReportsModule } from './modules/reports/reports.module';
import { DeliveriesModule } from './modules/deliveries/deliveries.module';
import { InventoryCountsModule } from './modules/inventory-counts/inventory-counts.module';
import { CurrenciesModule } from './modules/currencies/currencies.module';
import { TelegramModule } from './modules/telegram/telegram.module';
import { NotificationsModule } from './modules/notifications/notifications.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }]),
    ScheduleModule.forRoot(),
    PrismaModule,
    RedisModule,
    AuthModule,
    UsersModule,
    StoresModule,
    CategoriesModule,
    ProductsModule,
    SalesModule,
    CustomersModule,
    SuppliersModule,
    ExpensesModule,
    FinancesModule,
    ZakatModule,
    StaffModule,
    RolesModule,
    PayrollModule,
    ShiftsModule,
    ReportsModule,
    DeliveriesModule,
    InventoryCountsModule,
    CurrenciesModule,
    TelegramModule,
    NotificationsModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}
