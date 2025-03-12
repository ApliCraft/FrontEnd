import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../pages/home.dart';
import '../pages/authorization/login.dart';
import 'api.dart';


class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  _AuthCheckState createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() {
    super.initState();
    checkAuth(context);
  }

  

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Attempts to login a user with email and password
/// Returns a Map with 'success' boolean and 'message' string
Future<Map<String, dynamic>> login(String email, String password, BuildContext context) async {
  try {
    final loginUrl = Uri.parse('$apiUrl/user/login');
    final response = await http.post(
      loginUrl,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final body = response.body;
      final Map<String, dynamic> jsonResponse = json.decode(body);
      final accessToken = jsonResponse['accessToken'];
      final refreshToken = jsonResponse['refreshToken'];

      await storage.write(key: 'accessToken', value: accessToken);
      await storage.write(key: 'refreshToken', value: refreshToken);

      try {
        final parts = accessToken.split('.');
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decodedPayload = utf8.decode(base64Url.decode(normalized));
        final payloadMap = json.decode(decodedPayload);
        final userId = payloadMap['sub'] ?? payloadMap['id'];
        await storage.write(key: 'userId', value: userId.toString());
        final exp = payloadMap['exp'];
        await storage.write(key: 'exp', value: exp.toString());
      } catch (e) {
        print('Failed to decode JWT token: $e');
      }

      // Navigate to the HomePage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomePage(),
        ),
      );

      return {
        'success': true,
        'message': 'Login successful',
      };
    } else {
      return {
        'success': false,
        'message': 'Invalid credentials',
      };
    }
  } catch (e) {
    return {
      'success': false,
      'message': 'Network error: ${e.toString()}',
    };
  }
}

Future<void> checkAuth(context) async {
    final accessToken = await storage.read(key: 'accessToken');
    final refreshToken = await storage.read(key: 'refreshToken');

    if (accessToken != null && refreshToken != null) {
      // Print the access token for debugging
      print('Access token: $accessToken');
      print('Refresh token: $refreshToken');

      // Token exists, try to refresh it
      final refreshUrl =
          Uri.parse('$apiUrl/user/refresh-token');
      final response = await http.post(
        refreshUrl,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'refreshToken': refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final newAccessToken = jsonDecode(response.body)['accessToken'];
        await storage.write(key: 'accessToken', value: newAccessToken);
        final newRefreshToken = jsonDecode(response.body)['newRefreshToken'];
        await storage.write(key: 'refreshToken', value: newRefreshToken);

        print("Token refreshed");
        print('New access token: $newAccessToken');
        print('New refresh token: $newRefreshToken');

        // Decode the JWT token to extract the user id and write it to secure storage
        try {
          final parts = newAccessToken.split('.');
          if (parts.length != 3) {
            throw Exception('Invalid JWT token');
          }
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final decodedPayload = utf8.decode(base64Url.decode(normalized));
          final payloadMap = json.decode(decodedPayload);
          // Replace 'sub' with the appropriate key if your JWT stores the user id under a different claim
          final userId = payloadMap['sub'] ?? payloadMap['id'];
          await storage.write(key: 'userId', value: userId.toString());
          print('User id stored: $userId');
        } catch (e) {
          print('Failed to decode JWT token: $e');
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomePage(),
          ),
        );
      } else {
        // Refresh token failed, show login page and delete old tokens
        print('Token refresh failed');
        await storage.deleteAll();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          ),
        );
      }
    } else {
      // No access token, show login page
      print('AccessTokenNotFound');
      print('RefreshTokenNotFound');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
    }
  }
  
  Future<String> getUsername() async {
    final userId = await storage.read(key: 'userId');
    final response = await http.get(Uri.parse('$apiUrl/user/$userId'));
    if (response.statusCode == 200) {
      final body = response.body;
      final Map<String, dynamic> jsonResponse = json.decode(body);
      final username = jsonResponse['username'];
      return username;
    } else {
      return '';
    }

  }