import 'package:codenames_bgu/video_calls/video_call_page.dart';
import 'package:codenames_bgu/views/GameView.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeamChoosingView extends StatefulWidget {
  final String? roomId;

  const TeamChoosingView({Key? key, required this.roomId}) : super(key: key);

  @override
  _TeamChoosingViewState createState() => _TeamChoosingViewState();
}

class _TeamChoosingViewState extends State<TeamChoosingView> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String currentUserId = '';
  String selectedTeam = '';
  String selectedRole = '';
  Map<String, dynamic> players = {};

  bool isHost = false;
  bool isNavigating = false;
  @override
  void dispose() {
    isNavigating = false; // Reset navigation flag
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    currentUserId = _auth.currentUser!.uid;
    _checkIfUserIsHost();

    FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .get()
        .then((roomSnapshot) {
      if (!roomSnapshot.exists ||
          !roomSnapshot.data()!.containsKey('gameStarted')) {
        FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).set({
          'gameStarted': false,
        }, SetOptions(merge: true));
      }
    });

    _listenToRoomUpdates(); // Call only once
  }

  Future<void> _checkIfUserIsHost() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("User not logged in");
        return;
      }

      DocumentSnapshot roomSnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .get();

      if (roomSnapshot.exists) {
        var roomData = roomSnapshot.data() as Map<String, dynamic>;
        String hostDisplayName = roomData['host'];

        String currentUserDisplayName = currentUser.displayName ?? '';

        if (currentUserDisplayName == hostDisplayName) {
          setState(() {
            isHost = true;
          });
        }
      }
    } catch (e) {
      print("Error checking host status: $e");
    }
  }

  void _listenToRoomUpdates() {
    FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .snapshots()
        .listen((roomSnapshot) {
      if (!mounted) return;

      if (roomSnapshot.exists) {
        Map<String, dynamic> roomData =
            roomSnapshot.data() as Map<String, dynamic>;

        // Handle player data first
        if (mounted) {
          setState(() {
            players = roomData['players'] ?? {};
            selectedTeam = players[currentUserId]?['team'] ?? '';
            selectedRole = players[currentUserId]?['role'] ?? '';
          });
        }

        // Separate the game state handling completely
        try {
          dynamic gameStarted = roomData['gameStarted'];
          if (mounted &&
              context.mounted &&
              !isNavigating &&
              gameStarted != null &&
              gameStarted is bool &&
              gameStarted) {
            isNavigating = true;

            // Use microtask to handle navigation
            Future.microtask(() {
              if (mounted && context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => GameView(
                      roomId: widget.roomId,
                    ),
                  ),
                );
              }
            });
          }
        } catch (e) {
          // Silently handle any type conversion errors
          print('Navigation check error: $e');
        }
      }
    });
  }

  void _chooseTeam(String team) async {
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .update({
      'players.$currentUserId': {
        'username': _auth.currentUser!.displayName ?? 'Unknown',
        'team': team,
        'role': '', // Reset role on team change
      }
    });
  }

  void _chooseRole(String role) async {
    bool isSpymasterTaken = false;

    players.forEach((playerId, playerData) {
      if (playerData['role'] == 'Spymaster' &&
          playerData['team'] == selectedTeam) {
        isSpymasterTaken = true;
      }
    });

    if (role == 'Spymaster' && isSpymasterTaken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This team already has a Spymaster!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .update({
      'players.$currentUserId.role': role,
    });
  }

  Widget _buildStartGameButton() {
    if (!isHost) return SizedBox.shrink();

    return ElevatedButton(
      onPressed: _startGame,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: const Text(
        'Start Game',
        style: TextStyle(fontSize: 18, color: Colors.white),
      ),
    );
  }

  void _startGame() async {
    if (!isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the host can start the game!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int redSpymasters = 0;
    int blueSpymasters = 0;
    bool allPlayersReady = true;

    players.forEach((playerId, playerData) {
      if (playerData['team'] == 'red' && playerData['role'] == 'Spymaster') {
        redSpymasters++;
      }
      if (playerData['team'] == 'blue' && playerData['role'] == 'Spymaster') {
        blueSpymasters++;
      }
      if (playerData['role'] == '' || playerData['team'] == '') {
        allPlayersReady = false;
      }
    });

    if (redSpymasters != 1 || blueSpymasters != 1 || !allPlayersReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ensure all players have selected roles and there is one Spymaster per team!',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Initialize the full game state
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .set({
      'gameStarted': true,
      'players': players,
    }, SetOptions(merge: true)); // Use merge to preserve other fields
  }

  Widget _buildTeamCard(String team) {
    return GestureDetector(
      onTap: () => _chooseTeam(team),
      child: Container(
        decoration: BoxDecoration(
          color: team == selectedTeam
              ? (team == 'blue' ? Colors.blueAccent : Colors.redAccent)
              : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: team == 'blue' ? Colors.blueAccent : Colors.redAccent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              team == 'blue' ? 'Blue Team' : 'Red Team',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: team == selectedTeam ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleButton(String role) {
    return ElevatedButton(
      onPressed: () => _chooseRole(role),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.8),
        side: BorderSide(
          color: role == selectedRole ? Colors.green : Colors.grey,
          width: 2,
        ),
        minimumSize: const Size(140, 50),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: role == selectedRole ? Colors.green : Colors.black,
        ),
      ),
    );
  }

  Widget _buildPlayersList() {
    List<Map<String, dynamic>> redTeam = [];
    List<Map<String, dynamic>> blueTeam = [];

    players.forEach((playerId, playerData) {
      if (playerData['team'] == 'red') {
        redTeam.add(playerData);
      } else if (playerData['team'] == 'blue') {
        blueTeam.add(playerData);
      }
    });

    return Row(
      children: [
        Expanded(
          child: Column(
            children: redTeam.map((playerData) {
              return Card(
                color: Colors.redAccent,
                child: ListTile(
                  title: Text(
                    playerData['username'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${playerData['role'] ?? 'No Role'}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: Column(
            children: blueTeam.map((playerData) {
              return Card(
                color: Colors.blueAccent,
                child: ListTile(
                  title: Text(
                    playerData['username'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${playerData['role'] ?? 'No Role'}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/backgroundd.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildTeamCard('red')),
                            const SizedBox(width: 20),
                            Expanded(child: _buildTeamCard('blue')),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Choose your role: ',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        _buildRoleButton('Spymaster'),
                        _buildRoleButton('Operative'),
                        const SizedBox(height: 20),
                        const Text(
                          'Players:',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        _buildPlayersList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(bottom: 40.0), // Adjust the value here
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _buildStartGameButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
