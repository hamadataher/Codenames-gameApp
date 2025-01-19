import 'package:codenames_bgu/views/waitingview.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';


class JoinGamePage extends StatefulWidget {
  const JoinGamePage({super.key});

  @override
  _JoinGamePageState createState() => _JoinGamePageState();
}

class _JoinGamePageState extends State<JoinGamePage> {
  final TextEditingController _gameCodeController = TextEditingController();
  final TextEditingController _gameLinkController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _joinGame() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String gameCode = _gameCodeController.text.trim();
    String gameLink = _gameLinkController.text.trim();

    if (gameCode.isEmpty && gameLink.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enter a game code or game link.';
      });
      return;
    }

    try {
      if (gameLink.isNotEmpty) {
        Uri? dynamicLink = Uri.tryParse(gameLink);

        if (dynamicLink == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Invalid game link.';
          });
          return;
        }

        gameCode = dynamicLink.queryParameters['gameCode'] ?? '';

        if (gameCode.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Invalid game link (missing game code).';
          });
          return;
        }
      }

      QuerySnapshot roomSnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .where('gameCode', isEqualTo: gameCode)
          .limit(1)
          .get();

      if (roomSnapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Room not found.';
        });
        return;
      }

      DocumentSnapshot roomDoc = roomSnapshot.docs[0];
      String roomId = roomDoc.id;
      Map<String, dynamic> roomData = roomDoc.data() as Map<String, dynamic>;
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'You need to be logged in to join a game.';
        });
        return;
      }

      await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
        'players': FieldValue.arrayUnion([currentUser.displayName]),
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingRoomPage(roomId: roomId),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error joining the game. Please try again later.';
      });
    }
  }

  Future<void> _initDynamicLink() async {
    final PendingDynamicLinkData? data =
        await FirebaseDynamicLinks.instance.getInitialLink();

    final Uri? deepLink = data?.link;

    if (deepLink != null) {
      String gameCode = deepLink.queryParameters['gameCode'] ?? '';

      if (gameCode.isNotEmpty) {
        _gameCodeController.text = gameCode;
        _joinGame();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initDynamicLink();
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
          SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  TextField(
                    controller: _gameCodeController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      labelText: 'Enter Game Code',
                      labelStyle: const TextStyle(color: Colors.black),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Colors.black38),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'or',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _gameLinkController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      labelText: 'Enter Game Link',
                      labelStyle: const TextStyle(color: Colors.black),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Colors.black38),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 50,
                    child: TextButton(
                      onPressed: _joinGame,
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              "Join",
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
