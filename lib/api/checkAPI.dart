import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import './user.dart';
import 'api.dart';

class CheckAPI extends StatefulWidget {
  const CheckAPI({Key? key}) : super(key: key);

  @override
  _CheckAPIState createState() => _CheckAPIState();
}

class _CheckAPIState extends State<CheckAPI> {
  @override
  void initState() {
    super.initState();
    checkAPI();
  }

  Future<void> checkAPI() async {
    try {
      final url = Uri.parse(apiUrl!.replaceAll('/v1', ''));
      print(url);
      final response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        }
      );

      if (response.statusCode == 200) {
        print('API is working');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AuthCheck(),
          ),
        );
      } else {
        throw Exception("Status code is not 200");
      }
    } catch (e) {
      print('API is not working');
      print(e);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => APIFailedScreen(
            retryFunction: checkAPI,
          ),
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

class APIFailedScreen extends StatefulWidget {
  final Function retryFunction;
  const APIFailedScreen({required this.retryFunction, super.key});

  @override
  State<APIFailedScreen> createState() => _APIFailedScreenState();
}

class _APIFailedScreenState extends State<APIFailedScreen> {
  int _timer = 10;
  bool _isRetrying = false;
  late Timer _retryTimer;

  @override
  void initState() {
    super.initState();
    _startRetryTimer();
  }

  void _startRetryTimer() {
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timer > 0) {
        setState(() {
          _timer--;
        });
      } else {
        _retryTimer.cancel();
        _retryAPI();
      }
    });
  }

  Future<void> _retryAPI() async {
    setState(() {
      _isRetrying = true;
    });


    try {
      final url = Uri.parse('$apiUrl/api/');
      final response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        }
      );

      if (response.statusCode == 200) {
        print('API is working');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AuthCheck(),
          ),
        );
      } else {
        throw Exception("Status code is not 200");
      }
    } catch (e) {
      print('API is not working');
      print(e);
      if (mounted) {
        setState(() {
          _isRetrying = false;
          _timer = 10;
        });
        _startRetryTimer();
      }
    }
  }

  @override
  void dispose() {
    _retryTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text("API Failed"),
        ),
      ),
      body: Center(
        child: _isRetrying
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text("There was an error while connecting to the API"),
                  const Text("Retrying in:"),
                  Text('$_timer'),
                ],
              ),
      ),
    );
  }
}