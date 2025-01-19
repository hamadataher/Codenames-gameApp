import 'package:codenames_bgu/video_calls/video_call_page.dart';
import 'package:codenames_bgu/views/team_choosing_view.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'dart:math';
import 'package:share_plus/share_plus.dart';

class StartGameSplashScreen extends StatelessWidget {
  const StartGameSplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const StartGamePage()),
      );
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgroundd.jpg',
            fit: BoxFit.cover,
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Loading...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StartGamePage extends StatefulWidget {
  const StartGamePage({Key? key}) : super(key: key);

  @override
  _StartGamePageState createState() => _StartGamePageState();
}

class _StartGamePageState extends State<StartGamePage> {
  String? _gameCode;
  String? _joinLink;
  String? _roomId;
  Stream<DocumentSnapshot>? _roomStream;

  @override
  void initState() {
    super.initState();
    _generateGameCodeAndLink();
  }

  String generateGameCode() {
    const characters = '0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => characters.codeUnitAt(random.nextInt(characters.length)),
      ),
    );
  }

  Future<void> _generateGameCodeAndLink() async {
    String gameCode = generateGameCode();

    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://codenames.bgu.link',
      link: Uri.parse('https://codenames.bgu.link/join?gameCode=$gameCode'),
      androidParameters: AndroidParameters(
        packageName: 'com.hamada.codenames_bgu',
        minimumVersion: 1,
      ),
      iosParameters: IOSParameters(
        bundleId: 'com.hamada.codenames_bgu',
        minimumVersion: '1.0.0',
      ),
    );

    try {
      final Uri dynamicUrl =
          await FirebaseDynamicLinks.instance.buildLink(parameters);

      setState(() {
        _gameCode = gameCode;
        _joinLink = dynamicUrl.toString();
      });

      await _createRoom(gameCode, dynamicUrl.toString());
    } catch (e) {
      print('Error generating dynamic link: $e');
    }
  }

  Future<void> _createRoom(String gameCode, String joinLink) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("User not logged in");
        return;
      }
      String hostId = currentUser.uid;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(hostId)
          .get();

      if (!userDoc.exists) {
        print("User document not found.");
        return;
      }

      var userData = userDoc.data() as Map<String, dynamic>;
      String hostUsername = userData['username'] ?? '';

      if (hostUsername.isEmpty) {
        print("Username is empty in Firestore.");
        return;
      }

      Map<String, dynamic> roomData = {
        'players': [hostUsername],
        'host': hostUsername,
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
        'gameCode': gameCode,
        'joinLink': joinLink,
        'playersRoles': {},
      };

      DocumentReference roomRef =
          await FirebaseFirestore.instance.collection('rooms').add(roomData);

      _roomId = roomRef.id;

      setState(() {
        _roomStream = FirebaseFirestore.instance
            .collection('rooms')
            .doc(_roomId)
            .snapshots();
      });
    } catch (e) {
      print("Error creating room: $e");
    }
  }

  Future<void> _endRoom() async {
    if (_roomId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(_roomId)
          .delete();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print("Error ending room: $e");
    }
  }

  void _startGame() {
    FirebaseFirestore.instance
        .collection('rooms')
        .doc(_roomId)
        .update({'status': 'in_progress'});

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => TeamChoosingView(
                roomId: _roomId,
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgroundd.jpg',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 90),
                StreamBuilder<DocumentSnapshot>(
                  stream: _roomStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Text("Room not found");
                    }

                    var roomData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    List<dynamic> playersList = roomData['players'] ?? [];

                    return Column(
                      children: playersList.map<Widget>((player) {
                        bool isHost = player == roomData['host'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                isHost ? Colors.blueAccent : Colors.greenAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 30),
                              const SizedBox(width: 10),
                              Text(
                                player,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const Spacer(),
                if (_gameCode != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Game Code: $_gameCode',
                      style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_gameCode != null && _joinLink != null) {
                      Share.share('Join my game: $_joinLink');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white),
                  icon: const Icon(Icons.share),
                  label: const Text("Share Link"),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white),
                  child: const Text("Start Game"),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _endRoom,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  child: const Text("End Room"),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
