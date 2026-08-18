import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:autobus/config/app_config.dart';
import 'package:autobus/common_bloc/success_bloc.dart';
import '../models/token_model.dart';
import '../services/token_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final TokenService tokenService;
  final SuccessBloc successBloc;

  AuthBloc({TokenService? tokenService, SuccessBloc? successBloc})
    : tokenService = tokenService ?? TokenService(),
      successBloc = successBloc ?? SuccessBloc(),
      super(AuthInitial()) {
    on<LoginEvent>(_onLogin);
    on<SignupEvent>(_onSignup);
    on<CheckAuthEvent>(_onCheckAuth);
    on<LogoutEvent>(_onLogout);
    on<VerifyResetCodeEvent>(_onVerifyResetCode);
    on<ResetPasswordEvent>(_onResetPassword);
    on<CheckEmailExistsEvent>(_onCheckEmailExists);
    on<SendResetCodeEvent>(_onSendResetCode);
    on<RefreshTokenEvent>(_onRefreshToken);
    on<CheckSessionEvent>(_onCheckSession);
    on<VerifySignupOtpEvent>(_onVerifySignupOtp);
    on<ResendSignupOtpEvent>(_onResendSignupOtp);
  }

  // Helper method to get headers with auth token
  Future<Map<String, String>> _getAuthHeaders() async {
    final accessToken = await tokenService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final identifier = event.identifier.trim();
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/v1/auth/signin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': identifier,
          'username': identifier,
          'password': event.password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Parse and save token
        final tokenModel = TokenModel.fromJson(data);
        await tokenService.saveToken(tokenModel);

        // Fetch user data using access token
        final userResponse = await http.get(
          Uri.parse('${AppConfig.backendUrl}/api/v1/user/me'),
          headers: await _getAuthHeaders(),
        );

        if (userResponse.statusCode == 200) {
          final userData = json.decode(userResponse.body);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', json.encode(userData));
          emit(Authenticated(user: userData));
        } else {
          String errorMsg = 'Failed to fetch user data';
          try {
            final errorData = json.decode(userResponse.body);
            if (errorData is Map && errorData['detail'] != null) {
              errorMsg = errorData['detail'];
            }
          } catch (_) {}
          print('User fetch error: ${userResponse.body}');
          emit(AuthError(message: errorMsg, source: 'login'));
        }
      } else {
        String errorMsg = 'Login failed';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['detail'] != null) {
            errorMsg = errorData['detail'].toString();
          }
        } catch (_) {}
        if (errorMsg.toLowerCase().contains('invalid username and password')) {
          errorMsg = 'Invalid email/username or PIN';
        }
        emit(AuthError(message: errorMsg, source: 'login'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString(), source: 'login'));
    }
  }

  Future<void> _onSignup(SignupEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/v1/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          // Backend DTO expects `fullname` (we collect it as username in UI).
          'fullname': event.username,
          'phone': event.phone,
          'email': event.email,
          'password': event.password,
          'company': event.company,
          'ghana_card': event.ghanaCard,
        }),
      );

      if (response.statusCode == 200) {
        // Auto-login after signup so a token is available for the
        // subscription/payment flow that follows immediately.
        final loginResponse = await http.post(
          Uri.parse('${AppConfig.backendUrl}/api/v1/auth/signin'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'email': event.email, 'password': event.password}),
        );

        if (loginResponse.statusCode == 200) {
          final tokenData = json.decode(loginResponse.body);
          final tokenModel = TokenModel.fromJson(tokenData);
          await tokenService.saveToken(tokenModel);
        }
        // Emit Registered regardless — subscription flow proceeds even if
        // auto-login fails (user can still log in manually afterwards).
        emit(
          Registered(
            email: event.email,
            message: 'Account creation was successful!',
          ),
        );
      } else {
        String errorMsg = 'Signup failed';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['detail'] != null) {
            errorMsg = errorData['detail'];
          }
        } catch (_) {}
        emit(AuthError(message: errorMsg, source: 'signup'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString(), source: 'signup'));
    }
  }

  Future<void> _onVerifySignupOtp(
    VerifySignupOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/v1/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': event.phone, 'otp': event.otp}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['success'] == false) {
          emit(
            AuthError(
              message: (data['message'] ?? 'OTP verification failed').toString(),
              source: 'signup_otp',
            ),
          );
          return;
        }
        emit(
          SignupOtpVerified(
            phone: event.phone,
            message: (data is Map && data['message'] != null)
                ? data['message'].toString()
                : 'OTP verified successfully',
          ),
        );
      } else {
        String errorMsg = 'OTP verification failed';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['detail'] != null) {
            final detail = errorData['detail'];
            if (detail is List && detail.isNotEmpty) {
              final first = detail.first;
              errorMsg = first is Map
                  ? (first['msg'] ?? errorMsg).toString()
                  : detail.toString();
            } else {
              errorMsg = detail.toString();
            }
          }
        } catch (_) {}
        emit(AuthError(message: errorMsg, source: 'signup_otp'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString(), source: 'signup_otp'));
    }
  }

  Future<void> _onResendSignupOtp(
    ResendSignupOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/v1/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': event.phone}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        emit(
          SignupOtpResent(
            phone: event.phone,
            message: (data is Map && data['message'] != null)
                ? data['message'].toString()
                : 'OTP resent successfully',
          ),
        );
      } else {
        String errorMsg = 'Failed to resend OTP';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['detail'] != null) {
            errorMsg = errorData['detail'];
          }
        } catch (_) {}
        emit(AuthError(message: errorMsg, source: 'signup_otp_resend'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString(), source: 'signup_otp_resend'));
    }
  }

  Future<void> _onCheckAuth(
    CheckAuthEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userString = prefs.getString('user');

      if (token != null && userString != null) {
        final user = json.decode(userString);
        emit(Authenticated(user: user));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: e.toString(), source: 'check_auth'));
    }
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    try {
      final accessToken = await tokenService.getAccessToken();
      if (accessToken != null) {
        try {
          await http.post(
            Uri.parse('${AppConfig.backendUrl}/api/v1/auth/signout'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          );
        } catch (_) {
          // Best-effort server logout; always clear local session.
        }
      }
      await tokenService.clearTokens();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(message: 'Logout failed: $e', source: 'logout'));
    }
  }

  Future<void> _onResetPassword(
    ResetPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final body = <String, dynamic>{
        'otp': event.code,
        'new_password': event.newPassword,
      };
      if (event.email.isNotEmpty) {
        body['email'] = event.email;
      } else if (event.phone.isNotEmpty) {
        body['phone'] = event.phone;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/v1/auth/no-auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        emit(PasswordResetSuccess(message: 'Password reset successfully'));
      } else {
        String errorMsg = 'Password reset failed';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['detail'] != null) {
            errorMsg = errorData['detail'].toString();
          }
        } catch (_) {}
        emit(AuthError(message: errorMsg, source: 'reset_password'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString(), source: 'reset_password'));
    }
  }

  Future<void> _onCheckEmailExists(
    CheckEmailExistsEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final body = <String, dynamic>{};
      if (event.email.isNotEmpty) {
        body['email'] = event.email;
      } else if (event.phone.isNotEmpty) {
        body['phone'] = event.phone;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/v1/auth/verify-account'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        emit(EmailExists(email: event.email, phone: event.phone));
      } else {
        String errorMsg = 'Account check failed';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['detail'] != null) {
            errorMsg = errorData['detail'].toString();
          }
        } catch (_) {}
        emit(AuthError(message: errorMsg, source: 'check_email'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString(), source: 'check_email'));
    }
  }

  //////////////   OTP Code Handers //////////////////////

  Future<void> _onSendResetCode(
    SendResetCodeEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final body = <String, dynamic>{};
      if (event.email.isNotEmpty) {
        body['email'] = event.email;
      } else if (event.phone.isNotEmpty) {
        body['phone'] = event.phone;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/v1/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        emit(
          ResetCodeSent(
            email: event.email,
            phone: event.phone,
            message: data['message'] ?? 'Reset code sent successfully',
          ),
        );
      } else {
        String errorMsg = 'Failed to send reset code';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['detail'] != null) {
            errorMsg = errorData['detail'].toString();
          }
        } catch (_) {}
        emit(AuthError(message: errorMsg, source: 'send_reset_code'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString(), source: 'send_reset_code'));
    }
  }

  Future<void> _onVerifyResetCode(
    VerifyResetCodeEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final body = <String, dynamic>{
        'otp': event.code,
        // Peek only — password reset endpoint consumes the OTP.
        'consume': false,
      };
      if (event.email.isNotEmpty) {
        body['email'] = event.email;
      } else if (event.phone.isNotEmpty) {
        body['phone'] = event.phone;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/v1/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        emit(
          ResetCodeVerified(
            email: event.email,
            phone: event.phone,
            code: event.code,
          ),
        );
      } else {
        String errorMsg = 'Invalid verification code';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['detail'] != null) {
            errorMsg = errorData['detail'].toString();
          }
        } catch (_) {}
        emit(AuthError(message: errorMsg, source: 'verify_code'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString(), source: 'verify_code'));
    }
  }

  // Token Refresh Handler
  Future<void> _onRefreshToken(
    RefreshTokenEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(TokenRefreshing());
    try {
      final refreshToken =
          event.refreshToken ?? await tokenService.getRefreshToken();

      if (refreshToken == null) {
        emit(SessionExpired());
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final existing = await tokenService.getToken();
        final newTokenModel = TokenModel.fromJson(
          data,
          preserveRefreshToken: existing?.refreshToken,
        );

        // Save new tokens
        await tokenService.updateToken(newTokenModel);

        // Fetch updated user data
        final userResponse = await http.get(
          Uri.parse('${AppConfig.backendUrl}/api/v1/user/me'),
          headers: await _getAuthHeaders(),
        );

        if (userResponse.statusCode == 200) {
          final userData = json.decode(userResponse.body);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', json.encode(userData));
          emit(TokenRefreshed(user: userData));
        } else {
          emit(
            TokenRefreshFailed(
              message: 'Failed to fetch user data after token refresh',
            ),
          );
        }
      } else if (response.statusCode == 401) {
        // Refresh token is invalid or expired
        await tokenService.clearTokens();
        emit(
          SessionExpired(
            message: 'Your session has expired. Please login again.',
          ),
        );
      } else {
        String errorMsg = 'Failed to refresh token';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['detail'] != null) {
            errorMsg = errorData['detail'];
          }
        } catch (_) {}
        emit(TokenRefreshFailed(message: errorMsg));
      }
    } catch (e) {
      emit(TokenRefreshFailed(message: 'Token refresh error: $e'));
    }
  }

  // Session Check Handler
  Future<void> _onCheckSession(
    CheckSessionEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final hasValidSession = await tokenService
          .hasValidSession()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);

      if (!hasValidSession) {
        emit(const Unauthenticated());
        return;
      }

      final isAccessValid = await tokenService.isTokenValid();
      if (!isAccessValid) {
        add(RefreshTokenEvent());
        return;
      }

      // Check if token should be refreshed proactively
      final shouldRefresh = await tokenService.shouldRefreshToken();
      if (shouldRefresh) {
        add(RefreshTokenEvent());
        return;
      }

      // Session is valid, get user data
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');

      if (userString != null) {
        final user = json.decode(userString);
        emit(Authenticated(user: user));
      } else {
        emit(const Unauthenticated());
      }
    } catch (e) {
      emit(const Unauthenticated());
    }
  }
}
