import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_view.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _username;
  bool _isLoading = false;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
    _username = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _username.dispose();
    super.dispose();
  }

  void _sendVerificationEmail(User user) async {
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }

    await Future.delayed(const Duration(seconds: 2));

    Timer.periodic(const Duration(seconds: 2), (timer) async {
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        await currentUser.reload();

        if (currentUser.emailVerified) {
          setState(() {
            _isLoading = false;
            _isVerified = true;
          });

          timer.cancel();
          await Future.delayed(const Duration(seconds: 2));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginView(),
            ),
          );
        }
      }
    });
  }

  Future<void> _registerUser() async {
    final email = _email.text;
    final password = _password.text;
    final username = _username.text;

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        await user.updateProfile(displayName: username);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'username': username,
          'displayName': username,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _sendVerificationEmail(user);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (e.code == 'weak-password') {
        print('Your password is weak, it should contain at least 6 characters');
      } else if (e.code == 'email-already-in-use') {
        print('Email is already in use');
      } else if (e.code == 'invalid-email') {
        print('Invalid email');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgroundd.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              iconSize: 28,
              onPressed: () {
                Navigator.pop(context);
              },
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
                            controller: _username,
                            enableSuggestions: false,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              hintText: 'Enter your Username',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
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
                            onPressed: _registerUser,
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 9, 78, 11),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15, horizontal: 30),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Register",
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          if (_isLoading)
                            Column(
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 20),
                                const Text("Sending verification email..."),
                              ],
                            ),
                          if (_isVerified)
                            Column(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 60,
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  "Email verified successfully!",
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.green),
                                ),
                              ],
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
