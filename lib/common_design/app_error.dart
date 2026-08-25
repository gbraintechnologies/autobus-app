import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Categories of failures the app knows how to explain to a user.
enum AppErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  conflict,
  rateLimited,
  insufficientCredits,
  subscriptionRequired,
  server,
  unexpected,
}

/// App-level exception. [userMessage] is always safe to show in the UI.
/// [debugDetail] keeps the raw backend/runtime text for logs only.
class AppException implements Exception {
  const AppException({
    required this.kind,
    this.action = '',
    this.userOverride,
    this.statusCode,
    this.debugDetail,
  });

  final AppErrorKind kind;
  final String action;
  final String? userOverride;
  final int? statusCode;
  final String? debugDetail;

  /// Explicit copy the UI is allowed to show (client-side validation, etc.).
  factory AppException.user(
    String message, {
    AppErrorKind kind = AppErrorKind.validation,
    String action = '',
    int? statusCode,
    String? debugDetail,
  }) {
    return AppException(
      kind: kind,
      action: action,
      userOverride: message,
      statusCode: statusCode,
      debugDetail: debugDetail,
    );
  }

  factory AppException.fromResponse(
    http.Response response, {
    required String action,
  }) {
    final detail = AppErrorMapper.extractDetail(response.body).trim();
    final fromBody = AppErrorMapper.fromMessage(detail);
    if (fromBody == AppErrorKind.network || fromBody == AppErrorKind.timeout) {
      return AppException(
        kind: fromBody,
        action: action,
        statusCode: response.statusCode,
        debugDetail: response.body,
      );
    }
    final kind = AppErrorMapper.fromHttp(response.statusCode, response.body);
    String? override;
    if (kind == AppErrorKind.validation) {
      if (AppErrorMapper.isSafeUserMessage(detail)) {
        override = detail;
      }
    }
    return AppException(
      kind: kind,
      action: action,
      userOverride: override,
      statusCode: response.statusCode,
      debugDetail: response.body,
    );
  }

  /// Auth flows: map a few known backend phrases, otherwise stay generic.
  factory AppException.fromAuthResponse(
    http.Response response, {
    required String action,
  }) {
    final detail = AppErrorMapper.extractDetail(response.body).toLowerCase();
    if (AppErrorMapper.isCredentialFailure(detail)) {
      return AppException.user(
        AppErrorMapper.credentialsCheckMessage,
        kind: AppErrorKind.unauthorized,
        action: action,
        statusCode: response.statusCode,
        debugDetail: response.body,
      );
    }
    if (detail.contains('already') &&
        (detail.contains('email') || detail.contains('exist'))) {
      return AppException.user(
        'An account with this email already exists',
        kind: AppErrorKind.conflict,
        action: action,
        statusCode: response.statusCode,
        debugDetail: response.body,
      );
    }
    if (detail.contains('already') && detail.contains('phone')) {
      return AppException.user(
        'An account with this phone number already exists',
        kind: AppErrorKind.conflict,
        action: action,
        statusCode: response.statusCode,
        debugDetail: response.body,
      );
    }
    if (_containsAny(detail, const ['expired']) &&
        _containsAny(detail, const ['otp', 'code', 'verification'])) {
      return AppException.user(
        'This code has expired. Please request a new one.',
        kind: AppErrorKind.validation,
        action: action,
        statusCode: response.statusCode,
        debugDetail: response.body,
      );
    }
    if (_containsAny(detail, const ['invalid', 'incorrect']) &&
        _containsAny(detail, const ['otp', 'code', 'verification'])) {
      return AppException.user(
        'Invalid verification code',
        kind: AppErrorKind.validation,
        action: action,
        statusCode: response.statusCode,
        debugDetail: response.body,
      );
    }
    if (detail.contains('not found') &&
        _containsAny(detail, const ['account', 'user', 'email', 'phone'])) {
      return AppException.user(
        'We couldn’t find an account with those details',
        kind: AppErrorKind.notFound,
        action: action,
        statusCode: response.statusCode,
        debugDetail: response.body,
      );
    }
    // Login/signup 401s are bad credentials, not an expired session.
    if (response.statusCode == 401) {
      return AppException.user(
        AppErrorMapper.credentialsCheckMessage,
        kind: AppErrorKind.unauthorized,
        action: action,
        statusCode: response.statusCode,
        debugDetail: response.body,
      );
    }
    return AppException.fromResponse(response, action: action);
  }

