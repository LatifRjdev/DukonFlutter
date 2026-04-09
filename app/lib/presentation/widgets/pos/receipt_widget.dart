import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/sale.dart';

class ReceiptWidget extends StatelessWidget {
  final Sale sale;
  final String storeName;

  const ReceiptWidget({
    super.key,
    required this.sale,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Store name
          Text(
            storeName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.lightTextPrimary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          // Receipt number
          Text(
            '#${sale.receiptNo}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.lightTextSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          // Date
          Text(
            Formatters.dateTime(sale.createdAt),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.lightTextSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          // Dashed divider
          _buildDashedDivider(),
          const SizedBox(height: AppConstants.spacingSm),
          // Items header
          const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Товар',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightTextSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Кол.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightTextSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Сумма',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightTextSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          // Items
          ...sale.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.productName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.lightTextPrimary,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${item.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.lightTextPrimary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        Formatters.price(item.total),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.lightTextPrimary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: AppConstants.spacingSm),
          _buildDashedDivider(),
          const SizedBox(height: AppConstants.spacingSm),
          // Subtotal
          _buildTotalRow('Подытог', Formatters.price(sale.subtotal)),
          if (sale.discount > 0)
            _buildTotalRow('Скидка', '- ${Formatters.price(sale.discount)}'),
          const SizedBox(height: AppConstants.spacingXs),
          // Total
          _buildTotalRow(
            'ИТОГО',
            Formatters.price(sale.total),
            isBold: true,
            fontSize: 18,
          ),
          const SizedBox(height: AppConstants.spacingSm),
          _buildDashedDivider(),
          const SizedBox(height: AppConstants.spacingSm),
          // Payment info
          _buildTotalRow('Оплата', sale.paymentType),
          _buildTotalRow('Оплачено', Formatters.price(sale.paidAmount)),
          if (sale.change > 0)
            _buildTotalRow('Сдача', Formatters.price(sale.change)),
          const SizedBox(height: AppConstants.spacingMd),
          // Footer
          const Text(
            'Спасибо за покупку!',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.lightTextSecondary,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value,
      {bool isBold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: AppColors.lightTextPrimary,
              fontFamily: 'Inter',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.lightTextPrimary,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const dashSpace = 3.0;
        final dashCount =
            (constraints.constrainWidth() / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.lightBorder),
              ),
            );
          }),
        );
      },
    );
  }
}
