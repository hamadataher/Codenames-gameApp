import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_view.dart';

class RegistrationSuccessView extends StatelessWidget {
  const RegistrationSuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    // Delay navigation to the LoginView after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginView(),
        ),
      );
    });

    return Scaffold(
      body: Stack(
        children: [
          // Background image (optional, adjust path as needed)
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgroundd.jpg', // Optional background for success page
              fit: BoxFit.cover,
            ),
          ),
          // BackdropFilter for blur effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color:
                    Colors.black.withOpacity(0.3), // Dark overlay for contrast
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Green check icon
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 100, // Adjust size of the check icon
                ),
                const SizedBox(height: 20),
                const Text(
                  "Registration Successful!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Your account has been created successfully.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                const CircularProgressIndicator(
                  color: Colors.white,
                ), // Optional loading indicator
              ],
            ),
          ),
        ],
      ),
    );
  }
}
