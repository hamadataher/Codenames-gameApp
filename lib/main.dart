import 'package:codenames_bgu/views/login_view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart'; // Import Firebase Dynamic Links
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize Firebase Dynamic Links
  _handleDynamicLinks(); // Handle dynamic links immediately after initialization

  hideStatusBar(); // Hide status bar early in app startup
  runApp(MaterialApp(
    title: 'Flutter Demo',
    theme: ThemeData(primarySwatch: Colors.green),
    home: const SplashScreen(),
  ));
}

void hideStatusBar() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

// Function to handle dynamic links when app is opened via a link
Future<void> _handleDynamicLinks() async {
  final PendingDynamicLinkData? data =
      await FirebaseDynamicLinks.instance.getInitialLink();
  _processDynamicLink(
      data?.link); // Handle the dynamic link if the app was opened via one

  FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) {
    _processDynamicLink(
        dynamicLinkData.link); // Handle the link if the app is already running
  }).onError((error) {
    print('Error handling dynamic link: $error');
  });
}

// Function to process the dynamic link
void _processDynamicLink(Uri? link) {
  if (link != null && link.queryParameters.containsKey('gameCode')) {
    String gameCode = link.queryParameters['gameCode']!;
    print('Game Code from dynamic link: $gameCode');
    // Here you can navigate to the game page or join the game with the provided game code
  }
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

    // Navigate to LoginView after 3 seconds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginView()),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Image.asset(
          'assets/images/Designer.jpeg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(child: Text('Failed to load image'));
          },
        ),
      ),
    );
  }
}
