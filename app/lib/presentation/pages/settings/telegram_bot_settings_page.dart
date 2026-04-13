import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../injection.dart';

class TelegramBotSettingsPage extends StatefulWidget {
  final String storeId;
  const TelegramBotSettingsPage({super.key, required this.storeId});

  @override
  State<TelegramBotSettingsPage> createState() => _TelegramBotSettingsPageState();
}

class _TelegramBotSettingsPageState extends State<TelegramBotSettingsPage> {
  final _dioClient = sl<DioClient>();
  bool _loading = true;
  bool _connected = false;
  int _linkedCustomers = 0;
  String _botUsername = '@duckonpro_bot';
  bool _sendingTest = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dioClient
          .get('/stores/${widget.storeId}/telegram-bot/status');
      final data = res.data as Map<String, dynamic>? ?? {};
      setState(() {
        _connected = data['connected'] as bool? ?? false;
        _linkedCustomers = data['linkedCustomers'] as int? ?? 0;
        _botUsername = data['botUsername'] as String? ?? '@duckonpro_bot';
      });
    } catch (_) {
      // fallback to defaults
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendTestMessage() async {
    setState(() => _sendingTest = true);
    try {
      await _dioClient.post(
          '/stores/${widget.storeId}/telegram-bot/test-message');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Тестовое сообщение отправлено'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Telegram-бот'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _connected
                          ? AppColors.success.withValues(alpha: 0.08)
                          : AppColors.errorBg,
                      borderRadius:
                          BorderRadius.circular(AppConstants.cardRadius),
                      border: Border.all(
                        color: _connected
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: _connected
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.error.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.send_rounded,
                            color: _connected ? AppColors.success : AppColors.error,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      color: _connected
                                          ? AppColors.success
                                          : AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _connected ? 'Подключён' : 'Не подключён',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _connected
                                          ? AppColors.success
                                          : AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(_botUsername,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.lightTextSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          BorderRadius.circular(AppConstants.cardRadius),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.people_outline,
                              color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Подключённых клиентов',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                        ),
                        Text(
                          '$_linkedCustomers',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // How to connect instructions
                  const Text('Как подключить клиентов',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lightTextSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          BorderRadius.circular(AppConstants.cardRadius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStep('1', 'Клиент находит бота $_botUsername в Telegram'),
                        const SizedBox(height: 12),
                        _buildStep('2', 'Нажимает /start и вводит свой номер телефона'),
                        const SizedBox(height: 12),
                        _buildStep('3',
                            'Бот проверяет номер в базе клиентов и связывает аккаунт'),
                        const SizedBox(height: 12),
                        _buildStep('4',
                            'Клиент получает уведомления о продажах и долгах'),
                        const SizedBox(height: 16),
                        // QR placeholder
                        Center(
                          child: Container(
                            width: 120, height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.lightBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.lightBorder),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.qr_code_2,
                                    size: 64, color: AppColors.lightTextPrimary),
                                Text(_botUsername,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.lightTextSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Test message button
                  if (_connected) ...[
                    SizedBox(
                      width: double.infinity,
                      height: AppConstants.buttonHeight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppConstants.buttonRadius)),
                        ),
                        onPressed: _sendingTest ? null : _sendTestMessage,
                        icon: _sendingTest
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          _sendingTest ? 'Отправка...' : 'Тестовое сообщение',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(number,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.lightTextPrimary)),
        ),
      ],
    );
  }
}
