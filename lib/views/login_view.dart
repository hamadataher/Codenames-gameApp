import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codenames_bgu/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'register_view.dart';
import 'HomePage.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _isFirebaseInitialized = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      setState(() {
        _isFirebaseInitialized = true;
      });
    } catch (e) {
      print("Firebase initialization error: $e");
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isFirebaseInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgroundd.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _email,
                            enableSuggestions: false,
                            autocorrect: false,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'Enter your Email',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _password,
                            obscureText: true,
                            enableSuggestions: false,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              hintText: 'Enter your password',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () async {
                              final email = _email.text;
                              final password = _password.text;
                              try {
                                final userCredential = await FirebaseAuth
                                    .instance
                                    .signInWithEmailAndPassword(
                                  email: email,
                                  password: password,
                                );
                                print("Logged in: $userCredential");

                                User? user = userCredential.user;
                                if (user != null && user.emailVerified) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const HomePage(),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Please verify your email before logging in.'),
                                    ),
                                  );
                                }
                              } on FirebaseAuthException catch (e) {
                                if (e.code == 'wrong-password') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Wrong password"),
                                    ),
                                  );
                                } else {
                                  print("Login error: ${e.code}");
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text("Login failed: ${e.message}"),
                                    ),
                                  );
                                }
                              }
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15, horizontal: 30),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Login",
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterView(),
                                ),
                              );
                            },
                            child: const Text(
                                "Don't have an account? Register here"),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15, horizontal: 30),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
