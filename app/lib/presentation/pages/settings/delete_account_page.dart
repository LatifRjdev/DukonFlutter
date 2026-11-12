import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../l10n/app_message_l10n.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_snackbar.dart';
import '../../widgets/common/app_text_field.dart';

/// Lets the signed-in user delete their account. Required by Google Play for
/// any app with sign-in, alongside a public page describing the same thing.
///
/// Deliberately not a one-tap action, and deliberately not a dialog on the
/// settings page: the consequences take a paragraph to state, the password has
/// to be re-entered, and a full screen is what makes room for both. The
/// confirm button stays disabled until something is typed, so the destructive
/// action is never one stray tap away.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Rebuild on every keystroke: the confirm button's enabled state is
    // derived from whether the field is empty.
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() => setState(() {});

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _passwordController.dispose();
    super.dispose();
  }

  void _confirm() {
    context
        .read<AuthBloc>()
        .add(AuthAccountDeletionRequested(_passwordController.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteAccountTitle)),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAccountDeleted) {
            AppSnackbar.success(context, l10n.deleteAccountSuccess);
            // `go`, not `pop`: every screen behind this one belongs to an
            // account that no longer exists.
            context.go(RouteNames.login);
          }
          if (state is AuthFailure) {
            AppSnackbar.error(context, state.message.resolve(l10n));
          }
        },
        builder: (context, state) {
          final isDeleting = state is AuthLoading;
          // No password, or a request already in flight — either way the
          // button must not fire.
          final canConfirm = _passwordController.text.isNotEmpty && !isDeleting;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                  Text(
                    l10n.deleteAccountWarning,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppConstants.spacingXl),
                  AppTextField(
                    controller: _passwordController,
                    label: l10n.deleteAccountPasswordLabel,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    enabled: !isDeleting,
                  ),
                  const SizedBox(height: AppConstants.spacingXl),
                  AppButton(
                    text: l10n.deleteAccountConfirmButton,
                    type: AppButtonType.danger,
                    isLoading: isDeleting,
                    onPressed: canConfirm ? _confirm : null,
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                  AppButton(
                    text: l10n.cancel,
                    type: AppButtonType.text,
                    onPressed: isDeleting ? null : () => context.pop(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