  factory AppException.fromCause(Object error, {required String action}) {
    if (error is AppException) {
      if (error.action.isNotEmpty || action.isEmpty) return error;
      return AppException(
        kind: error.kind,
        action: action,
        userOverride: error.userOverride,
        statusCode: error.statusCode,
        debugDetail: error.debugDetail,
      );
    }

    final kind = AppErrorMapper.fromCause(error);
    final raw = AppErrorMapper.stripPrefix(error.toString());
    if (kind != AppErrorKind.unexpected) {
      return AppException(kind: kind, action: action, debugDetail: raw);
    }

    if (AppErrorMapper.isCredentialFailure(raw)) {
      return AppException.user(
        AppErrorMapper.credentialsCheckMessage,
        kind: AppErrorKind.unauthorized,
        action: action,
        debugDetail: raw,
      );
    }

    final fromText = AppErrorMapper.fromMessage(raw);
    if (fromText != AppErrorKind.unexpected) {
      return AppException(kind: fromText, action: action, debugDetail: raw);
    }

    if (AppErrorMapper.isSafeUserMessage(raw)) {
      return AppException.user(raw, action: action, debugDetail: raw);
    }

    return AppException(
      kind: AppErrorKind.unexpected,
      action: action,
      debugDetail: raw,
    );
  }

  String get userMessage {
    final override = userOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    return AppErrorMapper.messageFor(kind, action);
  }

  @override
  String toString() => userMessage;
}

/// Maps any thrown object to a short message that is safe to show in the UI.
String userFacingError(Object error, {String? action}) {
  return AppException.fromCause(error, action: action ?? '').userMessage;
}

class AppErrorMapper {
  AppErrorMapper._();

  static const credentialsCheckMessage =
      'Please check your username, email, or PIN and try again.';

  static bool isSignInAction(String action) {
    final t = action.toLowerCase();
    return t.contains('signing in') || t.contains('sign in') || t == 'login';
  }

  static bool isCredentialFailure(String raw) {
    return _containsAny(raw.toLowerCase(), const [
      'invalid email or password',
      'invalid username',
      'invalid password',
      'incorrect password',
      'incorrect pin',
      'invalid email/username',
      'invalid credentials',
    ]);
  }

  static String messageFor(AppErrorKind kind, String action) {
    switch (kind) {
      case AppErrorKind.network:
        return 'Network error. Please check your network.';
      case AppErrorKind.timeout:
        return 'Network error. Please check your network.';
      case AppErrorKind.unauthorized:
        if (isSignInAction(action)) return credentialsCheckMessage;
        return 'Your session expired. Please sign in again.';
      case AppErrorKind.forbidden:
        return 'You don’t have permission to do this.';
      case AppErrorKind.notFound:
        return _withAction(action, fallback: 'We couldn’t find that.');
      case AppErrorKind.validation:
        return _withAction(action, fallback: 'Please check your details and try again.');
      case AppErrorKind.conflict:
        return _withAction(action, fallback: 'This already exists.');
      case AppErrorKind.rateLimited:
        return 'Too many requests. Please wait a moment.';
      case AppErrorKind.insufficientCredits:
        return 'You don’t have enough credits for this.';
      case AppErrorKind.subscriptionRequired:
        return 'An active subscription is required.';
      case AppErrorKind.server:
      case AppErrorKind.unexpected:
        return _withAction(action, fallback: 'Something went wrong. Please try again.');
    }
  }

  static String _withAction(String action, {required String fallback}) {
    final trimmed = action.trim();
    if (trimmed.isEmpty) return fallback;
    return 'Error $trimmed';
  }

  static AppErrorKind fromHttp(int statusCode, String body) {
    final detail = extractDetail(body).toLowerCase();
    if (statusCode == 401) return AppErrorKind.unauthorized;
    if (statusCode == 402 ||
        (detail.contains('insufficient') && detail.contains('credit'))) {
      return AppErrorKind.insufficientCredits;
    }
    if (statusCode == 403) {
      if (detail.contains('subscription')) {
        return AppErrorKind.subscriptionRequired;
      }
      return AppErrorKind.forbidden;
    }
    if (statusCode == 404) return AppErrorKind.notFound;
    if (statusCode == 409) return AppErrorKind.conflict;
    if (statusCode == 429) return AppErrorKind.rateLimited;
    if (statusCode == 400 || statusCode == 422) return AppErrorKind.validation;
    if (statusCode == 408 || statusCode == 504) return AppErrorKind.timeout;
    if (statusCode >= 500) return AppErrorKind.server;
    return AppErrorKind.unexpected;
  }

  static AppErrorKind fromCause(Object error) {
    if (error is TimeoutException) return AppErrorKind.timeout;
    if (error is SocketException ||
        error is HandshakeException ||
        error is TlsException ||
        error is http.ClientException ||
        error is HttpException) {
      return AppErrorKind.network;
    }
    return AppErrorKind.unexpected;
  }

