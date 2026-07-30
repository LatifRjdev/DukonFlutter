import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Param,
  Query,
  Res,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import type { Response } from 'express';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiConsumes,
  ApiBody,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { StoreAccessGuard } from '../../common/guards/store-access.guard';
import { AdminGuard } from '../../common/guards/admin.guard';
import { SkipThrottle } from '@nestjs/throttler';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SubscriptionsService } from './subscriptions.service';
import { AdminExportService } from '../admin/admin-export.service';
import { RequestChangeDto } from './dto/request-change.dto';
import { AdminSubscriptionQueryDto } from './dto/admin-subscription-query.dto';
import { AdminSubscriptionExportQueryDto } from './dto/admin-subscription-export-query.dto';
import { RejectPaymentDto } from './dto/reject-payment.dto';
import { ChangePlanDto } from './dto/change-plan.dto';
import { ExtendSubscriptionDto } from './dto/extend-subscription.dto';
import { SetDiscountDto } from './dto/set-discount.dto';
import { AdminManualPaymentDto } from './dto/admin-manual-payment.dto';

// ─── User endpoints ────────────────────────────────────────────────────────────

@ApiTags('Subscriptions')
@Controller('subscription')
export class SubscriptionPlansController {
  constructor(private readonly subscriptionsService: SubscriptionsService) {}

  @Get('plans')
  @ApiOperation({
    summary: 'Get all subscription plan configs (public, no auth)',
  })
  getPlans() {
    return this.subscriptionsService.getPlans();
  }
}

@ApiTags('Subscriptions')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, StoreAccessGuard)
@Controller('stores/:storeId/subscription')
export class SubscriptionsController {
  constructor(private readonly subscriptionsService: SubscriptionsService) {}

  @Get()
  @ApiOperation({
    summary: 'Get subscription with plan config and calculated price',
  })
  getSubscription(@Param('storeId') storeId: string) {
    return this.subscriptionsService.getSubscription(storeId);
  }

  @Post('request-change')
  @ApiOperation({
    summary: 'Request a plan change — creates a pending payment',
  })
  requestChange(
    @Param('storeId') storeId: string,
    @Body() dto: RequestChangeDto,
  ) {
    return this.subscriptionsService.requestChange(storeId, dto);
  }

  @Post('upload-receipt/:paymentId')
  @ApiOperation({ summary: 'Upload receipt image for a pending payment' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: join(process.cwd(), 'uploads', 'receipts'),
        filename: (_req, file, cb) => {
          const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
          cb(null, `${unique}${extname(file.originalname)}`);
        },
      }),
      fileFilter: (_req, file, cb) => {
        if (!file.mimetype.match(/\/(jpg|jpeg|png|gif|pdf)$/)) {
          return cb(
            new BadRequestException('Only image/pdf files allowed'),
            false,
          );
        }
        cb(null, true);
      },
      limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
    }),
  )
  uploadReceipt(
    @Param('storeId') storeId: string,
    @Param('paymentId') paymentId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }
    const filePath = `uploads/receipts/${file.filename}`;
    return this.subscriptionsService.uploadReceipt(
      storeId,
      paymentId,
      filePath,
    );
  }

  @Get('payments')
  @ApiOperation({ summary: 'Get payment history for store' })
  getPaymentHistory(@Param('storeId') storeId: string) {
    return this.subscriptionsService.getPaymentHistory(storeId);
  }
}

// ─── Admin endpoints ───────────────────────────────────────────────────────────

@ApiTags('Admin - Subscriptions')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin/subscriptions')
export class AdminSubscriptionsController {
  constructor(
    private readonly subscriptionsService: SubscriptionsService,
    private readonly exportService: AdminExportService,
  ) {}

  @Get()
  @ApiOperation({
    summary: 'Admin: list all subscriptions with optional filters',
  })
  getAll(@Query() query: AdminSubscriptionQueryDto) {
    return this.subscriptionsService.adminGetAll(query);
  }

