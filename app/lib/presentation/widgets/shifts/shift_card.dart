import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/shift.dart';
import '../common/app_card.dart';

class ShiftCard extends StatelessWidget {
  final ShiftModel shift;
  final VoidCallback? onTap;

  const ShiftCard({super.key, required this.shift, this.onTap});

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(DateTime open, DateTime? close) {
    final end = close ?? DateTime.now();
    final diff = end.difference(open);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    return '${hours}ч ${minutes}м';
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = shift.status == 'OPEN';

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isOpen ? AppColors.success : AppColors.lightTextSecondary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isOpen ? Icons.access_time : Icons.check_circle_outline,
                  color: isOpen ? AppColors.success : AppColors.lightTextSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          shift.staffName ?? 'Сотрудник',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(width: AppConstants.spacingSm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isOpen ? AppColors.success : AppColors.disabled).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                          ),
                          child: Text(
                            isOpen ? 'Открыта' : 'Закрыта',
                            style: TextStyle(
                              color: isOpen ? AppColors.success : AppColors.lightTextSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDateTime(shift.openedAt)} - ${_formatDuration(shift.openedAt, shift.closedAt)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${shift.salesTotal.toStringAsFixed(0)} TJS',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    '${shift.salesCount} продаж',
                    style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
