import 'package:equatable/equatable.dart';

abstract class LoyaltySettingsEvent extends Equatable {
  const LoyaltySettingsEvent();
  @override
  List<Object?> get props => [];
}

class LoyaltySettingsLoadRequested extends LoyaltySettingsEvent {
  final String storeId;
  const LoyaltySettingsLoadRequested(this.storeId);
  @override
  List<Object?> get props => [storeId];
}

class LoyaltySettingsSaveRequested extends LoyaltySettingsEvent {
  final String storeId;
  final Map<String, dynamic> data;
  const LoyaltySettingsSaveRequested(this.storeId, this.data);
  @override
  List<Object?> get props => [storeId, data];
}
