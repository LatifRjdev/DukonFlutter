import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/user.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final DioClient _dioClient;

  SettingsBloc({required DioClient dioClient})
      : _dioClient = dioClient,
        super(SettingsInitial()) {
    on<SettingsProfileRequested>(_onProfileRequested);
    on<SettingsProfileUpdated>(_onProfileUpdated);
    on<SettingsPasswordChanged>(_onPasswordChanged);
    on<SettingsThemeChanged>((event, emit) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', event.themeMode.index);
      if (state is SettingsLoaded) {
        emit((state as SettingsLoaded).copyWith(themeMode: event.themeMode));
      }
    });
  }

  Future<void> _onProfileRequested(SettingsProfileRequested event, Emitter<SettingsState> emit) async {
    emit(SettingsLoading());
    try {
      final response = await _dioClient.get(ApiEndpoints.userMe);
      final data = response.data as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      final themeModeIndex = prefs.getInt('theme_mode') ?? ThemeMode.system.index;
      final themeMode = ThemeMode.values[themeModeIndex];
      emit(SettingsLoaded(_mapUser(data), themeMode: themeMode));
    } catch (e) {
      emit(SettingsError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onProfileUpdated(SettingsProfileUpdated event, Emitter<SettingsState> emit) async {
    emit(SettingsLoading());
    try {
      final response = await _dioClient.put(
        ApiEndpoints.userMe,
        data: {
          if (event.name != null) 'name': event.name,
          if (event.email != null) 'email': event.email,
        },
      );
      final data = response.data as Map<String, dynamic>;
      emit(const SettingsActionSuccess('Профиль обновлён'));
      emit(SettingsLoaded(_mapUser(data)));
    } catch (e) {
      emit(SettingsError(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onPasswordChanged(SettingsPasswordChanged event, Emitter<SettingsState> emit) async {
    emit(SettingsLoading());
    try {
      await _dioClient.put(
        ApiEndpoints.changePassword,
        data: {
          'currentPassword': event.currentPassword,
          'newPassword': event.newPassword,
        },
      );
      emit(const SettingsActionSuccess('Пароль изменён'));
    } catch (e) {
      emit(SettingsError(mapErrorToUserMessage(e)));
    }
  }

  User _mapUser(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      avatar: json['avatar'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
