import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../blocs/settings/settings_bloc.dart';
import '../../blocs/settings/settings_event.dart';
import '../../blocs/settings/settings_state.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();
    context.read<SettingsBloc>().add(SettingsProfileUpdated(
      name: fullName.isEmpty ? null : fullName,
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: BlocConsumer<SettingsBloc, SettingsState>(
          listener: (context, state) {
            if (state is SettingsLoaded && !_initialized) {
              _initialized = true;
              final parts = state.user.name.split(' ');
              _firstNameController.text = parts.isNotEmpty ? parts.first : '';
              _lastNameController.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
              _emailController.text = state.user.email ?? '';
              _phoneController.text = state.user.phone;
            }
            if (state is SettingsActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.success),
              );
              context.pop();
            }
            if (state is SettingsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
              );
            }
          },
          builder: (context, state) {
            if (state is SettingsLoading && !_initialized) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                      const Text('Профиль',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton(
                        onPressed: _save,
                        child: const Text('Сохранить',
                          style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Avatar
                          Center(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: const Icon(Icons.person, size: 40, color: AppColors.primary),
                                ),
                                const SizedBox(height: 8),
                                const Text('Изменить фото',
                                  style: TextStyle(fontSize: 13, color: AppColors.primary)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Name fields
                          _buildField('Имя', _firstNameController, validator: (v) {
                            if (v == null || v.isEmpty) return 'Введите имя';
                            return null;
                          }),
                          const SizedBox(height: 16),
                          _buildField('Фамилия', _lastNameController),
                          const SizedBox(height: 16),
                          _buildField('Email', _emailController,
                            keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 16),
                          _buildField('Телефон', _phoneController,
                            keyboardType: TextInputType.phone, enabled: false),
                          const SizedBox(height: 16),

                          // Role badge
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock_outlined, size: 16, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Владелец',
                                  style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Security section
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Безопасность',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.lightTextSecondary)),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.lightBackground,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  title: const Text('Сменить пароль',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  trailing: const Icon(Icons.chevron_right, color: AppColors.lightTextSecondary, size: 20),
                                  onTap: () => context.push('/settings/password'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Save button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: state is SettingsLoading ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                state is SettingsLoading ? 'Сохранение...' : 'Сохранить изменения',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14, color: AppColors.lightTextSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
