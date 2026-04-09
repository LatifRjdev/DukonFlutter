import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String phone;
  final String password;
  const AuthLoginRequested({required this.phone, required this.password});
  @override
  List<Object?> get props => [phone, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String phone;
  final String password;
  final String name;
  final String? email;
  const AuthRegisterRequested({
    required this.phone,
    required this.password,
    required this.name,
    this.email,
  });
  @override
  List<Object?> get props => [phone, password, name, email];
}

class AuthLogoutRequested extends AuthEvent {}
