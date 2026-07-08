import 'package:equatable/equatable.dart';

abstract class LoyaltySettingsState extends Equatable {
  const LoyaltySettingsState();
  @override
  List<Object?> get props => [];
}

class LoyaltySettingsInitial extends LoyaltySettingsState {}

class LoyaltySettingsLoading extends LoyaltySettingsState {}

class LoyaltySettingsLoaded extends LoyaltySettingsState {
  final Map<String, dynamic> settings;
  const LoyaltySettingsLoaded(this.settings);
  @override
  List<Object?> get props => [settings];
}

class LoyaltySettingsSaved extends LoyaltySettingsState {
  final Map<String, dynamic> settings;
  const LoyaltySettingsSaved(this.settings);
  @override
  List<Object?> get props => [settings];
}

class LoyaltySettingsError extends LoyaltySettingsState {
  final String message;
  const LoyaltySettingsError(this.message);
  @override
  List<Object?> get props => [message];
}