  static AppErrorKind fromMessage(String raw) {
    final t = raw.toLowerCase();
    if (_containsAny(t, const [
      'socketexception',
      'clientexception',
      'handshakeexception',
      'tlsexception',
      'httpexception',
      'failed host lookup',
      'failed to fetch',
      'failed to connect',
      'xmlhttprequest',
      'network is unreachable',
      'unreachable network',
      'no internet',
      'internet connection',
      'network error',
      'network request failed',
      'connection refused',
      'connection reset',
      'connection failed',
      'connection closed',
      'connection abort',
      'connection timed',
      'no address associated',
      'no such host',
      'name or service not known',
      'no route to host',
      'broken pipe',
      'network changed',
    ])) {
      return AppErrorKind.network;
    }
    if (_containsAny(t, const [
      'timeoutexception',
      'timed out',
      'timeout',
    ])) {
      return AppErrorKind.timeout;
    }
    // Credential failures can arrive as 401/"unauthorized" dumps; do not
    // treat those as an expired session.
    if (isCredentialFailure(t)) {
      return AppErrorKind.unexpected;
    }
    if (_containsAny(t, const [
      'session expired',
      'unauthorized',
      'authentication required',
    ]) ||
        RegExp(r'\b401\b').hasMatch(t)) {
      return AppErrorKind.unauthorized;
    }
    if ((t.contains('insufficient') && t.contains('credit')) ||
        RegExp(r'\b402\b').hasMatch(t)) {
      return AppErrorKind.insufficientCredits;
    }
    if (t.contains('subscription') &&
        _containsAny(t, const ['required', 'active', 'upgrade'])) {
      return AppErrorKind.subscriptionRequired;
    }
    if (RegExp(r'\b429\b').hasMatch(t) || t.contains('too many requests')) {
      return AppErrorKind.rateLimited;
    }
    if (RegExp(r'\b403\b').hasMatch(t)) return AppErrorKind.forbidden;
    if (RegExp(r'\b404\b').hasMatch(t)) return AppErrorKind.notFound;
    if (RegExp(r'\b(500|502|503|504)\b').hasMatch(t)) {
      return AppErrorKind.server;
    }
    return AppErrorKind.unexpected;
  }

  static bool isSafeUserMessage(String raw) {
    final t = raw.trim();
    if (t.isEmpty || t.length > 120) return false;
    if (looksLikeBackendDump(t)) return false;
    final lower = t.toLowerCase();
    if (_containsAny(lower, const [
      'exception',
      'stack',
      'traceback',
      'statuscode',
      'status code',
      'socket',
      'null check',
      'typeerror',
      'formatexception',
      'file_url',
      'failed to fetch',
      'xmlhttprequest',
      'errno',
      'uri=',
      'http://',
      'https://',
    ])) {
      return false;
    }
    if (RegExp(r'\b\d{3}\b').hasMatch(t) &&
        _containsAny(lower, const ['failed', 'error', 'http'])) {
      return false;
    }
    return true;
  }

  static bool looksLikeBackendDump(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return true;
    if (t.length > 140) return true;
    final lower = t.toLowerCase();
    if (t.startsWith('{') || t.startsWith('[')) return true;
    if (_containsAny(lower, const [
      'traceback',
      '<html',
      '<!doctype',
      '"detail"',
      'internal server error',
    ])) {
      return true;
    }
    if (RegExp(r'\b\d{3}\b').hasMatch(t) &&
        (t.contains('{') || lower.contains('failed to'))) {
      return true;
    }
    return false;
  }

  static String stripPrefix(String raw) {
    var t = raw.trim();
    const prefixes = ['Exception: ', 'Error: ', 'HttpException: '];
    var changed = true;
    while (changed) {
      changed = false;
      for (final prefix in prefixes) {
        if (t.startsWith(prefix)) {
          t = t.substring(prefix.length).trim();
          changed = true;
        }
      }
    }
    return t;
  }

  static String extractDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final detail = decoded['detail'] ?? decoded['message'] ?? decoded['error'];
        if (detail is Map) {
          return (detail['message'] ?? detail.toString()).toString();
        }
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map) {
            return (first['msg'] ?? first['message'] ?? first.toString())
                .toString();
          }
          return detail.toString();
        }
        if (detail != null) return detail.toString();
      }
    } catch (_) {}
    return body;
  }
}

bool _containsAny(String value, List<String> needles) {
  for (final needle in needles) {
    if (value.contains(needle)) return true;
  }
  return false;
}
