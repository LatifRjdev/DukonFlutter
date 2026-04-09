import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/category_repository.dart';
import 'category_event.dart';
import 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final CategoryRepository _categoryRepository;

  CategoryBloc({required CategoryRepository categoryRepository})
      : _categoryRepository = categoryRepository,
        super(CategoryInitial()) {
    on<CategoryLoadRequested>(_onLoadRequested);
    on<CategoryCreateRequested>(_onCreateRequested);
    on<CategoryUpdateRequested>(_onUpdateRequested);
    on<CategoryDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onLoadRequested(CategoryLoadRequested event, Emitter<CategoryState> emit) async {
    emit(CategoryLoading());
    try {
      final categories = await _categoryRepository.getCategories(event.storeId);
      emit(CategoryLoaded(categories));
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }

  Future<void> _onCreateRequested(CategoryCreateRequested event, Emitter<CategoryState> emit) async {
    try {
      await _categoryRepository.createCategory(event.storeId, {
        'name': event.name,
        'icon': event.icon,
        'color': event.color,
        'parentId': event.parentId,
      });
      add(CategoryLoadRequested(event.storeId));
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }

  Future<void> _onUpdateRequested(CategoryUpdateRequested event, Emitter<CategoryState> emit) async {
    try {
      await _categoryRepository.updateCategory(event.storeId, event.id, {
        'name': event.name,
      });
      add(CategoryLoadRequested(event.storeId));
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }

  Future<void> _onDeleteRequested(CategoryDeleteRequested event, Emitter<CategoryState> emit) async {
    try {
      await _categoryRepository.deleteCategory(event.storeId, event.id);
      add(CategoryLoadRequested(event.storeId));
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }
}
