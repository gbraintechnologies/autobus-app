import 'package:autobus/barrel.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class TokenService {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';

  final FlutterSecureStorage _secureStorage;

  TokenService({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const _storageTimeout = Duration(seconds: 2);

  Future<String?> _readKey(String key) async {
    try {
      return await _secureStorage.read(key: key).timeout(_storageTimeout);
    } catch (e) {
      print('TokenService read timeout/error for $key: $e');
      return null;
    }
  }

  /// Save token to secure storage
  Future<void> saveToken(TokenModel token) async {
    try {
      await _secureStorage.write(
        key: _tokenKey,
        value: json.encode(token.toJson()),
      );
      await _secureStorage.write(
        key: _tokenExpiryKey,
        value: token.expirationDateTime.toIso8601String(),
      );
    } catch (e) {
      throw Exception('Failed to save token: $e');
    }
  }

  /// Retrieve token from secure storage
  Future<TokenModel?> getToken() async {
    try {
      final tokenJson = await _readKey(_tokenKey);
      if (tokenJson == null) return null;

      final decoded = json.decode(tokenJson) as Map<String, dynamic>;
      return TokenModel.fromJson(decoded);
    } catch (e) {
      print('Failed to retrieve token: $e');
      return null;
    }
  }

  /// Get access token string
  Future<String?> getAccessToken() async {
    try {
      final token = await getToken();
      return token?.accessToken;
    } catch (e) {
      return null;
    }
  }

  /// Get refresh token string
  Future<String?> getRefreshToken() async {
    try {
      final token = await getToken();
      return token?.refreshToken;
    } catch (e) {
      return null;
    }
  }

  /// Update tokens after refresh, preserving refresh token if omitted
  Future<void> updateToken(TokenModel newToken) async {
    try {
      final existing = await getToken();
      final merged = TokenModel(
        accessToken: newToken.accessToken,
        refreshToken: newToken.refreshToken.isNotEmpty
            ? newToken.refreshToken
            : (existing?.refreshToken ?? ''),
        tokenType: newToken.tokenType,
        expiresIn: newToken.expiresIn,
      );
      await saveToken(merged);
    } catch (e) {
      throw Exception('Failed to update token: $e');
    }
  }

  /// Check if token is still valid
  Future<bool> isTokenValid() async {
    try {
      final token = await getToken();
      if (token == null) return false;
      return !token.isExpired;
    } catch (e) {
      return false;
    }
  }

  /// Check if token should be refreshed (within 5 minutes of expiry)
  Future<bool> shouldRefreshToken() async {
    try {
      final token = await getToken();
      if (token == null) return false;
      return token.shouldRefresh;
    } catch (e) {
      return false;
    }
  }

  /// Get token expiration time
  Future<DateTime?> getTokenExpiration() async {
    try {
      final token = await getToken();
      if (token == null) return null;
      return token.expirationDateTime;
    } catch (e) {
      return null;
    }
  }

  /// Get user email from token
  Future<String?> getUserEmail() async {
    try {
      final token = await getToken();
      return token?.userEmail;
    } catch (e) {
      return null;
    }
  }

  /// Clear all tokens (logout)
  Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _tokenExpiryKey);
      await _secureStorage.delete(key: _refreshTokenKey);
    } catch (e) {
      throw Exception('Failed to clear tokens: $e');
    }
  }

  /// Check if user has valid session
  Future<bool> hasValidSession() async {
    try {
      final token = await getToken();
      if (token == null) return false;
      if (!token.isExpired) return true;
      if (token.refreshToken.isEmpty) return false;
      return !JwtDecoder.isExpired(token.refreshToken);
    } catch (e) {
      return false;
    }
  }
}
