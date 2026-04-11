import 'package:equatable/equatable.dart';

class StaffMember extends Equatable {
  final String id;
  final String storeId;
  final String? userId;
  final String name;
  final String? phone;
  final String? avatar;
  final String role;
  final double? salary;
  final double? commission;
  final bool isActive;
  final bool isOnShift;
  final double? todaySales;
  final DateTime createdAt;

  const StaffMember({
    required this.id,
    required this.storeId,
    this.userId,
    required this.name,
    this.phone,
    this.avatar,
    required this.role,
    this.salary,
    this.commission,
    this.isActive = true,
    this.isOnShift = false,
    this.todaySales,
    required this.createdAt,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    // Backend returns the raw Prisma Staff shape, where user identity lives
    // under `user.*` rather than flat top-level keys. Tolerate either shape
    // so the list renders regardless of whether the server flattens, falling
    // back to empty string for the required fields instead of crashing with
    // 'Null is not a subtype of String' (FD-P0-002 post-list-decoder).
    final user = json['user'] as Map<String, dynamic>?;
    return StaffMember(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      userId: (json['userId'] as String?) ?? (user?['id'] as String?),
      name: (json['name'] as String?) ?? (user?['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? (user?['phone'] as String?),
      avatar: (json['avatar'] as String?) ?? (user?['avatar'] as String?),
      role: (json['role'] as String?) ?? '',
      salary: (json['salary'] as num?)?.toDouble(),
      commission: (json['commission'] as num?)?.toDouble(),
      isActive: json['isActive'] as bool? ?? true,
      isOnShift: json['isOnShift'] as bool? ?? false,
      todaySales: (json['todaySales'] as num?)?.toDouble() ??
          (json['todaySalesTotal'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id, storeId, name, role];
}
