import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api/user.dart';
import 'register.dart';
import 'home.dart';
import 'forgotPassword.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  Future<void> _login() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    // Send the username and password to the server to get the token and save it in the secure storage
    final loginUrl = Uri.parse('http://192.168.1.38:4000/api/v1/user/login');
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
      final accessToken = jsonDecode(response.body)['accessToken'];
      final refreshToken = jsonDecode(response.body)['refreshToken'];
      await storage.write(key: 'accessToken', value: accessToken);
      await storage.write(key: 'refreshToken', value: refreshToken);
      print('Access token: $accessToken');
      print('Refresh token: $refreshToken');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MyHomePage(title: 'MindBoost'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid username or password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // appBar: AppBar(
        //   title: const Text('MindBoost',
        //       style: TextStyle(
        //         color: Colors.black,
        //         fontWeight: FontWeight.bold,
        //         fontSize: 24,
        //       )),
        //   centerTitle: true,
        // ),
        body: ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Image.asset(
                      'assets/logo.png',
                      height: 200,
                      width: 200,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const SizedBox(height: 20),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        TextField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: _passwordFocusNode.hasFocus
                                ? IconButton(
                                    icon: Icon(
                                      _obscureText
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: _togglePasswordVisibility,
                                  )
                                : null,
                          ),
                          obscureText: _obscureText,
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                            onPressed: forgotPassword,
                            child: const Text("Forgot Password?")),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _login,
                          child: const Text('Login'),
                        ),
                        const SizedBox(height: 20),
                        // ElevatedButton(
                        //     onPressed: () {
                        //       Navigator.pushReplacement(
                        //         context,
                        //         MaterialPageRoute(
                        //           builder: (context) => const RegisterPage(),
                        //         ),
                        //       );
                        //     },
                        //     child: const Text("Join Us")),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text("Don't have an account?"),
                            const SizedBox(width: 5),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterPage(),
                                  ),
                                );
                              },
                              child: const Text("Sign Up"),
                            ),
                          ],
                        ),
                        Container(
                          height: 50,
                          width: 200,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: SvgPicture.asset(
                                    'assets/icons/google.svg',
                                    height: 20,
                                    width: 20),
                                onPressed: () {
                                  print('Google');
                                },
                              ),
                              IconButton(
                                icon: SvgPicture.asset(
                                    'assets/icons/facebook.svg',
                                    height: 20,
                                    width: 20),
                                iconSize: 20,
                                onPressed: () {
                                  print('Facebook');
                                },
                              ),
                              IconButton(
                                icon: SvgPicture.asset('assets/icons/apple.svg',
                                    height: 20, width: 20),
                                iconSize: 20,
                                onPressed: () {
                                  print('Apple');
                                },
                              ),
                              IconButton(
                                icon: SvgPicture.asset('assets/icons/x.svg',
                                    height: 20, width: 20),
                                iconSize: 20,
                                onPressed: () {
                                  print('X');
                                },
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            )));
  }
}
