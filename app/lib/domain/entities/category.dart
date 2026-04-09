import 'package:equatable/equatable.dart';

class Category extends Equatable {
  final String id;
  final String storeId;
  final String name;
  final String? icon;
  final String? color;
  final int sortOrder;
  final String? parentId;
  final int productCount;

  const Category({
    required this.id,
    required this.storeId,
    required this.name,
    this.icon,
    this.color,
    this.sortOrder = 0,
    this.parentId,
    this.productCount = 0,
  });

  @override
  List<Object?> get props => [id, storeId, name, icon, color, sortOrder, parentId];
}
