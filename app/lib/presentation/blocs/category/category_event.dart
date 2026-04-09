import 'package:equatable/equatable.dart';

abstract class CategoryEvent extends Equatable {
  const CategoryEvent();
  @override
  List<Object?> get props => [];
}

class CategoryLoadRequested extends CategoryEvent {
  final String storeId;
  const CategoryLoadRequested(this.storeId);
  @override
  List<Object?> get props => [storeId];
}

class CategoryCreateRequested extends CategoryEvent {
  final String storeId;
  final String name;
  final String? icon;
  final String? color;
  final String? parentId;
  const CategoryCreateRequested({
    required this.storeId,
    required this.name,
    this.icon,
    this.color,
    this.parentId,
  });
  @override
  List<Object?> get props => [storeId, name];
}

class CategoryUpdateRequested extends CategoryEvent {
  final String storeId;
  final String id;
  final String name;
  const CategoryUpdateRequested({
    required this.storeId,
    required this.id,
    required this.name,
  });
  @override
  List<Object?> get props => [storeId, id, name];
}

class CategoryDeleteRequested extends CategoryEvent {
  final String storeId;
  final String id;
  const CategoryDeleteRequested({required this.storeId, required this.id});
  @override
  List<Object?> get props => [storeId, id];
}
