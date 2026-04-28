import 'package:dukonpro/domain/entities/category.dart';

class CategoryModel {
  final String id;
  final String storeId;
  final String name;
  final String? icon;
  final String? color;
  final int sortOrder;
  final String? parentId;
  final int productCount;

  const CategoryModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.icon,
    this.color,
    this.sortOrder = 0,
    this.parentId,
    this.productCount = 0,
  });

  // --- JSON (API) ---

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      parentId: json['parentId'] as String?,
      productCount: json['productCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'icon': icon,
      'color': color,
      'sortOrder': sortOrder,
      'parentId': parentId,
      'productCount': productCount,
    };
  }

  // --- SQLite Map ---

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String?,
      color: map['color'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      parentId: map['parent_id'] as String?,
      productCount: map['product_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store_id': storeId,
      'name': name,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
      'parent_id': parentId,
      'product_count': productCount,
    };
  }

  // --- Domain Entity conversion ---

  factory CategoryModel.fromEntity(Category entity) {
    return CategoryModel(
      id: entity.id,
      storeId: entity.storeId,
      name: entity.name,
      icon: entity.icon,
      color: entity.color,
      sortOrder: entity.sortOrder,
      parentId: entity.parentId,
      productCount: entity.productCount,
    );
  }

  Category toEntity() {
    return Category(
      id: id,
      storeId: storeId,
      name: name,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      parentId: parentId,
      productCount: productCount,
    );
  }
}
