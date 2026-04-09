import 'package:equatable/equatable.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => [];
}

class SettingsProfileRequested extends SettingsEvent {}

class SettingsProfileUpdated extends SettingsEvent {
  final String? name;
  final String? email;
  const SettingsProfileUpdated({this.name, this.email});
  @override
  List<Object?> get props => [name, email];
}

class SettingsPasswordChanged extends SettingsEvent {
  final String currentPassword;
  final String newPassword;
  const SettingsPasswordChanged({required this.currentPassword, required this.newPassword});
  @override
  List<Object?> get props => [currentPassword, newPassword];
}
