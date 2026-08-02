import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/datasources/local/auth_local_datasource.dart';
import '../../../injection.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';

/// Persistent (non-dismissible) banner shown while the app is running with
/// an impersonation-flavored access token — i.e. a support session started
/// by an admin from the admin panel's "Войти как пользователь" flow (see
/// ImpersonationService on the backend).
///
/// NOTE — deep-link caveat: the admin panel currently hands the token off
/// as a `dukonpro://impersonate?token=...` deep link + QR code, but this
/// codebase has no deep-link infrastructure at all (no `uni_links`/
/// `app_links` package, no registered URL scheme in AndroidManifest.xml or
/// Info.plist, no scheme-based router handling). Building that transport
/// was out of scope here — see the impersonation task's own guidance to
/// not invent a new deep-link subsystem from scratch.
///
/// So this widget implements only the *display* half: it reads
/// [AuthLocalDatasource.getImpersonationRequestId], which decodes the
/// `impersonationRequestId` claim off whatever access token is currently
/// stored, and shows the banner whenever that claim is present — however
/// the token got there. Today nothing in this app actually writes an
/// impersonation token into storage (no deep-link handler calls
/// saveTokens() with one), so in practice this banner cannot yet appear
/// end-to-end. It's built so that wiring up a receiving mechanism later
/// (deep link, manual token entry, etc.) only requires calling
/// saveTokens() with the token — this banner will correctly react without
/// further changes.
class ImpersonationBanner extends StatefulWidget {
  const ImpersonationBanner({super.key});

  @override
  State<ImpersonationBanner> createState() => _ImpersonationBannerState();
}

class _ImpersonationBannerState extends State<ImpersonationBanner> {
  String? _requestId;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = await sl<AuthLocalDatasource>().getImpersonationRequestId();
      if (mounted) setState(() => _requestId = id);
    } catch (_) {
      // Non-critical — never block the home screen on failure.
    }
  }

  Future<void> _endSession() async {
    final id = _requestId;
    if (id == null || _ending) return;
    setState(() => _ending = true);
    try {
      await sl<DioClient>().post('/admin/impersonation/$id/end');
    } catch (_) {
      // Even if the backend call fails, still log the device out locally —
      // the whole point of this button is "get me out of this session now".
    }
    if (mounted) {
      context.read<AuthBloc>().add(AuthLogoutRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_requestId == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.warning,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        children: [
          const Icon(Icons.support_agent, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Вы вошли как поддержка Dukon',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: _ending ? null : _endSession,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: _ending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Завершить сессию'),
          ),
        ],
      ),
    );
  }
}
