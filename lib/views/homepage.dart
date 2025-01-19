import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_view.dart';
import 'InsturctionsPage.dart';
import 'JoinGamePage.dart';
import 'StartGamePage.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
            bottom: 20,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              iconSize: 28,
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const LoginView(),
                  ),
                );
              },
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StartGameSplashScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 40),
                    backgroundColor: const Color.fromARGB(255, 8, 94, 164),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Start a Game",
                      style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JoinGamePage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 40),
                    backgroundColor: const Color.fromARGB(255, 155, 13, 13),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child:
                      const Text("Join a Game", style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InstructionsView(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 40),
                    backgroundColor: const Color.fromARGB(255, 132, 130, 129),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Instructions",
                      style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
