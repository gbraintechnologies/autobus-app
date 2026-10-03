import 'package:autobus/barrel.dart';
import 'package:autobus/common_design/credits_store.dart';
import 'package:autobus/common_design/plain_ai_text.dart';
import 'dart:developer';
import 'package:autobus/features/chat/models/chatwoot_inbox.dart';
import 'package:autobus/features/marketing/models/postiz_integration.dart';
import 'package:autobus/features/marketing/tiktok_creator_info.dart';
import 'package:autobus/features/notifications/models/app_notification.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  final SessionAwareHttpClient httpClient;
  final String baseUrl;

  /// Same folder the backend uses for RAG uploads (`chatbot-files`).
  static const String chatbotStorageFolder = 'chatbot-files';

  /// Catalogue files for product management (`StorageFolder.records_files`).
  static const String productCatalogStorageFolder = 'records-files';

  /// Product listing images (`StorageFolder.product_images` on the API).
  static const String productImageStorageFolder = 'product-images';

  ApiService({required this.httpClient, String? baseUrl})
    : baseUrl = baseUrl?.isNotEmpty == true
          ? baseUrl!
          : '${AppConfig.backendUrl}/api/v1';

  Never _fail(http.Response response, String action) {
    debugPrint('API error [$action] ${response.statusCode}: ${response.body}');
    throw AppException.fromResponse(response, action: action);
  }

  /// FastAPI Decimal values often arrive as JSON strings like `"12.50"`.
  static double _decodeJsonDouble(dynamic data) {
    final direct = parseJsonDouble(data);
    if (direct != null) return direct;
    if (data is Map) {
      return parseJsonDouble(
            data['revenue'] ??
                data['total'] ??
                data['amount'] ??
                data['value'] ??
                data['total_revenue'],
          ) ??
          0.0;
    }
    return 0.0;
  }

  /// GET /api/v1/auth/account-deletion-preview
  Future<Map<String, dynamic>> getAccountDeletionPreview() async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/auth/account-deletion-preview'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    _fail(response, 'loading account deletion details');
  }

  /// POST /api/v1/auth/delete-account — permanently delete this login and linked businesses.
  Future<Map<String, dynamic>> deleteMyAccount({required String password}) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/auth/delete-account'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'password': password}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'status': 'ok'};
    }
    if (response.statusCode == 403) {
      throw AppException.user(
        'Incorrect PIN. Try again.',
        kind: AppErrorKind.forbidden,
        action: 'deleting your account',
        statusCode: response.statusCode,
        debugDetail: response.body,
      );
    }
    _fail(response, 'deleting your account');
  }

  /// Get current user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await httpClient.get(Uri.parse('$baseUrl/user/me'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is! Map) {
          throw Exception('Unexpected profile response');
        }
        final map = Map<String, dynamic>.from(data);
        final nested = map['user'] ?? map['profile'];
        if (nested is Map) return Map<String, dynamic>.from(nested);
        return map;
      } else if (response.statusCode == 401) {
        throw Exception('Session expired');
      } else {
        _fail(response, 'loading your profile');
      }
    } catch (e) {
      throw AppException.fromCause(e, action: 'loading your profile');
    }
  }

  /// PUT /api/v1/user/me/sender-email — From address for outbound customer email.
  Future<Map<String, dynamic>> updateSenderEmail({
    required String senderEmail,
  }) async {
    try {
      final response = await httpClient.put(
        Uri.parse('$baseUrl/user/me/sender-email'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'sender_email': senderEmail.trim()}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      if (response.statusCode == 401) {
        throw Exception('Session expired');
      }
      _fail(response, 'saving your from email');
    } catch (e) {
      throw AppException.fromCause(e, action: 'saving your from email');
    }
  }

  /// GET /api/v1/subscription/status/{phone} — server truth for active subscription.
  Future<Map<String, dynamic>?> getSubscriptionStatusByPhone(
    String phone,
  ) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return null;
    try {
      final uri = Uri.parse(
        '$baseUrl/subscription/status/${Uri.encodeComponent(trimmed)}',
      );
      final response = await httpClient.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      debugPrint('getSubscriptionStatusByPhone: $e');
      return null;
    }
  }

  /// GET /api/v1/credits/me — JWT; wallet + per-feature remaining actions.
  Future<Map<String, dynamic>?> getMyCredits() async {
    try {
      final response = await httpClient.get(Uri.parse('$baseUrl/credits/me'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          CreditsStore.instance.ingest(map);
          return map;
        }
      }
      return null;
    } catch (e) {
      debugPrint('getMyCredits: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCreditPacks() async {
    final response = await httpClient.get(Uri.parse('$baseUrl/credits/packs'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final packs = data is Map ? data['packs'] : data;
      if (packs is List) {
        return packs
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }

  Future<Map<String, dynamic>?> checkoutCreditPack({
    required String packId,
    String? email,
  }) async {
    final body = <String, dynamic>{
      'pack_id': packId,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    };
    final response = await httpClient.post(
      Uri.parse('$baseUrl/credits/checkout'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    _fail(response, 'starting credit checkout');
    return null;
  }

  /// GET /api/v1/subscription/me — JWT; current user's subscription snapshot.
  Future<Map<String, dynamic>?> getMySubscriptionStatus() async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/subscription/me'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      debugPrint('getMySubscriptionStatus: $e');
      return null;
    }
  }

  /// POST /api/v1/subscription/me/cancel — JWT.
  Future<Map<String, dynamic>> cancelMySubscription({String? reason}) async {
    final body = <String, dynamic>{};
    if (reason != null && reason.trim().isNotEmpty) {
      body['reason'] = reason.trim();
    }
    final response = await httpClient.post(
      Uri.parse('$baseUrl/subscription/me/cancel'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    Map<String, dynamic> map;
    try {
      final data = json.decode(response.body);
      if (data is! Map) {
        throw AppException(kind: AppErrorKind.unexpected, action: 'canceling subscription');
      }
      map = Map<String, dynamic>.from(data);
    } catch (_) {
      _fail(response, 'canceling subscription');
    }
    if (response.statusCode != 200) {
      _fail(response, 'canceling subscription');
    }
    return map;
  }

  /// POST /api/v1/subscription/me/enroll-free — JWT.
  /// Grants the complimentary Free plan (iOS / App Review).
  Future<bool> enrollIosFreePlan() async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/subscription/me/enroll-free'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final data = json.decode(response.body);
        if (data is Map && data['success'] == false) return false;
      } catch (_) {}
      return true;
    }
    debugPrint(
      'enrollIosFreePlan: failed (${response.statusCode}) ${response.body}',
    );
    return false;
  }

  /// POST /api/v1/subscription/me/upgrade — JWT.
  Future<bool> upgradeMySubscription({
    required int newPlanId,
    String? paymentReference,
  }) async {
    final body = <String, dynamic>{
      'new_plan_id': newPlanId,
      if (paymentReference != null && paymentReference.trim().isNotEmpty)
        'payment_reference': paymentReference.trim(),
    };
    final response = await httpClient.post(
      Uri.parse('$baseUrl/subscription/me/upgrade'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data['success'] == true) return true;
    }
    return false;
  }

  /// Get all rides/buses
  Future<List<dynamic>> getRides() async {
    try {
      debugPrint('Fetching rides from: $baseUrl/rides');
      final response = await httpClient.get(Uri.parse('$baseUrl/rides'));

      debugPrint('Rides response status: ${response.statusCode}');
      debugPrint('Rides response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Decoded data type: ${data.runtimeType}');

        if (data is Map && data.containsKey('rides')) {
          debugPrint('Found rides in response: ${data['rides'].length} rides');
          return data['rides'];
        }
        debugPrint('Data is not a map or does not contain rides key');
        return data is List ? data : [];
      } else if (response.statusCode == 401) {
        throw Exception('Session expired - unauthorized');
      } else {
        _fail(response, 'loading rides');
      }
    } catch (e) {
      debugPrint('Error fetching rides: $e');
      throw AppException.fromCause(e, action: 'loading rides');
    }
  }

  /// Get ride details by ID
  Future<Map<String, dynamic>> getRideDetails(String rideId) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/rides/$rideId'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired');
      } else if (response.statusCode == 404) {
        throw Exception('Ride not found');
      } else {
        _fail(response, 'loading ride details');
      }
    } catch (e) {
      throw AppException.fromCause(e, action: 'loading ride details');
    }
  }

  /// Create a new booking
  Future<Map<String, dynamic>> createBooking({
    required String rideId,
    required int seats,
    required String pickupLocation,
    required String dropoffLocation,
  }) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/bookings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'ride_id': rideId,
          'seats': seats,
          'pickup_location': pickupLocation,
          'dropoff_location': dropoffLocation,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired');
      } else if (response.statusCode == 400) {
        _fail(response, 'creating booking');
      } else {
        _fail(response, 'creating booking');
      }
    } catch (e) {
      throw AppException.fromCause(e, action: 'creating booking');
    }
  }

  /// Get user bookings
  Future<List<dynamic>> getUserBookings() async {
    try {
      final response = await httpClient.get(Uri.parse('$baseUrl/bookings'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('bookings')) {
          return data['bookings'];
        }
        return data is List ? data : [];
      } else if (response.statusCode == 401) {
        throw Exception('Session expired');
      } else {
        _fail(response, 'loading bookings');
      }
    } catch (e) {
      throw AppException.fromCause(e, action: 'loading bookings');
    }
  }

  /// Cancel a booking
  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final response = await httpClient.delete(
        Uri.parse('$baseUrl/bookings/$bookingId'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired');
      } else if (response.statusCode == 404) {
        throw Exception('Booking not found');
      } else {
        _fail(response, 'canceling booking');
      }
    } catch (e) {
      throw AppException.fromCause(e, action: 'canceling booking');
    }
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateUserProfile({
    String? fullname,
    String? email,
    String? phone,
    String? profilePictureUrl,
    String? nationality,
    DateTime? dateOfBirth,
    String? gender,
    String? staffId,
    String? ghanaCard,
    // Notifications preferences
    bool? inAppNotifications,
    bool? smsNotifications,
    // Business / membership
    String? company,
    String? description,
    String? industry,
    String? currentBranch,
    String? address,
    String? location,
    // Socials
    String? facebookUrl,
    String? whatsappNumber,
    String? linkedinUrl,
    String? twitterUrl,
    String? instagramUrl,
    String? currencyCode,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (fullname != null) body['fullname'] = fullname;
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone.isEmpty ? null : phone;
      if (profilePictureUrl != null) {
        body['profile_picture_url'] = profilePictureUrl;
      }
      if (nationality != null) body['nationality'] = nationality;
      if (dateOfBirth != null) {
        body['date_of_birth'] = dateOfBirth.toIso8601String().split('T').first;
      }
      if (gender != null) body['gender'] = gender;
      if (staffId != null) body['staff_id'] = staffId;
      if (ghanaCard != null) body['ghana_card'] = ghanaCard;

      if (inAppNotifications != null) {
        body['in_app_notifications'] = inAppNotifications;
      }
      if (smsNotifications != null)
        body['sms_notifications'] = smsNotifications;

      if (company != null) body['company'] = company;
      if (description != null) body['description'] = description;
      if (industry != null) body['industry'] = industry;
      if (currentBranch != null) body['current_branch'] = currentBranch;
      if (address != null) body['address'] = address;
      if (location != null) body['location'] = location;

      if (facebookUrl != null) body['facebook_url'] = facebookUrl;
      if (whatsappNumber != null) body['whatsapp_number'] = whatsappNumber;
      if (linkedinUrl != null) body['linkedin_url'] = linkedinUrl;
      if (twitterUrl != null) body['twitter_url'] = twitterUrl;
      if (instagramUrl != null) body['instagram_url'] = instagramUrl;
      if (currencyCode != null) body['currency_code'] = currencyCode;

      final response = await httpClient.put(
        Uri.parse('$baseUrl/user/me'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired');
      } else if (response.statusCode == 400) {
        _fail(response, 'updating profile');
      } else {
        _fail(response, 'updating profile');
      }
    } catch (e) {
      throw AppException.fromCause(e, action: 'updating profile');
    }
  }

  /// Patch current user's notification settings.
  ///
  /// Backend: `PATCH /api/v1/user/me/notification-settings`
  /// Body: `{ "in_app_notification": true, "sms_notification": true }`
  Future<Map<String, dynamic>> patchMyNotificationSettings({
    bool? inAppNotification,
    bool? smsNotification,
  }) async {
    final body = <String, dynamic>{};
    if (inAppNotification != null) {
      body['in_app_notification'] = inAppNotification;
    }
    if (smsNotification != null) body['sms_notification'] = smsNotification;

    final response = await httpClient.patch(
      Uri.parse('$baseUrl/user/me/notification-settings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    } else if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'updating notification settings');
  }

  /// Patch a specific user's notification settings by id.
  ///
  /// Backend: `PATCH /api/v1/user/{user_id}/notification-settings`
  Future<Map<String, dynamic>> patchUserNotificationSettings({
    required String userId,
    bool? inAppNotification,
    bool? smsNotification,
  }) async {
    final body = <String, dynamic>{};
    if (inAppNotification != null) {
      body['in_app_notification'] = inAppNotification;
    }
    if (smsNotification != null) body['sms_notification'] = smsNotification;

    final response = await httpClient.patch(
      Uri.parse('$baseUrl/user/$userId/notification-settings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    } else if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'updating notification settings');
  }

  /// Patch current user's profile image URL only.
  ///
  /// Backend: `PATCH /api/v1/user/me/profile-image`
  /// Body: `{ "profile_picture_url": "https://..." }`
  Future<Map<String, dynamic>> patchMyProfileImage({
    required String profilePictureUrl,
  }) async {
    final response = await httpClient.patch(
      Uri.parse('$baseUrl/user/me/profile-image'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'profile_picture_url': profilePictureUrl}),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    } else if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'updating profile image');
  }

  /// Patch a specific user's profile image URL by id.
  ///
  /// Backend: `PATCH /api/v1/user/{user_id}/profile-image`
  Future<Map<String, dynamic>> patchUserProfileImage({
    required String userId,
    required String profilePictureUrl,
  }) async {
    final response = await httpClient.patch(
      Uri.parse('$baseUrl/user/$userId/profile-image'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'profile_picture_url': profilePictureUrl}),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    } else if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'updating profile image');
  }

  /// Upload a file (image/doc) to storage service.
  ///
  /// Backend: `POST /api/v1/storage/upload` (form-data: `file`)
  /// Returns: `{ file_name, file_url }`
  Future<String> uploadFile({
    required File file,
    String? filename,
    String fieldName = 'file',
    String? storageFolder,
  }) async {
    var uri = Uri.parse('$baseUrl/storage/upload');
    final folder = storageFolder?.trim();
    if (folder != null && folder.isNotEmpty) {
      uri = uri.replace(queryParameters: {'folder': folder});
    }
    final request = http.MultipartRequest('POST', uri);

    final multipartFile = await http.MultipartFile.fromPath(
      fieldName,
      file.path,
      filename: filename,
    );
    request.files.add(multipartFile);

    final streamed = await httpClient.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final url = (data['file_url'] ?? data['url'] ?? '').toString();
      if (url.isEmpty) {
        throw AppException(kind: AppErrorKind.unexpected, action: 'uploading file');
      }
      return url;
    }

    _fail(response, 'uploading file');
  }

  /// Same as [uploadFile] but from bytes (e.g. web `FilePicker` with `withData: true`).
  Future<String> uploadFileBytes({
    required List<int> fileBytes,
    required String filename,
    String fieldName = 'file',
    String? storageFolder,
  }) async {
    var uri = Uri.parse('$baseUrl/storage/upload');
    final folder = storageFolder?.trim();
    if (folder != null && folder.isNotEmpty) {
      uri = uri.replace(queryParameters: {'folder': folder});
    }
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes(fieldName, fileBytes, filename: filename),
    );

    final streamed = await httpClient.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final url = (data['file_url'] ?? data['url'] ?? '').toString();
      if (url.isEmpty) {
        throw AppException(kind: AppErrorKind.unexpected, action: 'uploading file');
      }
      return url;
    }

    _fail(response, 'uploading file');
  }

  /// List available files in storage (typically AI training docs).
  ///
  /// Backend: `GET /api/v1/storage/list?subfolder=chatbot-files/&extensions=txt,pdf,docx`
  /// Returns: `{ "files": [ { file_name, file_url, file_size, file_type, last_modified } ] }`
  Future<List<Map<String, dynamic>>> listStorageFiles({
    String subfolder = 'chatbot-files/',
    List<String> extensions = const ['txt', 'pdf', 'docx'],
    int maxKeys = 200,
  }) async {
    final uri = Uri.parse('$baseUrl/storage/list').replace(
      queryParameters: {
        'subfolder': subfolder,
        'extensions': extensions.join(','),
        'max_keys': maxKeys.toString(),
      },
    );

    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final files =
          (decoded is Map ? (decoded['files'] ?? decoded['data']) : decoded) ??
          const [];
      if (files is List) {
        return files
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return const [];
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'loading files');
  }

  /// List files for the authenticated user under:
  /// `operations/<folder>/<jwtSubject>/`
  ///
  /// Backend: `GET /api/v1/storage/me/files?folder=<folder>`
  /// Returns: `List[FileDTO]` (each includes a presigned URL)
  Future<List<Map<String, dynamic>>> listMyStorageFiles({
    required String folder,
  }) async {
    final normalizedFolder = folder.trim().replaceAll('\\', '/');
    final uri = Uri.parse(
      '$baseUrl/storage/me/files',
    ).replace(queryParameters: {'folder': normalizedFolder});

    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data =
          (decoded is Map ? (decoded['files'] ?? decoded['data']) : decoded) ??
          const [];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return const [];
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'loading files');
  }

  /// Download a user's file.
  ///
  /// Backend: `GET /api/v1/storage/me/download/{file_name}?folder=<folder>`
  /// Note: This may return bytes or a redirect depending on backend.
  Uri myStorageDownloadUri({required String folder, required String fileName}) {
    final normalizedFolder = folder.trim().replaceAll('\\', '/');
    return Uri.parse(
      '$baseUrl/storage/me/download/${Uri.encodeComponent(fileName)}',
    ).replace(queryParameters: {'folder': normalizedFolder});
  }

  /// Delete a user's file.
  ///
  /// Backend: `DELETE /api/v1/storage/me/file/{file_name}?folder=<folder>`
  Future<void> deleteMyStorageFile({
    required String folder,
    required String fileName,
  }) async {
    final normalizedFolder = folder.trim().replaceAll('\\', '/');
    final uri = Uri.parse(
      '$baseUrl/storage/me/file/${Uri.encodeComponent(fileName)}',
    ).replace(queryParameters: {'folder': normalizedFolder});

    final response = await httpClient.delete(uri);
    if (response.statusCode == 200 ||
        response.statusCode == 202 ||
        response.statusCode == 204) {
      return;
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'deleting file');
  }

  /// Preview extractable text for an intelligence file (Word/PDF/etc.).
  ///
  /// Backend: `GET /api/v1/storage/me/rag-preview/{file_name}?folder=<folder>`
  Future<String> previewMyRagFileText({
    required String folder,
    required String fileName,
  }) async {
    final normalizedFolder = folder.trim().replaceAll('\\', '/');
    final uri = Uri.parse(
      '$baseUrl/storage/me/rag-preview/${Uri.encodeComponent(fileName)}',
    ).replace(queryParameters: {'folder': normalizedFolder});

    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final empty = decoded['empty'] == true;
        final text = (decoded['text'] ?? '').toString();
        if (empty || text.trim().isEmpty) {
          throw AppException.user(
            'No readable text could be extracted from this file.',
          );
        }
        final truncated = decoded['truncated'] == true;
        return truncated ? '$text\n\n…' : text;
      }
      throw AppException(kind: AppErrorKind.unexpected, action: 'previewing file');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'previewing file');
  }

  /// Clear all intelligence files + document/website vectors.
  ///
  /// Backend: `DELETE /api/v1/storage/me/clear-intelligence?folder=<folder>`
  Future<String> clearMyIntelligence({
    String folder = chatbotStorageFolder,
  }) async {
    final normalizedFolder = folder.trim().replaceAll('\\', '/');
    final uri = Uri.parse('$baseUrl/storage/me/clear-intelligence').replace(
      queryParameters: {'folder': normalizedFolder},
    );

    final response = await httpClient.delete(uri);
    if (response.statusCode == 200 || response.statusCode == 202) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] != null) {
          return decoded['message'].toString();
        }
      } catch (_) {}
      return 'Intelligence cleared. You can upload again.';
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'clearing intelligence');
  }

  /// Owner copilot chat grounded in this business's live setup.
  ///
  /// Backend: `POST /api/v1/intelligence/chat` (JWT)
  Future<String> sendIntelligenceChat(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw AppException.user('Please type a message.');
    }
    final response = await httpClient.post(
      Uri.parse('$baseUrl/intelligence/chat'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'message': trimmed}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map) {
        final reply = (data['message'] ??
                data['reply'] ??
                data['response'] ??
                data['text'] ??
                '')
            .toString();
        return stripAiMarkdown(reply);
      }
      throw AppException(kind: AppErrorKind.unexpected, action: 'talking to your AI');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'talking to your AI');
  }

  /// POST /api/v1/intelligence/agent — owner agent turn (tools, asks, confirms).
  Future<Map<String, dynamic>> sendAgentTurn({
    String? message,
    List<Map<String, dynamic>> attachments = const [],
    String? confirmId,
    bool? confirmed,
    String? askId,
  }) async {
    final body = <String, dynamic>{};
    final trimmed = message?.trim();
    if (trimmed != null && trimmed.isNotEmpty) body['message'] = trimmed;
    if (attachments.isNotEmpty) body['attachments'] = attachments;
    if (confirmId != null && confirmId.isNotEmpty) {
      body['confirm_id'] = confirmId;
    }
    if (confirmed != null) body['confirmed'] = confirmed;
    if (askId != null && askId.isNotEmpty) body['ask_id'] = askId;

    if (body.isEmpty) {
      throw AppException.user('Please type a message or attach a file.');
    }

    final response = await httpClient
        .post(
          Uri.parse('$baseUrl/intelligence/agent'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        )
        .timeout(
          const Duration(minutes: 11),
          onTimeout: () => throw AppException(
            kind: AppErrorKind.timeout,
            action: 'talking to your AI',
          ),
        );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw AppException(
        kind: AppErrorKind.unexpected,
        action: 'talking to your AI',
      );
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'talking to your AI');
  }

  /// GET /api/v1/intelligence/onboarding — questions + saved business profile.
  Future<Map<String, dynamic>> getBusinessOnboarding() async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/intelligence/onboarding'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'loading your business questionnaire');
  }

  /// POST /api/v1/intelligence/onboarding — save answers and index into Qdrant.
  Future<Map<String, dynamic>> submitBusinessOnboarding(
    Map<String, String> answers,
  ) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/intelligence/onboarding'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'answers': answers}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'saving your business profile');
  }

  /// Download a user's storage file bytes (authenticated).
  Future<List<int>> downloadMyStorageFileBytes({
    required String folder,
    required String fileName,
  }) async {
    final uri = myStorageDownloadUri(folder: folder, fileName: fileName);
    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'downloading file');
  }

  /// Upload a file to the authenticated user's folder.
  ///
  /// Backend: `POST /api/v1/storage/me/upload-multiple?folder=<folder>`
  /// Form-data: `files` (one or more)
  /// Returns: `List[FileDTO]` (each includes a presigned URL)
  Future<Map<String, dynamic>> uploadMyStorageFile({
    required String folder,
    required File file,
    String fieldName = 'files',
    String? filename,
  }) async {
    final normalizedFolder = folder.trim().replaceAll('\\', '/');
    final uri = Uri.parse(
      '$baseUrl/storage/me/upload-multiple',
    ).replace(queryParameters: {'folder': normalizedFolder});

    final request = http.MultipartRequest('POST', uri);
    final multipartFile = await http.MultipartFile.fromPath(
      fieldName,
      file.path,
      filename: filename,
    );
    request.files.add(multipartFile);

    final streamed = await httpClient.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        return Map<String, dynamic>.from(decoded.first as Map);
      }
      if (decoded is Map<String, dynamic>) return decoded;
      throw AppException(kind: AppErrorKind.unexpected, action: 'uploading file');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'uploading file');
  }

  /// Upload one document for RAG indexing (storage + optional Qdrant).
  ///
  /// Backend: `POST /api/v1/storage/me/upload-rag-document?folder=<folder>`
  /// Multipart field name: `file` (single). Requires active subscription on server.
  ///
  /// When [asyncMode] is true, returns immediately with a `job_id` (HTTP 202);
  /// poll [getRagIndexJobStatus] for progress.
  Future<Map<String, dynamic>> uploadRagDocument({
    String folder = chatbotStorageFolder,
    required String filename,
    String? filePath,
    List<int>? fileBytes,
    bool asyncMode = false,
  }) async {
    final trimmedPath = filePath?.trim();
    final hasPath = trimmedPath != null && trimmedPath.isNotEmpty;
    final hasBytes = fileBytes != null && fileBytes.isNotEmpty;
    if (!hasPath && !hasBytes) {
      throw ArgumentError('Provide filePath or non-empty fileBytes');
    }
    if (hasPath && hasBytes) {
      throw ArgumentError('Provide only one of filePath or fileBytes');
    }

    final normalizedFolder = folder.trim().replaceAll('\\', '/');
    final uri = Uri.parse('$baseUrl/storage/me/upload-rag-document').replace(
      queryParameters: {
        'folder': normalizedFolder,
        if (asyncMode) 'async_mode': 'true',
      },
    );

    final request = http.MultipartRequest('POST', uri);
    final http.MultipartFile multipartFile =
        trimmedPath != null && trimmedPath.isNotEmpty
        ? await http.MultipartFile.fromPath(
            'file',
            trimmedPath,
            filename: filename,
          )
        : http.MultipartFile.fromBytes('file', fileBytes!, filename: filename);
    request.files.add(multipartFile);

    final streamed = await httpClient.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200 ||
        response.statusCode == 201 ||
        (asyncMode && response.statusCode == 202)) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw AppException(kind: AppErrorKind.unexpected, action: 'uploading file');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'uploading document');
  }

  /// Scrape a public website and index its text into RAG.
  ///
  /// Backend: `POST /api/v1/storage/me/upload-rag-url?folder=<folder>`
  /// Returns immediately with a `job_id`; poll [getRagIndexJobStatus].
  Future<Map<String, dynamic>> uploadRagUrl({
    required String url,
    String folder = chatbotStorageFolder,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('url must not be empty');
    }

    final normalizedFolder = folder.trim().replaceAll('\\', '/');
    final uri = Uri.parse(
      '$baseUrl/storage/me/upload-rag-url',
    ).replace(queryParameters: {'folder': normalizedFolder});

    final response = await httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': trimmed}),
    );

    if (response.statusCode == 200 ||
        response.statusCode == 201 ||
        response.statusCode == 202) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw AppException(kind: AppErrorKind.unexpected, action: 'indexing website');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'indexing website');
  }

  /// Poll indexing progress for an async file or URL upload.
  ///
  /// Backend: `GET /api/v1/storage/me/rag-index-jobs/{job_id}`
  Future<Map<String, dynamic>> getRagIndexJobStatus(String jobId) async {
    final trimmed = jobId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('jobId must not be empty');
    }

    final uri = Uri.parse(
      '$baseUrl/storage/me/rag-index-jobs/${Uri.encodeComponent(trimmed)}',
    );
    final response = await httpClient.get(uri);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw AppException(kind: AppErrorKind.unexpected, action: 'checking indexing status');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    if (response.statusCode == 404) {
      throw Exception('Indexing job not found');
    }
    _fail(response, 'checking indexing status');
  }

  static String? ragIndexJobId(Map<String, dynamic> startResponse) {
    final id = startResponse['job_id'];
    if (id == null) return null;
    final s = id.toString().trim();
    return s.isEmpty ? null : s;
  }

  static bool ragIndexJobTerminal(Map<String, dynamic> status) {
    final s = (status['status'] ?? '').toString().toLowerCase();
    return s == 'completed' || s == 'failed';
  }

  static bool ragIndexJobSucceeded(Map<String, dynamic> status) {
    return (status['status'] ?? '').toString().toLowerCase() == 'completed';
  }

  /// Get available rides with filters
  Future<List<dynamic>> searchRides({
    required String departure,
    required String destination,
    required DateTime date,
  }) async {
    try {
      final response = await httpClient.get(
        Uri.parse(
          '$baseUrl/rides/search?departure=$departure&destination=$destination&date=${date.toIso8601String().split('T')[0]}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('rides')) {
          return data['rides'];
        }
        return data is List ? data : [];
      } else if (response.statusCode == 401) {
        throw Exception('Session expired');
      } else {
        _fail(response, 'searching rides');
      }
    } catch (e) {
      throw AppException.fromCause(e, action: 'searching rides');
    }
  }

  Future<PaystackInitResult?> initializePaystackTransaction({
    required String email,
    required double amount,
  }) async {
    final token = await TokenService().getAccessToken();
    debugPrint('initializePaystack: token exists — ${token != null}');
    debugPrint('initializePaystack: token — $token');

    final body = json.encode({
      'email': email,
      'amount': (amount * 100).toInt(),
      'reference': DateTime.now().millisecondsSinceEpoch.toString(),
      'callback_url': AppConfig.paystackCallbackUrl,
    });

    debugPrint(
      'initializePaystack: POST $baseUrl/paystack/transaction/initialize',
    );
    debugPrint('initializePaystack: body — $body');

    final response = await httpClient.post(
      Uri.parse('$baseUrl/paystack/transaction/initialize'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    debugPrint('initializePaystack: status — ${response.statusCode}');
    debugPrint('initializePaystack: response — ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return PaystackInitResult.fromJson(data);
    }
    return null;
  }

  Future<bool> verifyPaystackTransaction(String reference) async {
    debugPrint(
      'verifyPaystack: GET $baseUrl/paystack/transaction/verify/$reference',
    );

    final response = await httpClient.get(
      Uri.parse('$baseUrl/paystack/transaction/verify/$reference'), // fix
    );

    debugPrint('verifyPaystack: status — ${response.statusCode}');
    debugPrint('verifyPaystack: response — ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'] == true || data['status'] == 'success';
    }
    return false;
  }

  Future<bool> subscribeToPlan({
    required String planId,
    required String billingId,
    required String reference,
    required String phone,
  }) async {
    final body = <String, dynamic>{
      'plan_id': int.tryParse(planId) ?? planId,
      'billing_id': int.tryParse(billingId) ?? billingId,
      'reference': reference,
      'phone': phone,
    };

    log('subscribeToPlan: POST /api/v1/subscription/subscribe');
    log('subscribeToPlan: request body — $body');

    final response = await httpClient.post(
      Uri.parse('$baseUrl/subscription/subscribe'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    log('subscribeToPlan: status — ${response.statusCode}');
    log('subscribeToPlan: response — ${response.body}');

    return response.statusCode == 200 || response.statusCode == 201;
  }

  /// POST /api/v1/iap/apple/verify — StoreKit 2 signed transaction.
  Future<bool> verifyAppleIapPurchase({
    required String signedTransaction,
    int? planId,
    String? billingId,
    String? phone,
  }) async {
    final body = <String, dynamic>{
      'signed_transaction': signedTransaction,
      if (planId != null) 'plan_id': planId,
      if (billingId != null && billingId.trim().isNotEmpty)
        'billing_id': billingId.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    };
    final response = await httpClient.post(
      Uri.parse('$baseUrl/iap/apple/verify'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    Map<String, dynamic>? map;
    try {
      final data = json.decode(response.body);
      if (data is Map) map = Map<String, dynamic>.from(data);
    } catch (_) {}
    if (response.statusCode == 200 && map?['success'] == true) {
      return true;
    }
    _fail(response, 'verifying purchase');
  }

  /// POST /api/v1/iap/google/verify — Google Play purchase token.
  Future<bool> verifyGooglePlayPurchase({
    required String purchaseToken,
    required String productId,
    String? packageName,
    String? orderId,
  }) async {
    final body = <String, dynamic>{
      'purchase_token': purchaseToken,
      'product_id': productId,
      if (packageName != null && packageName.trim().isNotEmpty)
        'package_name': packageName.trim(),
      if (orderId != null && orderId.trim().isNotEmpty) 'order_id': orderId.trim(),
    };
    final response = await httpClient.post(
      Uri.parse('$baseUrl/iap/google/verify'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    Map<String, dynamic>? map;
    try {
      final data = json.decode(response.body);
      if (data is Map) map = Map<String, dynamic>.from(data);
    } catch (_) {}
    if (response.statusCode == 200 && map?['success'] == true) {
      return true;
    }
    _fail(response, 'verifying purchase');
  }

  Future<List<SubscriptionPlan>> getSubscriptionPlans() async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/subscription/plans'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final raw = data is Map ? (data['plans'] ?? data['items'] ?? data['data']) : data;
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => SubscriptionPlan.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.isActive)
          .toList();
    }
    return [];
  }

  /// Get total revenue
  Future<double> getTotalRevenue() async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/payment/revenue'),
    );
    if (response.statusCode == 200) {
      return _decodeJsonDouble(jsonDecode(response.body));
    }
    return 0.0;
  }

  /// GET /api/v1/payment/revenue/{timeline} — revenue for TODAY, THIS_WEEK, etc.
  Future<double> getRevenueByTimeline(String timeline) async {
    final key = timeline.trim().toUpperCase();
    if (key.isEmpty || key == 'ALL') return getTotalRevenue();
    final response = await httpClient.get(
      Uri.parse('$baseUrl/payment/revenue/$key'),
    );
    if (response.statusCode == 200) {
      return _decodeJsonDouble(jsonDecode(response.body));
    }
    return 0.0;
  }

  /// GET /api/v1/products/inventory/low-stock
  Future<List<Map<String, dynamic>>> getLowStockInventory({
    double threshold = 0.5,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/products/inventory/low-stock',
    ).replace(queryParameters: {'threshold': '$threshold'});
    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is! List) return [];
      return data
          .map((e) {
            if (e is Map<String, dynamic>) return e;
            if (e is Map) return Map<String, dynamic>.from(e);
            return <String, dynamic>{};
          })
          .where((m) => m.isNotEmpty)
          .toList();
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    return [];
  }

  /// GET /api/v1/interventions/list
  Future<List<Map<String, dynamic>>> listInterventions({
    String? status,
    int limit = 50,
  }) async {
    final qp = <String, String>{'limit': '$limit'};
    final trimmedStatus = status?.trim();
    if (trimmedStatus != null && trimmedStatus.isNotEmpty) {
      qp['status'] = trimmedStatus;
    }
    final uri = Uri.parse(
      '$baseUrl/interventions/list',
    ).replace(queryParameters: qp);
    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      return _decodeListPayload(jsonDecode(response.body));
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    return [];
  }

  /// GET /api/v1/billing — Paystack billing charges (order invoices, etc.)
  Future<List<Map<String, dynamic>>> listBillings({
    int page = 0,
    int size = 200,
  }) async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/billing?page=$page&size=$size'),
    );
    if (response.statusCode == 200) {
      return _decodeListPayload(jsonDecode(response.body));
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    return [];
  }

  /// GET /api/v1/billing/payment-methods — saved mobile money / card methods.
  Future<List<Map<String, dynamic>>> listPaymentMethods() async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/billing/payment-methods'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data['payment_methods'] is List) {
        return _decodeMapList(data['payment_methods']);
      }
      return _decodeListPayload(data);
    }
    _fail(response, 'loading payment methods');
  }

  /// POST /api/v1/billing/payment-methods — save a mobile money wallet.
  Future<Map<String, dynamic>> addMobileMoneyPaymentMethod({
    required String accountName,
    required String phoneNumber,
    String provider = 'mtn',
  }) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/billing/payment-methods'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': 'mobile_money',
        'provider': provider,
        'account_name': accountName,
        'phone_number': phoneNumber,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is Map) return Map<String, dynamic>.from(data);
      return const {};
    }
    _fail(response, 'adding payment method');
  }

  /// DELETE /api/v1/billing/payment-methods/{id}
  Future<void> deletePaymentMethod(String id) async {
    final response = await httpClient.delete(
      Uri.parse('$baseUrl/billing/payment-methods/${Uri.encodeComponent(id)}'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) return;
    _fail(response, 'removing payment method');
  }

  /// Get financial transaction history
  Future<List<Map<String, dynamic>>> getFinancials({
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/user/me/financials?page=$page&page_size=$pageSize'),
    );
    if (response.statusCode == 200) {
      return _decodeListPayload(jsonDecode(response.body));
    }
    return [];
  }

  /// Get connected social media accounts
  Future<List<Map<String, dynamic>>> getSocialAccounts() async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/social/accounts'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final accounts = data['accounts'] as List? ?? [];
      return List<Map<String, dynamic>>.from(accounts);
    }
    return [];
  }

  /// Publish a post to connected social accounts
  Future<Map<String, dynamic>> publishSocialPost({
    required List<String> accountIds,
    required String content,
    List<String> mediaUrls = const [],
    String? scheduleTime,
    List<String> hashtags = const [],
  }) async {
    final body = <String, dynamic>{
      'account_ids': accountIds,
      'content': content,
      if (mediaUrls.isNotEmpty)
        'media_urls': mediaUrls
            .map((u) => {'url': u, 'type': 'image'})
            .toList(),
      if (scheduleTime != null) 'schedule_time': scheduleTime,
      if (hashtags.isNotEmpty) 'hashtags': hashtags,
    };

    final response = await httpClient.post(
      Uri.parse('$baseUrl/social/post'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    _fail(response, 'publishing post');
  }

  Future<String> generateAgentContent({
    required String userId,
    required String prompt,
    String agentName = 'marketing',
  }) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/agent/command'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userid': userId,
        'message': prompt,
        'agent_name': agentName,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final String raw;
      if (data is String) {
        raw = data;
      } else if (data is Map) {
        raw = (data['response'] ?? data['message'] ?? data['reply'] ?? '')
            .toString();
      } else {
        raw = data.toString();
      }
      return stripAiMarkdown(raw);
    }
    _fail(response, 'sending your message');
  }

  /// POST /api/v1/nlu/detect — classify intent without running NLU handlers.
  Future<Map<String, dynamic>> detectNluIntent({
    required String message,
    String? currentIntent,
    List<Map<String, String>>? conversation,
  }) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/nlu/detect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        if (currentIntent != null && currentIntent.trim().isNotEmpty)
          'current_intent': currentIntent.trim(),
        if (conversation != null) 'conversation': conversation,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw AppException(kind: AppErrorKind.unexpected, action: 'understanding your message');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'understanding your message');
  }

  Future<Map<String, dynamic>> generateImageMedia({
    required String prompt,
    String? userId,
    String? referenceBase64,
    String? referenceMimeType,
    String? referenceUrl,
    List<Map<String, String>>? references,
    Duration timeout = const Duration(minutes: 11),
  }) async {
    final response = await httpClient
        .post(
          Uri.parse('$baseUrl/media/generate-image'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'prompt': prompt,
            if (userId != null && userId.trim().isNotEmpty) 'user_id': userId,
            if (referenceBase64 != null && referenceBase64.trim().isNotEmpty)
              'reference_base64': referenceBase64,
            if (referenceMimeType != null && referenceMimeType.trim().isNotEmpty)
              'reference_mime_type': referenceMimeType,
            if (referenceUrl != null && referenceUrl.trim().isNotEmpty)
              'reference_url': referenceUrl,
            if (references != null && references.isNotEmpty) 'references': references,
          }),
        )
        .timeout(
          timeout,
          onTimeout: () => throw AppException(kind: AppErrorKind.timeout, action: 'creating media'),
        );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw AppException(kind: AppErrorKind.unexpected, action: 'creating media');
    }

    _fail(response, 'creating media');
  }

  /// [store] When true, the backend downloads the Veo output and uploads a public MP4 URL
  /// (recommended for in-app playback; raw Google URLs often fail on Android ExoPlayer).
  Future<Map<String, dynamic>> generateVideoMedia({
    required String prompt,
    String? userId,
    bool store = false,
    String? referenceBase64,
    String? referenceMimeType,
    String? referenceUrl,
    List<Map<String, String>>? references,
    Duration timeout = const Duration(minutes: 11),
  }) async {
    final uri = Uri.parse(
      '$baseUrl/media/generate-video',
    ).replace(queryParameters: {'store': store.toString()});
    final response = await httpClient
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'prompt': prompt,
            if (userId != null && userId.trim().isNotEmpty) 'user_id': userId,
            if (referenceBase64 != null && referenceBase64.trim().isNotEmpty)
              'reference_base64': referenceBase64,
            if (referenceMimeType != null && referenceMimeType.trim().isNotEmpty)
              'reference_mime_type': referenceMimeType,
            if (referenceUrl != null && referenceUrl.trim().isNotEmpty)
              'reference_url': referenceUrl,
            if (references != null && references.isNotEmpty) 'references': references,
          }),
        )
        .timeout(
          timeout,
          onTimeout: () => throw AppException(kind: AppErrorKind.timeout, action: 'creating media'),
        );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw AppException(kind: AppErrorKind.unexpected, action: 'creating media');
    }

    _fail(response, 'creating media');
  }

  /// GET /api/v1/user/me/notifications — paged list for the current user.
  /// Also accepts the legacy shape from GET /api/v1/notification/.
  Future<List<AppNotification>> getNotifications({
    int page = 1,
    int size = 100,
    String? status,
  }) async {
    final queryParameters = <String, String>{'page': '$page', 'size': '$size'};
    if (status != null && status.trim().isNotEmpty) {
      queryParameters['status'] = status.trim();
    }
    final uri = Uri.parse(
      '$baseUrl/user/me/notifications',
    ).replace(queryParameters: queryParameters);
    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = data is List
          ? data
          : (data is Map
                ? (data['notifications'] ??
                      data['data'] ??
                      data['items'] ??
                      data['results'] ??
                      [])
                : []);
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return const [];
    } else if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'loading notifications');
  }

  Future<List<AppNotification>> getUnreadNotifications({
    int page = 1,
    int size = 100,
  }) async {
    final items = await getNotifications(
      page: page,
      size: size,
      status: 'UNREAD',
    );
    return items.where((n) => !n.read).toList();
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final items = await getUnreadNotifications();
      return items.length;
    } catch (_) {
      return 0;
    }
  }

  /// PATCH /api/v1/notification/{id}/read
  Future<AppNotification> markNotificationAsRead(String notificationId) async {
    final response = await httpClient.patch(
      Uri.parse('$baseUrl/notification/$notificationId/read'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return AppNotification.fromJson(data);
      }
      if (data is Map) {
        return AppNotification.fromJson(Map<String, dynamic>.from(data));
      }
      throw AppException(kind: AppErrorKind.unexpected, action: 'updating notification');
    } else if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'updating notification');
  }

  /// GET /api/v1/social/postiz/integrations — connected Postiz channels.
  Future<List<PostizIntegration>> listPostizIntegrations() async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/social/postiz/integrations'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> raw;
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        const keys = [
          'integrations',
          'items',
          'data',
          'value',
          'results',
          'channels',
        ];
        List<dynamic>? found;
        for (final k in keys) {
          final v = data[k];
          if (v is List) {
            found = v;
            break;
          }
        }
        raw = found ?? [];
      } else {
        return [];
      }
      final parsed = <PostizIntegration>[];
      for (final row in raw) {
        if (row is! Map) continue;
        try {
          parsed.add(
            PostizIntegration.fromJson(Map<String, dynamic>.from(row)),
          );
        } catch (_) {}
      }
      return parsed.where((i) => i.isActive).toList();
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    // No Postiz org / API key yet — treat as nothing linked.
    if (response.statusCode == 404) {
      return [];
    }
    _fail(response, 'loading linked social media');
  }

  /// DELETE /api/v1/social/postiz/integrations/{id} — unlink a Postiz channel.
  Future<void> deletePostizIntegration(String integrationId) async {
    final id = integrationId.trim();
    if (id.isEmpty) {
      throw AppException(kind: AppErrorKind.unexpected, action: 'disconnecting outlet');
    }
    final response = await httpClient.delete(
      Uri.parse(
        '$baseUrl/social/postiz/integrations/${Uri.encodeComponent(id)}',
      ),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    if (response.statusCode == 404) {
      return;
    }
    _fail(response, 'disconnecting outlet');
  }

  /// DELETE /api/v1/instagram/accounts/{id} — unlink Autobus Instagram account.
  Future<void> deleteInstagramAccount(String accountId) async {
    final id = accountId.trim();
    if (id.isEmpty) {
      throw AppException(kind: AppErrorKind.unexpected, action: 'connecting Instagram');
    }
    final response = await httpClient.delete(
      Uri.parse('$baseUrl/instagram/accounts/${Uri.encodeComponent(id)}'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    if (response.statusCode == 404) {
      return;
    }
    _fail(response, 'disconnecting Instagram');
  }

  /// DELETE /api/v1/whatsapp/accounts/{id} — unlink Autobus WhatsApp account.
  Future<void> deleteWhatsAppAccount(String accountId) async {
    final id = accountId.trim();
    if (id.isEmpty) {
      throw AppException(kind: AppErrorKind.unexpected, action: 'connecting WhatsApp');
    }
    final response = await httpClient.delete(
      Uri.parse('$baseUrl/whatsapp/accounts/${Uri.encodeComponent(id)}'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    if (response.statusCode == 404) {
      return;
    }
    _fail(response, 'disconnecting WhatsApp');
  }

  /// POST /api/v1/social/postiz/auto-login — Postiz LOCAL login + integrations URL.
  Future<PlatformEmbedSession> postizAutoLogin() async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/social/postiz/auto-login'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return PlatformEmbedSession.fromPostizAutoLogin(data);
      }
      if (data is Map) {
        return PlatformEmbedSession.fromPostizAutoLogin(
          Map<String, dynamic>.from(data),
        );
      }
      throw AppException(kind: AppErrorKind.unexpected, action: 'connecting Postiz');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'connecting Postiz');
  }

  /// POST /api/v1/social/postiz/posts — create or schedule via Postiz Public API.
  ///
  /// [payload] is passed through to Postiz `POST /api/public/v1/posts`.
  /// When [agentName] is `digital_marketing`, the server archives caption/media for assets.
  Future<Map<String, dynamic>> createPostizPost(
    Map<String, dynamic> payload, {
    String? agentName,
  }) async {
    final uri = Uri.parse('$baseUrl/social/postiz/posts').replace(
      queryParameters: (agentName != null && agentName.trim().isNotEmpty)
          ? {'agent_name': agentName.trim()}
          : null,
    );
    final response = await httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'ok': true, 'value': data};
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'publishing post');
  }

  /// GET /api/v1/social/postiz/tiktok/creator-info
  Future<TikTokCreatorInfo> getTikTokCreatorInfo(String integrationId) async {
    final id = integrationId.trim();
    final response = await httpClient.get(
      Uri.parse('$baseUrl/social/postiz/tiktok/creator-info').replace(
        queryParameters: {'integration_id': id},
      ),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return TikTokCreatorInfo.fromJson(data);
      if (data is Map) {
        return TikTokCreatorInfo.fromJson(Map<String, dynamic>.from(data));
      }
      throw AppException(kind: AppErrorKind.unexpected, action: 'loading TikTok account');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'loading TikTok account');
  }

  /// GET /api/v1/social/postiz/tiktok/publish-status
  Future<TikTokPublishStatus> getTikTokPublishStatus({
    required String integrationId,
    String? publishId,
  }) async {
    final params = <String, String>{'integration_id': integrationId.trim()};
    final pid = publishId?.trim() ?? '';
    if (pid.isNotEmpty) params['publish_id'] = pid;
    final response = await httpClient.get(
      Uri.parse('$baseUrl/social/postiz/tiktok/publish-status').replace(
        queryParameters: params,
      ),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return TikTokPublishStatus.fromJson(data);
      if (data is Map) {
        return TikTokPublishStatus.fromJson(Map<String, dynamic>.from(data));
      }
      throw AppException(kind: AppErrorKind.unexpected, action: 'checking TikTok post');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'checking TikTok post');
  }

  /// GET /api/v1/social/postiz/posts — recent Postiz posts for publish status.
  Future<List<Map<String, dynamic>>> listPostizPosts({
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{};
    if (startDate != null && startDate.trim().isNotEmpty) {
      params['start_date'] = startDate.trim();
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      params['end_date'] = endDate.trim();
    }
    final response = await httpClient.get(
      Uri.parse('$baseUrl/social/postiz/posts').replace(
        queryParameters: params.isEmpty ? null : params,
      ),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> raw;
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        const keys = ['posts', 'items', 'data', 'value', 'results'];
        List<dynamic>? found;
        for (final k in keys) {
          final v = data[k];
          if (v is List) {
            found = v;
            break;
          }
        }
        raw = found ?? [];
      } else {
        return [];
      }
      return [
        for (final row in raw)
          if (row is Map) Map<String, dynamic>.from(row),
      ];
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    if (response.statusCode == 404) {
      return [];
    }
    _fail(response, 'loading post status');
  }

  /// GET /api/v1/social/connect/{platform} — OAuth or Postiz embed for Facebook, etc.
  Future<PlatformEmbedSession> initiateSocialConnect(String platform) async {
    final slug = platform.trim().toLowerCase();
    final response = await httpClient.get(
      Uri.parse('$baseUrl/social/connect/$slug').replace(
        queryParameters: const {'return_to': 'app'},
      ),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      Map<String, dynamic>? map;
      if (data is Map<String, dynamic>) {
        map = data;
      } else if (data is Map) {
        map = Map<String, dynamic>.from(data);
      }
      if (map != null) {
        final provider = (map['provider'] ?? '').toString().toUpperCase();
        final authUrl = (map['authorization_url'] ?? map['auth_url'] ?? '')
            .toString()
            .trim();
        if (authUrl.toLowerCase().contains('chatwoot')) {
          throw AppException(
            kind: AppErrorKind.unexpected,
            action: 'connecting $slug',
          );
        }
        if (provider == 'POSTIZ') {
          final session = PlatformEmbedSession.fromSocialConnect(map);
          if (!session.directOauth) {
            throw AppException(
              kind: AppErrorKind.unexpected,
              action: 'connecting $slug',
            );
          }
          return session;
        }
        if (authUrl.isNotEmpty) {
          return PlatformEmbedSession(authorizationUrl: authUrl);
        }
        throw AppException(
          kind: AppErrorKind.unexpected,
          action: 'connecting $slug',
        );
      }
      throw AppException(kind: AppErrorKind.unexpected, action: 'connecting account');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'connecting $slug');
  }

  /// GET /api/v1/chatwoot/session — Chatwoot login + inbox settings URL.
  Future<PlatformEmbedSession> getChatwootSession() async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/chatwoot/session'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return PlatformEmbedSession.fromChatwoot(data);
      }
      if (data is Map) {
        return PlatformEmbedSession.fromChatwoot(
          Map<String, dynamic>.from(data),
        );
      }
      throw AppException(kind: AppErrorKind.unexpected, action: 'connecting Chatwoot');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'connecting Chatwoot');
  }

  /// GET /api/v1/chatwoot/channels/{channel}/link — per-channel Chatwoot embed.
  Future<PlatformEmbedSession> getChatwootChannelLink(String channel) async {
    final slug = channel.trim().toLowerCase();
    final response = await httpClient.get(
      Uri.parse('$baseUrl/chatwoot/channels/$slug/link'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return PlatformEmbedSession.fromChatwoot(data);
      }
      if (data is Map) {
        return PlatformEmbedSession.fromChatwoot(
          Map<String, dynamic>.from(data),
        );
      }
      throw AppException(kind: AppErrorKind.unexpected, action: 'linking channel');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'linking channel');
  }

  /// GET /api/v1/whatsapp/connect — Meta WhatsApp Embedded Signup URL.
  Future<PlatformEmbedSession> getWhatsAppConnectSession() async {
    // JS SDK on the Meta-whitelisted callback URL. Do not use launch=redirect:
    // Facebook's OAuth dialog then sends a redirect_uri that is not in
    // Client OAuth Settings ("URL blocked").
    final query = <String, String>{
      'return_to': 'app',
    };
    final response = await httpClient.get(
      Uri.parse('$baseUrl/whatsapp/connect').replace(queryParameters: query),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final authUrl = (map['authorization_url'] ?? '').toString();
        if (authUrl.isEmpty) {
          throw AppException(kind: AppErrorKind.unexpected, action: 'connecting WhatsApp');
        }
        return PlatformEmbedSession(
          authorizationUrl: authUrl,
          message: map['message']?.toString(),
        );
      }
      throw AppException(kind: AppErrorKind.unexpected, action: 'connecting WhatsApp');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'connecting WhatsApp');
  }

  /// GET /api/v1/whatsapp/accounts — Meta-linked WhatsApp numbers.
  Future<List<Map<String, dynamic>>> listWhatsAppAccounts() async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/whatsapp/accounts'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    return [];
  }

  /// GET /api/v1/instagram/connect — Instagram Business Login authorize URL.
  Future<PlatformEmbedSession> getInstagramConnectSession() async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/instagram/connect').replace(
        queryParameters: const {'return_to': 'app'},
      ),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final authUrl = (map['authorization_url'] ?? '').toString();
        if (authUrl.isEmpty) {
          throw AppException(kind: AppErrorKind.unexpected, action: 'connecting Instagram');
        }
        return PlatformEmbedSession(
          authorizationUrl: authUrl,
          message: map['message']?.toString(),
        );
      }
      throw AppException(kind: AppErrorKind.unexpected, action: 'connecting Instagram');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'connecting Instagram');
  }

  /// GET /api/v1/instagram/accounts — Instagram Business Login linked accounts.
  Future<List<Map<String, dynamic>>> listInstagramAccounts() async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/instagram/accounts'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    return [];
  }

  /// POST /api/v1/instagram/posts — publish via Autobus Instagram Business Login.
  Future<Map<String, dynamic>> publishInstagramPost({
    required String accountId,
    required String caption,
    required List<String> mediaUrls,
  }) async {
    final id = accountId.trim();
    if (id.isEmpty) {
      throw AppException(kind: AppErrorKind.unexpected, action: 'connecting Instagram');
    }
    final urls =
        mediaUrls.map((u) => u.trim()).where((u) => u.isNotEmpty).toList();
    if (urls.isEmpty) {
      throw AppException.user('Add an image or video before posting to Instagram');
    }
    final response = await httpClient.post(
      Uri.parse('$baseUrl/instagram/posts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'account_id': id,
        'caption': caption,
        'media_urls': urls,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'ok': true, 'value': data};
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'publishing to Instagram');
  }

  /// GET /api/v1/sms-sender-ids — current user's SMS sender ID registrations.
  Future<List<Map<String, dynamic>>> listSmsSenderIds() async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/sms-sender-ids'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    return [];
  }

  /// POST /api/v1/sms-sender-ids — register a sender ID for team approval.
  Future<Map<String, dynamic>> registerSmsSenderId({
    required String senderId,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'sender_id': senderId.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    final response = await httpClient.post(
      Uri.parse('$baseUrl/sms-sender-ids'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw AppException(kind: AppErrorKind.unexpected, action: 'registering sender ID');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'registering sender ID');
  }

  /// GET /api/v1/chatwoot/status — env + workspace mapping (no subscription required).
  Future<Map<String, dynamic>> getChatwootStatus() async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/chatwoot/status'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw AppException(kind: AppErrorKind.unexpected, action: 'loading chat status');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'loading chat status');
  }

  /// GET /api/v1/orders/me — current user's orders; optional [orderStatus] filter.
  Future<List<Map<String, dynamic>>> listOrders({
    int skip = 0,
    int limit = 100,
    String? orderStatus,
  }) async {
    final qp = <String, String>{'skip': '$skip', 'limit': '$limit'};
    final trimmedStatus = orderStatus?.trim();
    if (trimmedStatus != null && trimmedStatus.isNotEmpty) {
      qp['order_status'] = trimmedStatus;
    }
    final uri = Uri.parse('$baseUrl/orders/me').replace(queryParameters: qp);
    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      return _decodeListPayload(jsonDecode(response.body));
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'loading orders');
  }

  /// GET /api/v1/products/me — current user's products; optional [category] filter.
  Future<List<Map<String, dynamic>>> listProducts({
    int skip = 0,
    int limit = 100,
    String? category,
  }) async {
    final qp = <String, String>{'skip': '$skip', 'limit': '$limit'};
    final trimmedCategory = category?.trim();
    if (trimmedCategory != null && trimmedCategory.isNotEmpty) {
      qp['category'] = trimmedCategory;
    }
    final uri = Uri.parse('$baseUrl/products/me').replace(queryParameters: qp);
    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      return _decodeListPayload(jsonDecode(response.body));
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'loading products');
  }

  /// GET /api/v1/products/{productId}
  Future<Map<String, dynamic>> getProduct(String productId) async {
    final uri = Uri.parse(
      '$baseUrl/products/${Uri.encodeComponent(productId)}',
    );
    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    if (response.statusCode == 404) {
      throw Exception('Product not found');
    }
    _fail(response, 'loading product');
  }

  /// POST /api/v1/products — create a product (inventory is created on the server).
  ///
  /// [photos] and/or [videos] must contain at least one media URL.
  Future<Map<String, dynamic>> createProduct({
    required String name,
    String? description,
    required double price,
    String? category,
    required String condition,
    int? numberInStock,
    String? link,
    List<String> photos = const [],
    List<String> videos = const [],
  }) async {
    final urls = photos
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final videoUrls = videos
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (urls.isEmpty && videoUrls.isEmpty) {
      throw ArgumentError('At least one product image or video is required');
    }

    final body = <String, dynamic>{
      'name': name.trim(),
      'price': price,
      'condition': condition.trim(),
    };
    if (urls.isNotEmpty) body['photos'] = urls;
    if (videoUrls.isNotEmpty) body['videos'] = videoUrls;
    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }
    if (category != null && category.trim().isNotEmpty) {
      body['category'] = category.trim();
    }
    if (numberInStock != null) body['number_in_stock'] = numberInStock;
    if (link != null && link.trim().isNotEmpty) body['link'] = link.trim();

    final uri = Uri.parse('$baseUrl/products');
    final response = await httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'creating product');
  }

  /// PUT /api/v1/products/{productId}
  Future<Map<String, dynamic>> updateProduct(
    String productId, {
    String? name,
    String? description,
    double? price,
    String? category,
    String? condition,
    int? numberInStock,
    String? photo,
    String? link,
  }) async {
    final body = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) body['name'] = name.trim();
    if (description != null) body['description'] = description.trim();
    if (price != null) body['price'] = price;
    if (category != null) body['category'] = category.trim();
    if (condition != null && condition.trim().isNotEmpty) {
      body['condition'] = condition.trim();
    }
    if (numberInStock != null) body['number_in_stock'] = numberInStock;
    if (photo != null && photo.trim().isNotEmpty) body['photo'] = photo.trim();
    if (link != null) body['link'] = link.trim();

    final uri = Uri.parse(
      '$baseUrl/products/${Uri.encodeComponent(productId)}',
    );
    final response = await httpClient.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'updating product');
  }

  /// DELETE /api/v1/products/{productId}
  Future<void> deleteProduct(String productId) async {
    final uri = Uri.parse(
      '$baseUrl/products/${Uri.encodeComponent(productId)}',
    );
    final response = await httpClient.delete(uri);
    if (response.statusCode == 204 || response.statusCode == 200) {
      return;
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    if (response.statusCode == 404) {
      throw Exception('Product not found');
    }
    _fail(response, 'deleting product');
  }

  /// GET /api/v1/products/{productId}/photos
  Future<List<Map<String, dynamic>>> listProductPhotos(
    String productId,
  ) async {
    final uri = Uri.parse(
      '$baseUrl/products/${Uri.encodeComponent(productId)}/photos',
    );
    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    if (response.statusCode == 404) {
      throw Exception('Product not found');
    }
    _fail(response, 'loading product photos');
  }

  /// POST /api/v1/products/{productId}/photos — upload multiple image files.
  Future<Map<String, dynamic>> uploadProductPhotos(
    String productId, {
    List<File>? files,
    List<({List<int> bytes, String filename})>? fileBytes,
  }) async {
    final fileList = files ?? const <File>[];
    final bytesList = fileBytes ?? const <({List<int> bytes, String filename})>[];
    if (fileList.isEmpty && bytesList.isEmpty) {
      throw ArgumentError('At least one image file is required');
    }

    final uri = Uri.parse(
      '$baseUrl/products/${Uri.encodeComponent(productId)}/photos',
    );
    final request = http.MultipartRequest('POST', uri);
    for (final file in fileList) {
      request.files.add(
        await http.MultipartFile.fromPath('files', file.path),
      );
    }
    for (final entry in bytesList) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          entry.bytes,
          filename: entry.filename,
        ),
      );
    }

    final streamed = await httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'uploading product photos');
  }

  /// DELETE /api/v1/products/{productId}/photos/{imageId}
  Future<Map<String, dynamic>> deleteProductPhoto(
    String productId,
    String imageId,
  ) async {
    final uri = Uri.parse(
      '$baseUrl/products/${Uri.encodeComponent(productId)}/photos/${Uri.encodeComponent(imageId)}',
    );
    final response = await httpClient.delete(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'deleting product photo');
  }

  /// PATCH /api/v1/products/{productId}/photos/{imageId}/primary
  Future<Map<String, dynamic>> setPrimaryProductPhoto(
    String productId,
    String imageId,
  ) async {
    final uri = Uri.parse(
      '$baseUrl/products/${Uri.encodeComponent(productId)}/photos/${Uri.encodeComponent(imageId)}/primary',
    );
    final response = await httpClient.patch(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'updating cover photo');
  }

  /// GET /api/v1/conversations/session/{sessionId} — full session with history.
  Future<Map<String, dynamic>> getConversationSession(int sessionId) async {
    final uri = Uri.parse('$baseUrl/conversations/session/$sessionId');
    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    if (response.statusCode == 404) {
      throw Exception('Conversation not found');
    }
    _fail(response, 'loading conversation');
  }

  /// GET /api/v1/conversations/for-order/{orderId} — customer chat for an order.
  Future<Map<String, dynamic>> getConversationForOrder(String orderId) async {
    final uri = Uri.parse(
      '$baseUrl/conversations/for-order/${Uri.encodeComponent(orderId)}',
    );
    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    if (response.statusCode == 404) {
      throw Exception('No conversation found for this order');
    }
    _fail(response, 'loading order conversation');
  }

  /// POST /api/v1/interventions/human-message — agent reply during intervention.
  Future<Map<String, dynamic>> sendInterventionHumanMessage(
    String message, {
    int? sessionId,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw AppException.user('Message cannot be empty');
    }
    final qp = <String, String>{'message': trimmed};
    if (sessionId != null) {
      qp['session_id'] = '$sessionId';
    }
    final uri = Uri.parse(
      '$baseUrl/interventions/human-message',
    ).replace(queryParameters: qp);
    final response = await httpClient.post(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final conv = data is Map ? data['conversation'] : null;
      if (conv is Map<String, dynamic>) return conv;
      if (conv is Map) return Map<String, dynamic>.from(conv);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'success': true};
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'sending message');
  }

  /// POST /api/v1/conversations/session/{sessionId}/complete
  Future<Map<String, dynamic>> completeConversationSession(
    int sessionId,
  ) async {
    final uri = Uri.parse(
      '$baseUrl/conversations/session/$sessionId/complete',
    );
    final response = await httpClient.post(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final conv = data is Map ? data['conversation'] : null;
      if (conv is Map<String, dynamic>) return conv;
      if (conv is Map) return Map<String, dynamic>.from(conv);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'completing conversation');
  }

  /// Deprecated alias — completing the session is the only way to leave intervention.
  Future<Map<String, dynamic>> deactivateConversationIntervention(
    int sessionId,
  ) =>
      completeConversationSession(sessionId);

  /// GET /api/v1/orders/{orderId}
  Future<Map<String, dynamic>> getOrder(String orderId) async {
    final uri = Uri.parse('$baseUrl/orders/${Uri.encodeComponent(orderId)}');
    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    if (response.statusCode == 404) {
      throw Exception('Order not found');
    }
    _fail(response, 'loading order');
  }

  /// PUT /api/v1/orders/{orderId}
  Future<Map<String, dynamic>> updateOrder(
    String orderId, {
    String? orderStatus,
    String? paymentStatus,
    String? fulfillmentStatus,
  }) async {
    final body = <String, dynamic>{};
    if (orderStatus != null && orderStatus.trim().isNotEmpty) {
      body['order_status'] = orderStatus.trim();
    }
    if (paymentStatus != null && paymentStatus.trim().isNotEmpty) {
      body['payment_status'] = paymentStatus.trim();
    }
    if (fulfillmentStatus != null && fulfillmentStatus.trim().isNotEmpty) {
      body['fulfillment_status'] = fulfillmentStatus.trim();
    }
    final uri = Uri.parse('$baseUrl/orders/${Uri.encodeComponent(orderId)}');
    final response = await httpClient.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'updating order');
  }

  /// POST /api/v1/orders/{orderId}/send-invoice — Paystack link + message to customer chat.
  Future<Map<String, dynamic>> sendOrderInvoice(
    String orderId, {
    String? customerEmail,
  }) async {
    final qp = <String, String>{};
    final trimmedEmail = customerEmail?.trim();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      qp['customer_email'] = trimmedEmail;
    }
    final uri = Uri.parse(
      '$baseUrl/orders/${Uri.encodeComponent(orderId)}/send-invoice',
    ).replace(queryParameters: qp.isEmpty ? null : qp);
    final response = await httpClient.post(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'sending invoice');
  }

  /// POST /api/v1/orders/{orderId}/save-customer — copy order contact into customers.
  Future<Map<String, dynamic>> saveCustomerFromOrder(String orderId) async {
    final uri = Uri.parse(
      '$baseUrl/orders/${Uri.encodeComponent(orderId)}/save-customer',
    );
    final response = await httpClient.post(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'saving customer from order');
  }

  /// GET /api/v1/conversations/me — `{ completed, intervention_active }`.
  /// `completed` lists sessions without active intervention (history / all chats).
  Future<Map<String, List<Map<String, dynamic>>>> listMyConversations({
    int skip = 0,
    int limit = 100,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/conversations/me',
    ).replace(queryParameters: {'skip': '$skip', 'limit': '$limit'});
    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is! Map) {
        return {'completed': [], 'intervention_active': []};
      }
      return {
        'completed': _decodeMapList(
          data['completed'] ?? data['history'] ?? data['all'],
        ),
        'intervention_active': _decodeMapList(
          data['intervention_active'] ?? data['active'] ?? data['live'],
        ),
      };
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'loading conversations');
  }

  List<Map<String, dynamic>> _decodeMapList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return Map<String, dynamic>.from(e);
          return <String, dynamic>{};
        })
        .where((m) => m.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _decodeListPayload(dynamic data) {
    if (data is List) return _decodeMapList(data);
    if (data is Map) {
      for (final key in [
        'items',
        'results',
        'data',
        'customers',
        'products',
        'orders',
        'plans',
        'financials',
        'transactions',
      ]) {
        if (data[key] is List) return _decodeMapList(data[key]);
      }
    }
    return [];
  }

  /// GET /api/v1/user/me/emails/sent — body `{ emails: [...], total_returned }`.
  /// Server validates `limit` ≤ 50.
  Future<Map<String, dynamic>> getMySentEmails({int limit = 50}) async {
    final safeLimit = limit.clamp(1, 50);
    final uri = Uri.parse(
      '$baseUrl/user/me/emails/sent',
    ).replace(queryParameters: {'limit': '$safeLimit'});
    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'emails': <dynamic>[], 'total_returned': 0};
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'loading sent emails');
  }

  /// GET /api/v1/user/me/sms/sent — body `{ messages: [...], total_returned }`.
  /// Server validates `limit` ≤ 50.
  Future<List<Map<String, dynamic>>> getMySentSms({int limit = 50}) async {
    final safeLimit = limit.clamp(1, 50);
    final uri = Uri.parse(
      '$baseUrl/user/me/sms/sent',
    ).replace(queryParameters: {'limit': '$safeLimit'});
    final response = await httpClient.get(uri);
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    if (response.statusCode != 200) {
      _fail(response, 'loading sent SMS');
    }

    final data = jsonDecode(response.body);
    final raw = data is Map
        ? (data['messages'] ?? data['sms'] ?? data['items'] ?? [])
        : (data is List ? data : []);
    return _decodeMapList(raw);
  }

  /// POST /api/v1/social/digital-marketing/assets — archive a chat campaign.
  Future<Map<String, dynamic>> createDigitalMarketingAsset({
    String? marketingText,
    List<String> contentLinks = const [],
    List<Map<String, dynamic>>? conversation,
    List<Map<String, dynamic>>? contents,
    String agentName = 'digital_marketing',
  }) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/social/digital-marketing/assets'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'marketing_text': marketingText,
        'content_links': contentLinks,
        if (conversation != null) 'conversation': conversation,
        if (contents != null) 'contents': contents,
        'agent_name': agentName,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'ok': true};
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'saving campaign');
  }

  /// GET /api/v1/social/digital-marketing/assets/{id}
  Future<Map<String, dynamic>> getDigitalMarketingAsset(String assetId) async {
    final response = await httpClient.get(
      Uri.parse(
        '$baseUrl/social/digital-marketing/assets/${Uri.encodeComponent(assetId)}',
      ),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw AppException(kind: AppErrorKind.unexpected, action: 'saving campaign');
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'loading campaign');
  }

  /// GET /api/v1/social/digital-marketing/assets — body `{ items: [...], total }`.
  Future<Map<String, dynamic>> listDigitalMarketingAssets({
    int limit = 30,
    int offset = 0,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/social/digital-marketing/assets',
    ).replace(queryParameters: {'limit': '$limit', 'offset': '$offset'});
    final response = await httpClient.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'items': <dynamic>[], 'total': 0};
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    _fail(response, 'loading campaigns');
  }

  /// GET /api/v1/chatwoot/inboxes — Chatwoot inboxes (subscription required).
  Future<List<ChatwootInbox>> listChatwootInboxes() async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/chatwoot/inboxes'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> raw;
      if (data is Map && data['inboxes'] is List) {
        raw = data['inboxes'] as List;
      } else if (data is Map && data['payload'] is List) {
        raw = data['payload'] as List;
      } else if (data is List) {
        raw = data;
      } else {
        return [];
      }
      return raw
          .whereType<Map>()
          .map((e) => ChatwootInbox.fromJson(Map<String, dynamic>.from(e)))
          .where((i) => i.isActive)
          .toList();
    }
    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }
    if (response.statusCode == 404) {
      return [];
    }
    _fail(response, 'loading Chatwoot inboxes');
  }

  /// Inbox count for dashboard summaries.
  Future<int> getChatwootInboxTotal() async {
    final inboxes = await listChatwootInboxes();
    return inboxes.length;
  }


  /// GET /api/v1/customers/list
  Future<List<Map<String, dynamic>>> listCustomers() async {
    final response = await httpClient.get(Uri.parse('$baseUrl/customers/list'));
    if (response.statusCode == 200) {
      return _decodeListPayload(json.decode(response.body));
    }
    if (response.statusCode == 401) throw Exception('Session expired');
    _fail(response, 'loading customers');
  }

  /// GET /api/v1/customers/get/{customerId}
  Future<Map<String, dynamic>> getCustomer(int customerId) async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/customers/get/$customerId'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) throw Exception('Session expired');
    if (response.statusCode == 404) throw Exception('Customer not found');
    _fail(response, 'loading customer');
  }

  /// POST /api/v1/customers/add
  Future<Map<String, dynamic>> addCustomer({
    required String name,
    required String customerNumber,
    String? network,
    String? bankCode,
    String? email,
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      'customer_number': customerNumber.trim(),
    };
    if (network != null && network.trim().isNotEmpty) {
      body['network'] = network.trim();
    }
    if (bankCode != null && bankCode.trim().isNotEmpty) {
      body['bank_code'] = bankCode.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim();
    }

    final response = await httpClient.post(
      Uri.parse('$baseUrl/customers/add'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) throw Exception('Session expired');
    _fail(response, 'adding customer');
  }

  /// PUT /api/v1/customers/update/{customerId}
  Future<Map<String, dynamic>> updateCustomer(
    int customerId, {
    required String name,
    required String customerNumber,
    String? network,
    String? bankCode,
    String? email,
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      'customer_number': customerNumber.trim(),
    };
    if (network != null && network.trim().isNotEmpty) {
      body['network'] = network.trim();
    }
    if (bankCode != null && bankCode.trim().isNotEmpty) {
      body['bank_code'] = bankCode.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim();
    }

    final response = await httpClient.put(
      Uri.parse('$baseUrl/customers/update/$customerId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) throw Exception('Session expired');
    _fail(response, 'updating customer');
  }

  /// DELETE /api/v1/customers/delete/{customerId}
  Future<void> deleteCustomer(int customerId) async {
    final response = await httpClient.delete(
      Uri.parse('$baseUrl/customers/delete/$customerId'),
    );
    if (response.statusCode == 200) return;
    if (response.statusCode == 401) throw Exception('Session expired');
    if (response.statusCode == 404) throw Exception('Customer not found');
    _fail(response, 'deleting customer');
  }

  /// POST /api/v1/customers/message/sms
  Future<Map<String, dynamic>> sendCustomerSms({
    required List<int> customerIds,
    required String message,
  }) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/customers/message/sms'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'customer_ids': customerIds,
        'message': message.trim(),
      }),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) throw Exception('Session expired');
    _fail(response, 'sending SMS');
  }

  /// POST /api/v1/customers/message/email
  Future<Map<String, dynamic>> sendCustomerEmail({
    required List<int> customerIds,
    required String subject,
    required String body,
  }) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/customers/message/email'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'customer_ids': customerIds,
        'subject': subject.trim(),
        'body': body,
      }),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    if (response.statusCode == 401) throw Exception('Session expired');
    _fail(response, 'sending email');
  }
}

class PaystackInitResult {
  final String authorizationUrl;
  final String accessCode;
  final String reference;

  const PaystackInitResult({
    required this.authorizationUrl,
    required this.accessCode,
    required this.reference,
  });

  factory PaystackInitResult.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw AppException(kind: AppErrorKind.unexpected, action: 'starting payment');
    }

    final authorizationUrl = (json['authorization_url'] ?? '').toString();
    final accessCode = (json['access_code'] ?? '').toString();
    final reference = (json['reference'] ?? '').toString();

    if (authorizationUrl.isEmpty || reference.isEmpty) {
      throw AppException(kind: AppErrorKind.unexpected, action: 'starting payment');
    }

    return PaystackInitResult(
      authorizationUrl: authorizationUrl,
      accessCode: accessCode,
      reference: reference,
    );
  }
}
