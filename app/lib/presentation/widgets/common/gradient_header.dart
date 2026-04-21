import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_gradients.dart';

class GradientHeader extends StatelessWidget {
  final String greeting;
  final String userName;
  final String? storeName;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onStoreTap;
  final double bottomOverlap;

  const GradientHeader({
    super.key,
    required this.greeting,
    required this.userName,
    this.storeName,
    this.onNotificationTap,
    this.onProfileTap,
    this.onStoreTap,
    this.bottomOverlap = 36,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      decoration: BoxDecoration(gradient: AppGradients.primaryFor(brightness)),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: bottomOverlap + 16,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting, style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(userName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              Row(
                children: [
                  _iconButton(Icons.notifications_outlined, onNotificationTap),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onProfileTap,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(AppConstants.radiusXl)),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (storeName != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onStoreTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0x1FFFFFFF),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.store, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(storeName!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    const Icon(Icons.keyboard_arrow_down, color: Color(0x99FFFFFF), size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
