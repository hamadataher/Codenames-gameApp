import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codenames_bgu/firebase_options.dart';
import 'register_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final TextEditingController _email;
  late final TextEditingController _password;

  @override
  void initState() {
    _email = TextEditingController();
    _password = TextEditingController();
    super.initState();
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
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.blue, // Set AppBar background to blue
        foregroundColor: Colors.white, // Set AppBar text to white
      ),
      body: FutureBuilder(
        future: Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ),
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.waiting:
            case ConnectionState.active:
            case ConnectionState.done:
              return Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment
                        .center, // Center the column vertically
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Email and Password Fields
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            // Email TextField
                            TextField(
                              controller: _email,
                              enableSuggestions: false,
                              autocorrect: false,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: 'Enter your Email',
                              ),
                            ),
                            const SizedBox(height: 10), // Space between fields
                            // Password TextField
                            TextField(
                              controller: _password,
                              obscureText: true,
                              enableSuggestions: false,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                hintText: 'Enter your password',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                          height: 20), // Space between fields and buttons

                      // Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            // Login Button
                            TextButton(
                              onPressed: () async {
                                final email = _email.text;
                                final password = _password.text;
                                try {
                                  final UserCredential = await FirebaseAuth
                                      .instance
                                      .signInWithEmailAndPassword(
                                    email: email,
                                    password: password,
                                  );
                                  print(UserCredential);
                                } on FirebaseAuthException catch (e) {
                                  print("Error code: ${e.code}");
                                  if (e.code == 'user-not-found') {
                                    print("User not found.");
                                  } else if (e.code == 'wrong-password') {
                                    print("Wrong password.");
                                  } else if (e.code == 'invalid-email') {
                                    print("Invalid email format.");
                                  } else {
                                    print(
                                        "An unknown error occurred: ${e.code}");
                                  }
                                }
                              },
                              child: const Text("Login"),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors
                                    .blue, // Set AppBar background to blue
                                foregroundColor:
                                    Colors.white, // Set text color to blue
                              ),
                            ),
                            // Register Button
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
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
          }
        },
      ),
    );
  }
}
