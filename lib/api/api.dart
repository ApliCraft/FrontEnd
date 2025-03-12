import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final apiUrl = dotenv.env['API_URL'];
final websiteUrl = dotenv.env['WEBSITE_URL'];

final storage = const FlutterSecureStorage();

// REFRESH TOKEN

Future<void> RefreshTokenIfExpired() async {
  print('Refreshing token process started');
  
  // Check if access token exists
  final accessToken = await storage.read(key: 'accessToken');

  if (accessToken != null) {
    final expiryString = await storage.read(key: "exp");
    if (expiryString != null) {
      final expiryValue = int.tryParse(expiryString);
      if (expiryValue == null) {
        print('Invalid expiry value stored: $expiryString');
      } else {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryValue * 1000);
        final now = DateTime.now();
        print('Expiry date: $expiryDate');
        print('Now: $now');
        if (now.isBefore(expiryDate)) {
          print('Access token is still valid');
          return;
        } else {
          print('Access token expired');
        }
      }
    } else {
      print('Expiry not set. Continuing with token refresh.');
    }
  }
  
  print('Refreshing token step 2');
  final refreshTokenValue = await storage.read(key: 'refreshToken');
  final refreshUrl = Uri.parse('$apiUrl/user/refresh-token');
  final response = await http.post(
    refreshUrl,
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String?>{
      'refreshToken': refreshTokenValue,
    }),
  );

  if (response.statusCode == 200) {
    final body = jsonDecode(response.body);
    final newAccessToken = body['accessToken'];
    await storage.write(key: 'accessToken', value: newAccessToken);
    final newRefreshToken = body['newRefreshToken'];
    await storage.write(key: 'refreshToken', value: newRefreshToken);

    // Set expiry date using the new access token
    try {
      final parts = newAccessToken.split('.');
      if (parts.length != 3) {
        throw Exception('Invalid JWT token');
      }
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decodedPayload = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(decodedPayload);
      final exp = payloadMap['exp'];
      await storage.write(key: 'exp', value: exp.toString());
      print('Token expiration: $exp');
    } catch (e) {
      print('Failed to decode JWT token: $e');
    }

    print("Token refreshed");
    print('New access token: $newAccessToken');
    print('New refresh token: $newRefreshToken');
  } else {
    print('Token refresh failed');
    await storage.deleteAll();
  }
}