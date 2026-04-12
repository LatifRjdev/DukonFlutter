import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../injection.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final _dioClient = sl<DioClient>();
  bool _loading = true;
  String _planName = 'БИЗНЕС';
  String _expiryDate = '30.03.2026';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _dioClient.get('/subscription/current');
      final data = res.data as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _planName = data['planName'] as String? ?? 'БИЗНЕС';
          _expiryDate = data['expiryDate'] as String? ?? '30.03.2026';
        });
      }
    } catch (_) {
      // use defaults
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Подписка'),
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
                  // Current plan card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.gradientStart, AppColors.gradientEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.circular(AppConstants.cardRadius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.workspace_premium,
                                color: Colors.amber, size: 28),
                            const SizedBox(width: 10),
                            Text(
                              _planName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('Текущий тариф',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Text('Действует до: $_expiryDate',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Активна',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Feature comparison
                  const Text('Сравнение тарифов',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lightTextSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          BorderRadius.circular(AppConstants.cardRadius),
                    ),
                    child: Column(
                      children: [
                        // Header row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.lightBackground,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                flex: 3,
                                child: Text('Функция',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.lightTextSecondary)),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text('Бесплатно',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.lightTextSecondary)),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text('Бизнес',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ..._features.asMap().entries.map((entry) {
                          final f = entry.value;
                          final isLast = entry.key == _features.length - 1;
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(f.name,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500)),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: _buildCheck(f.free),
                                      ),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: _buildCheck(f.business),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isLast) const Divider(height: 1, indent: 16),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Read-only notice
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      borderRadius:
                          BorderRadius.circular(AppConstants.cardRadius),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: AppColors.info, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Управление подпиской и оплата доступны в личном кабинете '
                            'на сайте dokonpro.tj. Обратитесь к вашему менеджеру.',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.lightTextSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildCheck(bool? value) {
    if (value == null) {
      return const Text('—',
          style: TextStyle(color: AppColors.lightTextHint, fontSize: 16));
    }
    return Icon(
      value ? Icons.check_circle_rounded : Icons.cancel_outlined,
      color: value ? AppColors.success : AppColors.lightTextHint,
      size: 20,
    );
  }
}

class _Feature {
  final String name;
  final bool? free;
  final bool? business;
  const _Feature(this.name, {this.free, this.business});
}

const _features = [
  _Feature('Товары', free: true, business: true),
  _Feature('Продажи (POS)', free: true, business: true),
  _Feature('Финансы', free: true, business: true),
  _Feature('Кол-во магазинов: 1 / ∞', free: true, business: true),
  _Feature('Сотрудники', free: null, business: true),
  _Feature('Telegram-бот', free: null, business: true),
  _Feature('Аналитика', free: null, business: true),
  _Feature('Экспорт Excel', free: null, business: true),
  _Feature('Доставка', free: null, business: true),
  _Feature('Зарплата', free: null, business: true),
  _Feature('Фискализация (ККМ)', free: null, business: true),
  _Feature('Приоритетная поддержка', free: null, business: true),
];
