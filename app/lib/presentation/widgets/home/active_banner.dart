import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../injection.dart';

/// Shows the currently active in-app banner for [storeId] (targeted by the
/// admin via plan/status filters), if any. Dismissal is persisted locally
/// so a dismissed banner never reappears on this device, even after a
/// relaunch — the backend has no concept of "seen" state.
class ActiveBanner extends StatefulWidget {
  final String storeId;
  const ActiveBanner({super.key, required this.storeId});

  @override
  State<ActiveBanner> createState() => _ActiveBannerState();
}

class _ActiveBannerState extends State<ActiveBanner> {
  Map<String, dynamic>? _banner;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = sl<DioClient>();
      final response = await client.get('/stores/${widget.storeId}/banners/active');
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return;

      final prefs = await SharedPreferences.getInstance();
      final dismissedIds = prefs.getStringList('dismissed_banner_ids') ?? [];
      if (dismissedIds.contains(data['id'])) return;

      if (mounted) {
        setState(() => _banner = data);
      }
    } catch (_) {
      // Banner is non-critical — never block the home screen on failure.
    }
  }

  Future<void> _dismiss() async {
    if (_banner == null) return;
    final prefs = await SharedPreferences.getInstance();
    final dismissedIds = prefs.getStringList('dismissed_banner_ids') ?? [];
    dismissedIds.add(_banner!['id'] as String);
    await prefs.setStringList('dismissed_banner_ids', dismissedIds);
    if (mounted) {
      setState(() => _dismissed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_banner == null || _dismissed) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _banner!['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  _banner!['body'] as String,
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _dismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
