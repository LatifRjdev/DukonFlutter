import 'package:flutter/material.dart';
import '../../../core/theme/theme_extensions.dart';
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
        color: context.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Store name
          Text(
            storeName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          // Receipt number
          Text(
            '#${sale.receiptNo}',
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          // Date
          Text(
            Formatters.dateTime(sale.createdAt),
            style: TextStyle(
              fontSize: 13,
              color: context.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          // Dashed divider
          _buildDashedDivider(context),
          const SizedBox(height: AppConstants.spacingSm),
          // Items header
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Товар',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
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
                    color: context.textSecondary,
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
                    color: context.textSecondary,
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
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textPrimary,
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
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textPrimary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        Formatters.price(item.total),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textPrimary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: AppConstants.spacingSm),
          _buildDashedDivider(context),
          const SizedBox(height: AppConstants.spacingSm),
          // Subtotal
          _buildTotalRow(context, 'Подытог', Formatters.price(sale.subtotal)),
          if (sale.discount > 0)
            _buildTotalRow(context, 'Скидка', '- ${Formatters.price(sale.discount)}'),
          const SizedBox(height: AppConstants.spacingXs),
          // Total
          _buildTotalRow(
            context,
            'ИТОГО',
            Formatters.price(sale.total),
            isBold: true,
            fontSize: 18,
          ),
          const SizedBox(height: AppConstants.spacingSm),
          _buildDashedDivider(context),
          const SizedBox(height: AppConstants.spacingSm),
          // Payment info
          _buildTotalRow(context, 'Оплата', sale.paymentType),
          _buildTotalRow(context, 'Оплачено', Formatters.price(sale.paidAmount)),
          if (sale.change > 0)
            _buildTotalRow(context, 'Сдача', Formatters.price(sale.change)),
          const SizedBox(height: AppConstants.spacingMd),
          // Footer
          Text(
            'Спасибо за покупку!',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 14,
  }) {
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
              color: context.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: context.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        const dashWidth = 5.0;
        const dashSpace = 3.0;
        final dashCount =
            (constraints.constrainWidth() / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: context.border),
              ),
            );
          }),
        );
      },
    );
  }
}
