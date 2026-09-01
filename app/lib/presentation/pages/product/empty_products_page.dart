import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import '../../widgets/common/app_button.dart';

class EmptyProductsPage extends StatelessWidget {
  const EmptyProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.products),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    size: 56, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.emptyProductsTitle,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.emptyProductsSubtitle,
                style: TextStyle(
                    color: context.textSecondary, fontSize: 15, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AppButton(
                text: l10n.addProduct,
                icon: Icons.add,
                width: 220,
                onPressed: () => context.push('/products/add'),
              ),
              const SizedBox(height: 12),
              AppButton(
                text: l10n.importFromExcel,
                type: AppButtonType.outlined,
                icon: Icons.upload_file,
                width: 220,
                onPressed: () {
                  final storeState = context.read<StoreBloc>().state;
                  final storeId = storeState is StoreLoaded
                      ? storeState.selectedStore?.id ?? ''
                      : '';
                  context.push('/products/import', extra: storeId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
