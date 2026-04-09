import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/sale.dart';

class SaleListItem extends StatelessWidget {
  final Sale sale;
  final VoidCallback? onTap;

  const SaleListItem({
    super.key,
    required this.sale,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      elevation: 1,
      shadowColor: AppColors.shadow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingSm + 4,
          ),
          child: Row(
            children: [
              // Receipt icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm + 4),
              // Sale info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${sale.receiptNo}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.time(sale.createdAt),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              // Amount and payment badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.price(sale.total),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildPaymentBadge(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentBadge() {
    Color badgeColor;
    String badgeLabel;

    switch (sale.paymentType) {
      case 'CASH':
        badgeColor = AppColors.success;
        badgeLabel = 'Наличные';
        break;
      case 'CARD':
        badgeColor = AppColors.info;
        badgeLabel = 'Карта';
        break;
      case 'DEBT':
        badgeColor = AppColors.warning;
        badgeLabel = 'В долг';
        break;
      default:
        badgeColor = AppColors.textSecondary;
        badgeLabel = sale.paymentType;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Text(
        badgeLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: badgeColor,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}
