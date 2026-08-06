import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/error_messages.dart';
import '../../../injection.dart';
import '../../widgets/common/app_snackbar.dart';

class EcommerceProductMappingPage extends StatefulWidget {
  final String storeId;
  const EcommerceProductMappingPage({super.key, required this.storeId});

  @override
  State<EcommerceProductMappingPage> createState() =>
      _EcommerceProductMappingPageState();
}

class _EcommerceProductMappingPageState
    extends State<EcommerceProductMappingPage> {
  final _dioClient = sl<DioClient>();
  bool _loading = true;
  List<Map<String, dynamic>> _products = [];
  final Map<String, TextEditingController> _controllers = {};
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // GET /stores/:storeId/products defaults to a page size of 20 — pass
      // a high limit so every product is available for mapping, not just
      // the first page.
      final productsRes = await _dioClient.get(
        ApiEndpoints.products(widget.storeId),
        queryParameters: {'limit': 1000},
      );
      final mappingsRes = await _dioClient
          .get('/stores/${widget.storeId}/ecommerce/mappings');

      // GET /stores/:storeId/products returns {data, total, page, limit,
      // totalPages} (see ProductsService.findAll), never a bare list — the
      // `is List` branch below is defensive only.
      final productsJson = (productsRes.data is List)
          ? productsRes.data as List
          : (productsRes.data as Map)['data'] as List? ?? [];
      final mappingsJson = (mappingsRes.data as List?) ?? [];

      final mappingByProductId = {
        for (final m in mappingsJson.cast<Map<String, dynamic>>())
          m['productId'] as String: m['externalProductId'] as String,
      };

      for (final p in productsJson.cast<Map<String, dynamic>>()) {
        final id = p['id'] as String;
        _controllers[id] =
            TextEditingController(text: mappingByProductId[id] ?? '');
      }

      setState(() {
        _products = productsJson.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (mounted) AppSnackbar.error(context, mapErrorToUserMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveMapping(String productId) async {
    final value = _controllers[productId]?.text.trim() ?? '';
    try {
      await _dioClient.put(
        '/stores/${widget.storeId}/ecommerce/mappings/$productId',
        data: {'externalProductId': value.isEmpty ? null : value},
      );
      if (mounted) AppSnackbar.success(context, 'Сохранено');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, mapErrorToUserMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _products
        : _products
            .where((p) =>
                (p['name'] as String? ?? '').toLowerCase().contains(query))
            .toList();

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Сопоставление товаров'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    key: const Key('mapping-search-field'),
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Поиск по названию товара',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            query.isEmpty ? 'Нет товаров' : 'Ничего не найдено',
                            style: TextStyle(color: context.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            final id = product['id'] as String;
                            final name = product['name'] as String? ?? '';
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius:
                                    BorderRadius.circular(AppConstants.radiusLg),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(name,
                                        style: const TextStyle(fontSize: 14)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      key: ValueKey('mapping-external-id-$id'),
                                      controller: _controllers[id],
                                      decoration: const InputDecoration(
                                        hintText: 'Внешний ID',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      onSubmitted: (_) => _saveMapping(id),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check, size: 20),
                                    onPressed: () => _saveMapping(id),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
