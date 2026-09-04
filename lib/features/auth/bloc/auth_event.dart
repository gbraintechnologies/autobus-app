part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class LoginEvent extends AuthEvent {
  final String identifier;
  final String password;

  const LoginEvent({required this.identifier, required this.password});

  @override
  List<Object> get props => [identifier, password];
}

class SignupEvent extends AuthEvent {
  final String username;
  final String phone;
  final String email;
  final String password;
  final String company;
  final String ghanaCard;

  const SignupEvent({
    required this.email,
    required this.password,
    required this.username,
    required this.phone,
    required this.company,
    required this.ghanaCard,
  });

  @override
  List<Object> get props => [
    username,
    phone,
    email,
    password,
    company,
    ghanaCard,
  ];
}

class VerifySignupOtpEvent extends AuthEvent {
  final String phone;
  final String otp;

  const VerifySignupOtpEvent({required this.phone, required this.otp});

  @override
  List<Object> get props => [phone, otp];
}

class ResendSignupOtpEvent extends AuthEvent {
  final String phone;

  const ResendSignupOtpEvent({required this.phone});

  @override
  List<Object> get props => [phone];
}

class CheckAuthEvent extends AuthEvent {}

class LogoutEvent extends AuthEvent {}

class RequestPasswordResetEvent extends AuthEvent {
  final String email;

  const RequestPasswordResetEvent({required this.email});

  @override
  List<Object> get props => [email];
}

// Add these alongside your existing events
class CheckEmailExistsEvent extends AuthEvent {
  final String email;
  final String phone;

  const CheckEmailExistsEvent({this.email = '', this.phone = ''});

  @override
  List<Object> get props => [email, phone];
}

class SendResetCodeEvent extends AuthEvent {
  final String email;
  final String phone;

  const SendResetCodeEvent({this.email = '', this.phone = ''});

  @override
  List<Object> get props => [email, phone];
}

class VerifyResetCodeEvent extends AuthEvent {
  final String email;
  final String phone;
  final String code;

  const VerifyResetCodeEvent({
    this.email = '',
    this.phone = '',
    required this.code,
  });

  @override
  List<Object> get props => [email, phone, code];
}

class ResetPasswordEvent extends AuthEvent {
  final String email;
  final String phone;
  final String code;
  final String newPassword;

  const ResetPasswordEvent({
    this.email = '',
    this.phone = '',
    required this.code,
    required this.newPassword,
  });

  @override
  List<Object> get props => [email, phone, code, newPassword];
}

// Session Management Events
class RefreshTokenEvent extends AuthEvent {
  final String? refreshToken;

  const RefreshTokenEvent({this.refreshToken});

  @override
  List<Object> get props => [refreshToken ?? ''];
}

class CheckSessionEvent extends AuthEvent {
  const CheckSessionEvent();
}

class SessionExpiredEvent extends AuthEvent {
  const SessionExpiredEvent();
}

class LoadBusinessesEvent extends AuthEvent {
  const LoadBusinessesEvent();
}

class SwitchBusinessEvent extends AuthEvent {
  final String userId;

  const SwitchBusinessEvent({required this.userId});

  @override
  List<Object> get props => [userId];
}

class CreateBusinessEvent extends AuthEvent {
  final String email;
  final String username;
  final String company;

  const CreateBusinessEvent({
    required this.email,
    required this.username,
    this.company = '',
  });

  @override
  List<Object> get props => [email, username, company];
}

class SendDetachOtpEvent extends AuthEvent {
  final String businessId;

  const SendDetachOtpEvent({required this.businessId});

  @override
  List<Object> get props => [businessId];
}

class DetachBusinessEvent extends AuthEvent {
  final String businessId;
  final String otp;
  final String newPassword;

  const DetachBusinessEvent({
    required this.businessId,
    required this.otp,
    required this.newPassword,
  });

  @override
  List<Object> get props => [businessId, otp, newPassword];
}
