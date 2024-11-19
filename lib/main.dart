import 'package:codenames_bgu/views/login_view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  hideStatusBar(); // Hide status bar early in app startup
  runApp(MaterialApp(
    title: 'Flutter Demo',
    theme: ThemeData(primarySwatch: Colors.green),
    home: const SplashScreen(), // Show SplashScreen initially
  ));
}

void hideStatusBar() {
  SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge); // Ensure content uses the entire screen
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Delay for 3 seconds and then navigate to LoginView
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get the screen size
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image set to full screen
            Image.asset(
              'assets/images/designer.jpeg', // Path to your image
              height: screenHeight, // Fill the full screen height
              width: screenWidth, // Fill the full screen width
              fit: BoxFit.fill, // Ensure the image covers the entire screen
            ),
          ],
        ),
      ),
    );
  }
}
