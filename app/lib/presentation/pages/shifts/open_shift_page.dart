import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/shift/shift_bloc.dart';
import '../../blocs/shift/shift_event.dart';
import '../../blocs/shift/shift_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_snackbar.dart';
import 'package:dokonpro/l10n/app_localizations.dart';
import '../../widgets/common/app_text_field.dart';

class OpenShiftPage extends StatefulWidget {
  final String storeId;
  const OpenShiftPage({super.key, required this.storeId});
  @override
  State<OpenShiftPage> createState() => _OpenShiftPageState();
}

class _OpenShiftPageState extends State<OpenShiftPage> {
  final _formKey = GlobalKey<FormState>();
  final _cashController = TextEditingController();

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final cash = double.tryParse(_cashController.text);
    if (cash == null || cash < 0) return;

    context.read<ShiftBloc>().add(OpenShift(
      storeId: widget.storeId,
      openingCash: cash,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Открыть смену')),
      body: BlocListener<ShiftBloc, ShiftState>(
        listener: (context, state) {
          if (state is ShiftOpened) {
            AppSnackbar.success(context, AppLocalizations.of(context)!.snackShiftOpened);
            context.pop();
          }
          if (state is ShiftError) {
            AppSnackbar.error(context, state.message);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppConstants.spacingLg),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.point_of_sale,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: AppConstants.spacingMd),
                      const Text(
                        'Начало смены',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      const SizedBox(height: AppConstants.spacingSm),
                      Text(
                        'Укажите сумму наличных в кассе на начало смены',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spacingLg),
                AppTextField(
                  controller: _cashController,
                  label: 'Сумма наличных (TJS)',
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите сумму';
                    if (double.tryParse(v) == null) return 'Некорректная сумма';
                    if (double.parse(v) < 0) return 'Сумма не может быть отрицательной';
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingXl),
                BlocBuilder<ShiftBloc, ShiftState>(
                  builder: (context, state) {
                    return AppButton(
                      text: 'Открыть смену',
                      icon: Icons.play_arrow,
                      isLoading: state is ShiftLoading,
                      onPressed: _submit,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
