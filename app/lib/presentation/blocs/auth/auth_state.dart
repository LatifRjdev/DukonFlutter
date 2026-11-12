import 'package:equatable/equatable.dart';
import '../../../core/errors/app_message.dart';
import '../../../domain/entities/user.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  const AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

/// The account was deleted. Emitted just before [AuthUnauthenticated] so the
/// screen can confirm it and navigate, while anything watching for a plain
/// sign-out still sees the state it expects.
class AuthAccountDeleted extends AuthState {}

class AuthFailure extends AuthState {
  final AppMessage message;
  const AuthFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class AuthOtpSent extends AuthState {
  final String phone;
  const AuthOtpSent({required this.phone});
  @override
  List<Object?> get props => [phone];
}

class AuthPasswordResetSuccess extends AuthState {}
