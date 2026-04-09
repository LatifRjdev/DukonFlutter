import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/category/category_bloc.dart';
import '../../blocs/category/category_event.dart';
import '../../blocs/category/category_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading.dart';
import '../../widgets/common/app_error_widget.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  String _getStoreId(BuildContext context) {
    final storeState = context.read<StoreBloc>().state;
    return storeState is StoreLoaded ? storeState.selectedStore?.id ?? '' : '';
  }

  String _pluralizeProducts(int count) {
    if (count == 1) return 'товар';
    if (count >= 2 && count <= 4) return 'товара';
    return 'товаров';
  }

  void _showCategoryDialog(BuildContext context, {String? id, String? currentName}) {
    final controller = TextEditingController(text: currentName);
    final isEditing = id != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Редактировать категорию' : 'Новая категория'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Название',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final storeId = _getStoreId(context);
                if (isEditing) {
                  context.read<CategoryBloc>().add(CategoryUpdateRequested(
                    storeId: storeId,
                    id: id,
                    name: name,
                  ));
                } else {
                  context.read<CategoryBloc>().add(CategoryCreateRequested(
                    storeId: storeId,
                    name: name,
                  ));
                }
                Navigator.pop(ctx);
              }
            },
            child: Text(isEditing ? 'Сохранить' : 'Создать'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String categoryId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text('Вы уверены, что хотите удалить "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final storeId = _getStoreId(context);
              context.read<CategoryBloc>().add(CategoryDeleteRequested(
                storeId: storeId,
                id: categoryId,
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Удалить',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Категории'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<CategoryBloc, CategoryState>(
        builder: (context, state) {
          if (state is CategoryLoading) {
            return const AppLoading();
          }
          if (state is CategoryError) {
            return AppErrorWidget(
              message: state.message,
              onRetry: () {
                final storeId = _getStoreId(context);
                context.read<CategoryBloc>().add(CategoryLoadRequested(storeId));
              },
            );
          }
          if (state is CategoryLoaded) {
            if (state.categories.isEmpty) {
              return AppEmptyState(
                icon: Icons.category_outlined,
                title: 'Нет категорий',
                subtitle: 'Создайте первую категорию для ваших товаров',
                buttonText: 'Создать категорию',
                onButtonPressed: () => _showCategoryDialog(context),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              itemCount: state.categories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final category = state.categories[index];
                return AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMd),
                        ),
                        child: const Icon(Icons.category,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(category.name,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${category.productCount} ${_pluralizeProducts(category.productCount)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.lightTextSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 20, color: AppColors.lightTextSecondary),
                        onPressed: () => _showCategoryDialog(
                          context,
                          id: category.id,
                          currentName: category.name,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: AppColors.error),
                        onPressed: () =>
                            _confirmDelete(context, category.id, category.name),
                      ),
                    ],
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showCategoryDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
