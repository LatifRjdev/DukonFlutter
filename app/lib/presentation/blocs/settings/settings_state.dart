import 'package:equatable/equatable.dart';
import '../../../domain/entities/user.dart';

abstract class SettingsState extends Equatable {
  const SettingsState();
  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}
class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final User user;
  const SettingsLoaded(this.user);
  @override
  List<Object?> get props => [user];
}

class SettingsActionSuccess extends SettingsState {
  final String message;
  const SettingsActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class SettingsError extends SettingsState {
  final String message;
  const SettingsError(this.message);
  @override
  List<Object?> get props => [message];
}
