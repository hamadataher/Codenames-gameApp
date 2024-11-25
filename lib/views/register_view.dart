import 'dart:ui';
import 'package:flutter/material.dart';
//import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:codenames_bgu/firebase_options.dart'; // Correct import path
import 'package:flutter/services.dart'; // Required for system UI
import 'RegistrationSuccessView.dart'; // Import the success view

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  late final TextEditingController _email;
  late final TextEditingController _password;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgroundd.jpg', // Replace with your image path
              fit: BoxFit.cover,
            ),
          ),
          // Back button
          Positioned(
            top: 40, // Adjust position as needed
            left: 20, // Adjust position as needed
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              iconSize: 28, // Increased icon size
              onPressed: () {
                Navigator.pop(context); // Go back to the previous screen
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
                          // Email TextField
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
                          // Password TextField
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
                          // Register Button
                          TextButton(
                            onPressed: () async {
                              final email = _email.text;
                              final password = _password.text;
                              try {
                                await FirebaseAuth.instance
                                    .createUserWithEmailAndPassword(
                                  email: email,
                                  password: password,
                                );

                                // Navigate to Registration Success screen
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RegistrationSuccessView(),
                                  ),
                                );
                              } on FirebaseAuthException catch (e) {
                                if (e.code == 'weak-password') {
                                  print(
                                      'Your password is weak, it should contain at least 6 characters');
                                } else if (e.code == 'email-already-in-use') {
                                  print('Email is already in use');
                                } else if (e.code == 'invalid-email') {
                                  print('Invalid email');
                                }
                              }
                            },
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
