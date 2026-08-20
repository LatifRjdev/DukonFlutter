import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/enums.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_event.dart';
import '../../blocs/store/store_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_chip.dart';
import '../../widgets/common/app_snackbar.dart';

class CreateStorePage extends StatefulWidget {
  const CreateStorePage({super.key});

  @override
  State<CreateStorePage> createState() => _CreateStorePageState();
}

class _CreateStorePageState extends State<CreateStorePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  StoreCategory _selectedCategory = StoreCategory.grocery;
  Currency _selectedCurrency = Currency.tjs;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<StoreBloc>().add(StoreCreateRequested(
        name: _nameController.text,
        category: _selectedCategory.name.toUpperCase(),
        currency: _selectedCurrency.name.toUpperCase(),
        address: _addressController.text.isNotEmpty ? _addressController.text : null,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createStore)),
      body: BlocListener<StoreBloc, StoreState>(
        listener: (context, state) {
          if (state is StoreLoaded && state.selectedStore != null) {
            context.go('/home');
          } else if (state is StoreError) {
            AppSnackbar.error(context, state.message);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.storeCategory,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: StoreCategory.values.map((cat) => AppChip(
                    label: cat.displayName,
                    isSelected: _selectedCategory == cat,
                    onTap: () => setState(() => _selectedCategory = cat),
                  )).toList(),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _nameController,
                  label: l10n.storeName,
                  prefixIcon: Icons.store,
                  validator: (v) => v == null || v.isEmpty ? l10n.createStoreNameRequiredError : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _addressController,
                  label: l10n.createStoreAddressLabel,
                  prefixIcon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _phoneController,
                  label: l10n.createStorePhoneLabel,
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                Text(l10n.currency,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: Currency.values.map((cur) => AppChip(
                    label: '${cur.name} ${cur.symbol}',
                    isSelected: _selectedCurrency == cur,
                    onTap: () => setState(() => _selectedCurrency = cur),
                  )).toList(),
                ),
                const SizedBox(height: 40),
                BlocBuilder<StoreBloc, StoreState>(
                  builder: (context, state) {
                    return AppButton(
                      text: l10n.createStore,
                      onPressed: _submit,
                      isLoading: state is StoreLoading,
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
