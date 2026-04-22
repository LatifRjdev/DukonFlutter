import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/product.dart';

class ProductListItem extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductListItem({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      elevation: AppConstants.cardElevation,
      shadowColor: context.shadowColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingSm + 4),
          child: Row(
            children: [
              // Image placeholder
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.bg,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: product.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildImagePlaceholder(context),
                        ),
                      )
                    : _buildImagePlaceholder(context),
              ),
              const SizedBox(width: AppConstants.spacingSm + 4),
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (product.sku != null)
                      Text(
                        'SKU: ${product.sku}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.price(product.sellPrice),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              // Quantity badge
              _buildQuantityBadge(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return Center(
      child: Icon(
        Icons.inventory_2_outlined,
        color: context.textMuted,
        size: 28,
      ),
    );
  }

  Widget _buildQuantityBadge(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    if (product.isOutOfStock) {
      backgroundColor = context.danger.withValues(alpha: 0.1);
      textColor = context.danger;
    } else if (product.isLowStock) {
      backgroundColor = context.warning.withValues(alpha: 0.1);
      textColor = context.warning;
    } else {
      backgroundColor = context.success.withValues(alpha: 0.1);
      textColor = context.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Text(
        '${product.quantity}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textColor,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}
