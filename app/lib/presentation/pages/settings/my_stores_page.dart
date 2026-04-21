import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../injection.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_event.dart';
import '../../blocs/store/store_state.dart';

class MyStoresPage extends StatefulWidget {
  const MyStoresPage({super.key});

  @override
  State<MyStoresPage> createState() => _MyStoresPageState();
}

class _MyStoresPageState extends State<MyStoresPage> {
  final _dioClient = sl<DioClient>();
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _dioClient.get('/stores');
      final data = res.data;
      if (data is List) {
        setState(() => _stores = List<Map<String, dynamic>>.from(data));
      } else if (data is Map && data['data'] is List) {
        setState(() => _stores = List<Map<String, dynamic>>.from(data['data'] as List));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String? _selectedStoreId() {
    final storeState = context.read<StoreBloc>().state;
    return storeState is StoreLoaded ? storeState.selectedStore?.id : null;
  }

  static const _categories = {
    'GROCERY': 'Продукты',
    'CLOTHING': 'Одежда',
    'ELECTRONICS': 'Электроника',
    'HARDWARE': 'Стройматериалы',
    'PHARMACY': 'Аптека',
    'OTHER': 'Другое',
  };

  void _showStoreForm({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final addressCtrl = TextEditingController(text: existing?['address'] ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] ?? '');
    String selectedCategory = existing?['category'] as String? ?? 'OTHER';
    final isEdit = existing != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: context.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(isEdit ? 'Редактировать магазин' : 'Добавить магазин',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Название *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(labelText: 'Категория *', border: OutlineInputBorder()),
              items: _categories.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setSheetState(() => selectedCategory = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(labelText: 'Адрес', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Телефон', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: AppConstants.buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _saveStore(
                    id: existing?['id'] as String?,
                    name: nameCtrl.text.trim(),
                    category: selectedCategory,
                    address: addressCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                  );
                },
                child: Text(isEdit ? 'Сохранить' : 'Создать',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      )),
    );
  }

  Future<void> _saveStore({
    String? id,
    required String name,
    required String category,
    required String address,
    required String phone,
  }) async {
    try {
      final payload = {'name': name, 'category': category, 'address': address, 'phone': phone};
      if (id != null) {
        await _dioClient.put('/stores/$id', data: payload);
      } else {
        await _dioClient.post('/stores', data: payload);
      }
      if (!mounted) return;
      await _loadStores();
      if (!mounted) return;
      context.read<StoreBloc>().add(StoreLoadRequested());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _switchStore(String storeId, String storeName) {
    context.read<StoreBloc>().add(StoreSelected(storeId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Магазин "$storeName" выбран'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = _selectedStoreId();

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Мои магазины'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showStoreForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadStores, child: const Text('Повторить')),
                    ],
                  ),
                )
              : _stores.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront_outlined, size: 64,
                              color: context.textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text('Нет магазинов',
                              style: TextStyle(fontSize: 16, color: context.textSecondary)),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showStoreForm(),
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить магазин'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _stores.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final store = _stores[index];
                        final id = store['id'] as String? ?? '';
                        final name = store['name'] as String? ?? '';
                        final address = store['address'] as String? ?? '';
                        final isActive = id == selectedId;

                        return GestureDetector(
                          onTap: () => _switchStore(id, name),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                              border: isActive
                                  ? Border.all(color: AppColors.primary, width: 2)
                                  : Border.all(color: context.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppColors.primary.withValues(alpha: 0.12)
                                        : context.bg,
                                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                                  ),
                                  child: Icon(Icons.storefront_outlined,
                                      color: isActive ? AppColors.primary : context.textSecondary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(name,
                                              style: const TextStyle(
                                                  fontSize: 15, fontWeight: FontWeight.w600)),
                                          if (isActive) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                              ),
                                              child: const Text('Активный',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.primary,
                                                      fontWeight: FontWeight.w600)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (address.isNotEmpty)
                                        Text(address,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: context.textSecondary)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit_outlined,
                                      color: context.textSecondary, size: 18),
                                  onPressed: () => _showStoreForm(existing: store),
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
