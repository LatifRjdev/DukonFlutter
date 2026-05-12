import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/errors/exceptions.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthVerifyRequested>(_onVerifyRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSendOtpRequested>(_onSendOtpRequested);
    on<AuthVerifyOtpRequested>(_onVerifyOtpRequested);
    on<AuthForgotPasswordRequested>(_onForgotPasswordRequested);
    on<AuthResetPasswordRequested>(_onResetPasswordRequested);
  }

  Future<void> _onCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    final isAuth = await _authRepository.isAuthenticated();
    if (isAuth) {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onVerifyRequested(
    AuthVerifyRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Cheap guard — never round-trip if we don't believe we're logged in.
    // Stops a logged-out splash/login screen from pinging /users/me every
    // time the OS resumes the process.
    if (state is! AuthAuthenticated) return;

    try {
      final user = await _authRepository.verifyToken();
      // Re-emit Authenticated with the (possibly updated) user so any
      // listeners pick up a fresh profile. Equatable on AuthAuthenticated
      // means an unchanged user is a no-op for buildWhen consumers.
      emit(AuthAuthenticated(user));
    } on UnauthorizedException {
      // Server says the token is revoked — eject the user. The router's
      // redirect rule + the ApiInterceptor's onSessionExpired callback
      // will land us on /login.
      await _authRepository.logout();
      emit(AuthUnauthenticated());
    } catch (_) {
      // Network errors, server 5xx, etc. don't tell us anything about the
      // auth state — keep the user where they are. The next real API call
      // will surface a 401 if the token genuinely is dead.
    }
  }

  Future<void> _onLoginRequested(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final result = await _authRepository.login(phone: event.phone, password: event.password);
      emit(AuthAuthenticated(result.user));
    } catch (e) {
      emit(AuthFailure(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onRegisterRequested(AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final result = await _authRepository.register(
        phone: event.phone,
        password: event.password,
        name: event.name,
        email: event.email,
      );
      emit(AuthAuthenticated(result.user));
    } catch (e) {
      emit(AuthFailure(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _authRepository.logout();
    emit(AuthUnauthenticated());
  }

  Future<void> _onSendOtpRequested(AuthSendOtpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.sendOtp(event.phone);
      emit(AuthOtpSent(phone: event.phone));
    } catch (e) {
      emit(AuthFailure(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onVerifyOtpRequested(AuthVerifyOtpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final result = await _authRepository.verifyOtp(event.phone, event.code);
      emit(AuthAuthenticated(result.user));
    } catch (e) {
      emit(AuthFailure(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onForgotPasswordRequested(AuthForgotPasswordRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.forgotPassword(event.phone);
      emit(AuthOtpSent(phone: event.phone));
    } catch (e) {
      emit(AuthFailure(mapErrorToUserMessage(e)));
    }
  }

  Future<void> _onResetPasswordRequested(AuthResetPasswordRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.resetPassword(event.phone, event.code, event.newPassword);
      emit(AuthPasswordResetSuccess());
    } catch (e) {
      emit(AuthFailure(mapErrorToUserMessage(e)));
    }
  }
}
