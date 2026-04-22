import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../blocs/pos/cart_state.dart';

class CartItemWidget extends StatelessWidget {
  final CartItem item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onDelete;

  const CartItemWidget({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      elevation: 1,
      shadowColor: context.shadowColor,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingSm + 4),
        child: Row(
          children: [
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
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
                  Text(
                    Formatters.price(item.unitPrice),
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            // Quantity selector
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQuantityButton(
                  context,
                  Icons.remove,
                  () {
                    if (item.quantity > 1) {
                      onQuantityChanged(item.quantity - 1);
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${item.quantity}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                _buildQuantityButton(
                  context,
                  Icons.add,
                  () => onQuantityChanged(item.quantity + 1),
                ),
              ],
            ),
            const SizedBox(width: AppConstants.spacingSm + 4),
            // Subtotal
            SizedBox(
              width: 80,
              child: Text(
                Formatters.price(item.total),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            // Delete button
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: context.danger.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton(BuildContext context, IconData icon, VoidCallback onTap) {
    return Material(
      color: context.bg,
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: Icon(icon, size: 18, color: AppColors.primary)),
        ),
      ),
    );
  }
}
