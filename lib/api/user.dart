import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../pages/home.dart';
import '../pages/login.dart';

final storage = FlutterSecureStorage();

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  _AuthCheckState createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final accessToken = await storage.read(key: 'accessToken');
    final refreshToken = await storage.read(key: 'refreshToken');

    if (accessToken != null && refreshToken != null) {
      // Print the access token for debugging
      print('Access token: $accessToken');
      print('Refresh token: $refreshToken');

      // Token exists, try to refresh it
      final refreshUrl =
          Uri.parse('http://192.168.1.38:4000/api/v1/user/refresh-token');
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

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MyHomePage(title: 'MindBoost'),
          ),
        );
      } else {
        // Refresh token failed, show login page and delete old tokens
        print('Token refresh failed');
        await storage.delete(key: 'accessToken');
        await storage.delete(key: 'refreshToken');
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

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
