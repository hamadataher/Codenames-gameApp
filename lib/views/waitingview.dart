import 'package:codenames_bgu/views/JoinGamePage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'team_choosing_view.dart';
import 'dart:async'; // Import for Timer

class WaitingRoomPage extends StatefulWidget {
  final String roomId;

  const WaitingRoomPage({Key? key, required this.roomId}) : super(key: key);

  @override
  _WaitingRoomPageState createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  late Stream<DocumentSnapshot> roomStream;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _statusCheckTimer; // Timer for checking status periodically

  @override
  void initState() {
    super.initState();
    roomStream = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .snapshots();

    // Start the timer to check the game status every 5 seconds
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkGameStatus();
    });
  }

  @override
  void dispose() {
    // Cancel the timer when the page is disposed to avoid memory leaks
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  void _checkGameStatus() async {
    try {
      DocumentSnapshot roomSnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .get();
      if (!roomSnapshot.exists) {
        // If the room no longer exists, handle the error gracefully
        _handleRoomDeletion();
        return;
      }

      Map<String, dynamic> roomData =
          roomSnapshot.data() as Map<String, dynamic>;
      String status = roomData['status'] ?? 'waiting';

      // Print the current status for testing
      print('Checked status: $status');

      // If the game status is 'in progress', navigate to team choosing view
      if (status == 'in_progress') {
        _navigateToTeamChoosing();
      }
    } catch (e) {
      print("Error checking game status: $e");
    }
  }

  void _navigateToTeamChoosing() {
    // Navigate only if the status is 'in progress'
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TeamChoosingView(roomId: widget.roomId),
      ),
    );
  }

  void _handleRoomDeletion() {
    // Use SchedulerBinding to ensure the navigation occurs after the current frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Show the snack bar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The room has been deleted.')),
      );

      // Perform the navigation after the current frame
      Future.delayed(Duration(milliseconds: 100), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  JoinGamePage()), // Replace with your JoinGameView widget
        );
      });
    });
  }

  void _shareGameLink(String joinLink) {
    if (joinLink.isNotEmpty) {
      Share.share('Join our game: $joinLink');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game link is not available.')),
      );
    }
  }

  void _exitRoom() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({
        'players': FieldValue.arrayRemove([userId]),
      });

      Navigator.pushReplacementNamed(context, '/joinGamePage');
    } catch (e) {
      print('Error exiting room: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to exit the room. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: roomStream,
        builder: (context, snapshot) {
          // Check if the stream is still waiting
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Handle errors from the snapshot
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Handle case when the document doesn't exist (room was deleted)
          if (!snapshot.hasData || !snapshot.data!.exists) {
            // Handle room deletion scenario
            _handleRoomDeletion();
            return const Center(child: Text('Room not found.'));
          }

          // If the room data is available, proceed as usual
          Map<String, dynamic> roomData =
              snapshot.data!.data() as Map<String, dynamic>;
          List players = roomData['players'] ?? [];
          String gameCode = roomData['gameCode'] ?? 'Unknown';
          String hostId = roomData['host'];
          String status = roomData['status'] ?? 'waiting';

          return Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/backgroundd.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 90),
                Expanded(
                  child: ListView.builder(
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      bool isHost = players[index] == hostId;
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
                              players[index],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Add some space between the content and the buttons
                const SizedBox(height: 20),
                Text(
                  'Game Code: $gameCode',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                // Use a SizedBox to move buttons up a bit
                SizedBox(height: 20), // Add spacing above the buttons
                ElevatedButton(
                  onPressed: () {
                    _shareGameLink(roomData['joinLink'] ?? '');
                  },
                  child: const Text('Share Game Link'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                SizedBox(height: 10), // Small space between buttons
                ElevatedButton(
                  onPressed: _exitRoom,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.red,
                  ),
                  child: const Text(
                    'Exit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 50)
              ],
            ),
          );
        },
      ),
    );
  }
}
