import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Short, non-technical copy shown in the UI. Raw errors stay in logs only.
class AppUserMessages {
  static const generic = 'Something went wrong. Please try again.';
  static const offline = 'Check your connection and try again.';
  static const session = 'Your session ended. Please sign in again.';
  static const timeout = 'This is taking too long. Please try again.';
  static const auth =
      "We couldn't sign you in. Check your details and try again.";
  static const signup = "We couldn't create your account. Please try again.";
  static const forbidden = "You don't have access to that.";
  static const notFound = "We couldn't find that right now.";
  static const conflict = 'That option is already in use. Try something else.';
  static const validation = 'Please check your details and try again.';
  static const tooMany =
      'Too many attempts. Please wait a moment and try again.';
  static const server =
      "We're having trouble right now. Please try again shortly.";
  static const upload = "We couldn't upload that. Please try again.";
  static const payment = "We couldn't complete the payment. Please try again.";
  static const save = "We couldn't save that. Please try again.";
  static const load = "We couldn't load this right now. Please try again.";
}

/// Maps exceptions and API text to a safe sentence for SnackBars and empty states.
String userFacingError(
  Object? error, {
  String? fallback,
  String? context,
  String? action,
}) {
  final safeFallback = fallback ?? AppUserMessages.generic;
  if (error == null) return safeFallback;

  final label = context ?? action;
  debugPrint('App error${label == null ? '' : ' [$label]'}: $error');

  if (error is TimeoutException) return AppUserMessages.timeout;
  if (error is SocketException || error is HandshakeException) {
    return AppUserMessages.offline;
  }
  if (error is http.ClientException) return AppUserMessages.offline;
  if (error is FormatException) return safeFallback;

  return sanitizeUserFacingError(error.toString(), fallback: safeFallback);
}

String sanitizeUserFacingError(String raw, {String? fallback}) {
  final safeFallback = fallback ?? AppUserMessages.generic;
  final text = raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  if (text.isEmpty) return safeFallback;

  final lower = text.toLowerCase();

  if (_isOffline(lower)) return AppUserMessages.offline;
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return AppUserMessages.timeout;
  }
  if (_isSession(lower)) return AppUserMessages.session;
  if (lower.contains('forbidden') || lower.contains('403')) {
    return AppUserMessages.forbidden;
  }
  if (lower.contains('too many') ||
      lower.contains('rate limit') ||
      lower.contains('429')) {
    return AppUserMessages.tooMany;
  }
  if (lower.contains('conflict') || lower.contains('already exists')) {
    return AppUserMessages.conflict;
  }
  if (lower.contains('paystack') ||
      lower.contains('payment') ||
      lower.contains('purchase') ||
      lower.contains('storekit') ||
      lower.contains('app store')) {
    return AppUserMessages.payment;
  }
  if (lower.contains('upload')) return AppUserMessages.upload;
  if (lower.contains('invalid email') ||
      lower.contains('invalid username') ||
      lower.contains('invalid password') ||
      lower.contains('invalid pin') ||
      lower.contains('wrong password') ||
      lower.contains('credentials')) {
    return AppUserMessages.auth;
  }
  if (lower.contains('422') ||
      lower.contains('400') ||
      lower.contains('validation') ||
      lower.contains('required field')) {
    return AppUserMessages.validation;
  }
  if (lower.contains('404') || lower.contains('not found')) {
    return AppUserMessages.notFound;
  }
  if (RegExp(r'\b50\d\b').hasMatch(lower) ||
      lower.contains('internal server') ||
      lower.contains('bad gateway')) {
    return AppUserMessages.server;
  }
  if (lower.contains('failed to fetch') ||
      lower.contains('failed to load') ||
      lower.contains('error fetching') ||
      lower.contains('error loading')) {
    return AppUserMessages.load;
  }
  if (lower.contains('failed to') || lower.contains('error updating')) {
    return AppUserMessages.save;
  }

  if (_looksLikeInternalLeak(text, lower)) return safeFallback;

  if (_isAllowlistedCopy(lower)) return _toSentence(text);

  return safeFallback;
}

bool _isOffline(String lower) {
  return lower.contains('socket') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('clientexception') ||
      lower.contains('handshake') ||
      lower.contains('xmlhttprequest') ||
      lower.contains('network error') ||
      lower.contains('offline');
}

bool _isSession(String lower) {
  return lower.contains('session expired') ||
      lower.contains('unauthorized') ||
      lower.contains('not authenticated') ||
      lower.contains('401');
}

bool _looksLikeInternalLeak(String text, String lower) {
  return lower.contains('/api/') ||
      lower.contains('http://') ||
      lower.contains('https://') ||
      lower.contains('traceback') ||
      lower.contains('stack trace') ||
      lower.contains('exception:') ||
      lower.contains('statuscode') ||
      lower.contains('status code') ||
      text.contains('{') ||
      text.contains('[') ||
      text.contains('\\') ||
      lower.contains('.dart') ||
      lower.contains('sql') ||
      lower.contains('postgres') ||
      lower.contains('mongodb') ||
      lower.contains('redis') ||
      lower.contains('null check') ||
      lower.contains('nosuchmethod') ||
      lower.contains('typeerror') ||
      lower.contains('rangeerror') ||
      lower.contains('flutter error') ||
      lower.contains('errno') ||
      RegExp(r'\b\d{3}\b').hasMatch(text) ||
      text.length > 140;
}

bool _isAllowlistedCopy(String lower) {
  const needles = [
    'please try again',
    'please check',
    'please enter',
    'please wait',
    'check your',
    'something went wrong',
    "couldn't",
    'could not',
    'try again',
    'sign in again',
    'session ended',
    'too many attempts',
    'check your connection',
    'check your details',
    "don't have access",
    'please wait a moment',
  ];
  return needles.any(lower.contains);
}

String _toSentence(String text) {
  if (text.endsWith('.') || text.endsWith('!') || text.endsWith('?')) {
    return text;
  }
  return '$text.';
}