  @Get('export')
  @ApiOperation({
    summary: 'Export the current filtered subscription list as .xlsx',
  })
  async exportSubscriptions(
    @Query() query: AdminSubscriptionExportQueryDto,
    @Res() res: Response,
  ) {
    const buffer = await this.exportService.exportSubscriptions(query);
    res.set({
      'Content-Type':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="dukonpro-subscriptions-${new Date().toISOString().slice(0, 10)}.xlsx"`,
    });
    res.send(buffer);
  }

  @Get('pending-payments')
  @ApiOperation({
    summary: 'Admin: list pending payments with store name and receipt',
  })
  getPendingPayments() {
    return this.subscriptionsService.adminGetPendingPayments();
  }

  @SkipThrottle()
  @Put(':id/approve-payment/:paymentId')
  @ApiOperation({ summary: 'Admin: approve payment — activates subscription' })
  approvePayment(
    @Param('id') id: string,
    @Param('paymentId') paymentId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.subscriptionsService.adminApprovePayment(id, paymentId, userId);
  }

  @SkipThrottle()
  @Put(':id/reject-payment/:paymentId')
  @ApiOperation({ summary: 'Admin: reject payment with reason' })
  rejectPayment(
    @Param('id') id: string,
    @Param('paymentId') paymentId: string,
    @Body() dto: RejectPaymentDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.subscriptionsService.adminRejectPayment(
      id,
      paymentId,
      dto,
      userId,
    );
  }

  @SkipThrottle()
  @Post(':id/manual-payment')
  @ApiOperation({
    summary:
      'Admin: record a manual payment (cash/transfer received outside the app) and extend the subscription',
  })
  manualPayment(
    @Param('id') id: string,
    @Body() dto: AdminManualPaymentDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.subscriptionsService.adminCreateManualPayment(id, dto, userId);
  }

  @Put(':id/extend')
  @ApiOperation({ summary: 'Admin: extend subscription by N days' })
  extend(
    @Param('id') id: string,
    @Body() dto: ExtendSubscriptionDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.subscriptionsService.adminExtend(id, dto, userId);
  }

  @Put(':id/change-plan')
  @ApiOperation({ summary: 'Admin: change subscription plan' })
  changePlan(
    @Param('id') id: string,
    @Body() dto: ChangePlanDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.subscriptionsService.adminChangePlan(id, dto, userId);
  }

  @Put(':id/set-discount')
  @ApiOperation({ summary: 'Admin: set admin discount percentage (0 removes)' })
  setDiscount(@Param('id') id: string, @Body() dto: SetDiscountDto) {
    return this.subscriptionsService.adminSetDiscount(id, dto);
  }

  @Put(':id/cancel')
  @ApiOperation({ summary: 'Admin: cancel subscription' })
  cancel(@Param('id') id: string) {
    return this.subscriptionsService.adminCancel(id);
  }

  // ─── Manual cron triggers (QA / ops) ───────────────────────────────────────
  // The matching @Cron jobs run at midnight and 09:00. These admin-gated
  // POST endpoints let QA exercise the EXPIRED-state flip and the
  // 3-day-out FCM reminder without waiting for the scheduler.

  @Post('run-expiry-check')
  @ApiOperation({
    summary:
      'Admin: manually run the expiry check cron (flips overdue subs to EXPIRED + push)',
  })
  async runExpiryCheck() {
    await this.subscriptionsService.checkExpiredSubscriptions();
    return { ok: true, message: 'Expiry check executed' };
  }

  @Post('send-expiry-reminders')
  @ApiOperation({
    summary:
      'Admin: manually dispatch 3-day expiry reminder push notifications',
  })
  async sendExpiryReminders() {
    await this.subscriptionsService.sendExpiryReminders();
    return { ok: true, message: 'Expiry reminders dispatched' };
  }
}
