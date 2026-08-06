import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/router/route_names.dart';
import '../../../injection.dart';
import '../../widgets/common/app_snackbar.dart';

class EcommerceSettingsPage extends StatefulWidget {
  final String storeId;
  const EcommerceSettingsPage({super.key, required this.storeId});

  @override
  State<EcommerceSettingsPage> createState() => _EcommerceSettingsPageState();
}

class _EcommerceSettingsPageState extends State<EcommerceSettingsPage> {
  final _dioClient = sl<DioClient>();
  bool _loading = true;
  bool _configured = false;
  String? _apiKey;
  bool _enabled = true;
  final _webhookUrlController = TextEditingController();

  // DioClient doesn't expose the configured base URL, so build the inbound
  // webhook URL from the same ApiEndpoints.baseUrl constant DioClient itself
  // is initialized with.
  String get _inboundWebhookUrl =>
      '${ApiEndpoints.baseUrl}/stores/${widget.storeId}/ecommerce/orders';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _webhookUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dioClient
          .get('/stores/${widget.storeId}/ecommerce/integration');
      final data = res.data as Map<String, dynamic>?;
      if (data != null) {
        setState(() {
          _configured = true;
          _apiKey = data['apiKey'] as String?;
          _enabled = data['enabled'] as bool? ?? true;
          _webhookUrlController.text =
              data['outboundWebhookUrl'] as String? ?? '';
        });
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, mapErrorToUserMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    try {
      final res = await _dioClient.put(
        '/stores/${widget.storeId}/ecommerce/integration',
        data: {
          'outboundWebhookUrl': _webhookUrlController.text.trim().isEmpty
              ? null
              : _webhookUrlController.text.trim(),
          'enabled': _enabled,
        },
      );
      final data = res.data as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _configured = true;
          _apiKey = data?['apiKey'] as String? ?? _apiKey;
        });
        AppSnackbar.success(context, 'Настройки сохранены');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, mapErrorToUserMessage(e));
    }
  }

  Future<void> _regenerateKey() async {
    try {
      final res = await _dioClient.post(
        '/stores/${widget.storeId}/ecommerce/integration/regenerate-key',
      );
      final data = res.data as Map<String, dynamic>?;
      if (mounted) {
        setState(() => _apiKey = data?['apiKey'] as String?);
        AppSnackbar.success(context, 'Ключ перегенерирован');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, mapErrorToUserMessage(e));
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.info(context, '$label скопирован(о)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Интернет-магазин'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('URL для входящих заказов',
                    style:
                        TextStyle(fontSize: 13, color: context.textSecondary)),
                const SizedBox(height: 6),
                _CopyableField(
                  value: _inboundWebhookUrl,
                  onCopy: () => _copy(_inboundWebhookUrl, 'URL'),
                ),
                const SizedBox(height: 16),
                Text('API-ключ',
                    style:
                        TextStyle(fontSize: 13, color: context.textSecondary)),
                const SizedBox(height: 6),
                _CopyableField(
                  value: _configured
                      ? (_apiKey ?? '—')
                      : 'Сохраните настройки, чтобы создать ключ',
                  onCopy: _apiKey == null ? null : () => _copy(_apiKey!, 'Ключ'),
                  obscure: _configured && _apiKey != null,
                ),
                if (_configured) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _regenerateKey,
                    child: const Text('Перегенерировать ключ'),
                  ),
                ],
                const SizedBox(height: 16),
                Text('URL вебхука вашего сайта',
                    style:
                        TextStyle(fontSize: 13, color: context.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _webhookUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'https://your-shop.example.com/dukon-webhook',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Интеграция активна'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  activeThumbColor: AppColors.primary,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: AppConstants.buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusLg)),
                    ),
                    onPressed: _save,
                    child: const Text('Сохранить',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.push(
                    RouteNames.ecommerceProductMapping,
                    extra: widget.storeId,
                  ),
                  child: const Text('Сопоставление товаров'),
                ),
              ],
            ),
    );
  }
}

class _CopyableField extends StatefulWidget {
  final String value;
  final VoidCallback? onCopy;
  final bool obscure;
  const _CopyableField({
    required this.value,
    required this.onCopy,
    this.obscure = false,
  });

  @override
  State<_CopyableField> createState() => _CopyableFieldState();
}

class _CopyableFieldState extends State<_CopyableField> {
  bool _revealed = false;

  @override
  void didUpdateWidget(covariant _CopyableField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.obscure && widget.value != oldWidget.value) {
      _revealed = false;
    }
  }

  String get _displayValue {
    if (!widget.obscure || _revealed) return widget.value;
    // Mask everything except keep the string length roughly indicative —
    // a fixed-width mask avoids leaking the real key's length exactly,
    // while still visually reading as "there's a secret here".
    return '•' * 24;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: context.border),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(_displayValue,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          ),
          if (widget.obscure)
            IconButton(
              icon: Icon(
                  _revealed
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18),
              onPressed: () => setState(() => _revealed = !_revealed),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (widget.onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 18),
              onPressed: widget.onCopy,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
