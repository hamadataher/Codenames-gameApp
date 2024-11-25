import 'dart:async';
import 'dart:math';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';

// Generate a unique 6-character alphanumeric game code
String generateGameCode() {
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random();
  String gameCode = '';
  for (int i = 0; i < 6; i++) {
    gameCode += characters[random.nextInt(characters.length)];
  }
  return gameCode;
}

class StartGameSplash extends StatefulWidget {
  @override
  _StartGameSplashState createState() => _StartGameSplashState();
}

class _StartGameSplashState extends State<StartGameSplash> {
  @override
  void initState() {
    super.initState();

    // Start a timer to navigate after 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StartGamePage(), // Replace with your game page
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                'assets/images/backgroundd.jpg'), // Replace with your image path
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Colors.white, // Adjust color to match the theme
              ),
              const SizedBox(height: 20),
              const Text(
                "Starting your game...",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color:
                      Colors.white, // Ensure the text is visible on the image
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StartGamePage extends StatefulWidget {
  const StartGamePage({super.key});

  @override
  _StartGamePageState createState() => _StartGamePageState();
}

class _StartGamePageState extends State<StartGamePage> {
  String? _gameCode;
  String? _joinLink;

  @override
  void initState() {
    super.initState();
    // Generate game code and dynamic link on page load
    _generateGameCodeAndLink();
  }

  // Function to generate game code and dynamic link
  Future<void> _generateGameCodeAndLink() async {
    String gameCode = generateGameCode(); // Generate the game code

    // Create a dynamic link with the game code
    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix:
          'https://codenames.bgu.link', // Your Firebase dynamic link domain
      link: Uri.parse(
          'https://codenames.bgu.link/join?gameCode=$gameCode'), // Include the game code as query parameter
      androidParameters: AndroidParameters(
        packageName:
            'com.hamada.codenames_bgu', // Your Android app package name
        minimumVersion: 1,
      ),
      iosParameters: IOSParameters(
        bundleId: 'com.hamada.codenames_bgu', // Your iOS app bundle ID
        minimumVersion: '1.0.0',
      ),
    );

    try {
      // Generate the dynamic link
      final Uri dynamicUrl =
          await FirebaseDynamicLinks.instance.buildLink(parameters);

      setState(() {
        _gameCode = gameCode;
        _joinLink = dynamicUrl.toString(); // Store the generated dynamic link
      });

      print('Generated dynamic link: $_joinLink');
    } catch (e) {
      print('Error generating dynamic link: $e');
      // Handle error appropriately
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Start Game")),
      body: Center(
        child: _joinLink == null
            ? const CircularProgressIndicator() // Show loading until link is generated
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Game Code: $_gameCode"),
                  SizedBox(height: 20),
                  Text("Join Link: $_joinLink"),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Share the join link with others
                      print('Join Link: $_joinLink');
                    },
                    child: Text("Share Link"),
                  ),
                ],
              ),
      ),
    );
  }
}
