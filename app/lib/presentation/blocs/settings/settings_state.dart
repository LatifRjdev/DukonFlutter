import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
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
  final ThemeMode themeMode;
  const SettingsLoaded(this.user, {this.themeMode = ThemeMode.system});
  @override
  List<Object?> get props => [user, themeMode];

  SettingsLoaded copyWith({User? user, ThemeMode? themeMode}) {
    return SettingsLoaded(
      user ?? this.user,
      themeMode: themeMode ?? this.themeMode,
    );
  }
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
