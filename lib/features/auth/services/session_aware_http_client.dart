import 'package:http/http.dart' as http;
import 'package:autobus/barrel.dart';

/// HTTP Client wrapper with automatic token injection and refresh
/// This client automatically:
/// - Injects Authorization headers with the current access token
/// - Handles 401 responses by attempting token refresh
/// - Retries the original request after successful token refresh
/// - Clears the session and notifies [onSessionExpired] when refresh fails
class SessionAwareHttpClient extends http.BaseClient {
  final TokenService tokenService;
  final String? baseUrl;
  final http.Client _innerClient = http.Client();

  /// Invoked after tokens are cleared because refresh failed (or was missing).
  VoidCallback? onSessionExpired;

  SessionAwareHttpClient({
    required this.tokenService,
    this.baseUrl,
    this.onSessionExpired,
  });

  Future<void> _expireSession() async {
    try {
      await tokenService.clearTokens();
    } catch (_) {}
    onSessionExpired?.call();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Get current access token and add to headers
    final accessToken = await tokenService.getAccessToken();
    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }

    final timeout = _timeoutFor(request.url);
    var response = await _innerClient.send(request).timeout(timeout);

    // If we get a 401, attempt token refresh and retry
    if (response.statusCode == 401) {
      final refreshToken = await tokenService.getRefreshToken();
      final hadSession = accessToken != null || refreshToken != null;

      if (refreshToken != null && await _refreshToken(refreshToken)) {
        final newAccessToken = await tokenService.getAccessToken();
        if (newAccessToken != null) {
          request.headers['Authorization'] = 'Bearer $newAccessToken';
          final clonedRequest = _cloneRequest(request);
          response = await _innerClient.send(clonedRequest).timeout(timeout);
          return response;
        }
      }
      // Refresh missing/failed — do not leave a browseable stale session.
      if (hadSession) {
        await _expireSession();
      }
    }

    return response;
  }

  /// Attempt to refresh the access token using the refresh token
  Future<bool> _refreshToken(String refreshToken) async {
    try {
      final url = baseUrl != null
          ? Uri.parse('$baseUrl/api/v1/auth/refresh')
          : Uri.parse('${AppConfig.backendUrl}/api/v1/auth/refresh');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'refresh_token': refreshToken}),
          )
          .timeout(AppConfig.networkTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final existing = await tokenService.getToken();
        await tokenService.updateToken(
          TokenModel.fromJson(
            data,
            preserveRefreshToken: existing?.refreshToken,
          ),
        );
        return true;
      }
      return false;
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }

  Duration _timeoutFor(Uri url) {
    final path = url.path.toLowerCase();
    if (path.contains('start-dialog') ||
        path.contains('/nlu/') ||
        path.contains('/agent/')) {
      return AppConfig.agentTimeout;
    }
    return AppConfig.networkTimeout;
  }

  /// Clone a request to resend it
  http.BaseRequest _cloneRequest(http.BaseRequest request) {
    http.BaseRequest clonedRequest;

    if (request is http.Request) {
      clonedRequest = http.Request(request.method, request.url)
        ..encoding = request.encoding
        ..bodyBytes = request.bodyBytes;
    } else if (request is http.MultipartRequest) {
      clonedRequest = http.MultipartRequest(request.method, request.url)
        ..fields.addAll(request.fields)
        ..files.addAll(request.files);
    } else if (request is http.StreamedRequest) {
      throw Exception('Cannot clone StreamedRequest');
    } else {
      throw Exception('Cannot clone ${request.runtimeType}');
    }

    clonedRequest
      ..persistentConnection = request.persistentConnection
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..headers.addAll(request.headers);

    return clonedRequest;
  }
}
