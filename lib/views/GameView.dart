import 'package:codenames_bgu/views/homepage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:ui';

class GameView extends StatefulWidget {
  final String? roomId;

  const GameView({Key? key, required this.roomId}) : super(key: key);

  @override
  _GameViewState createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  Map<int, String> selectedTiles = {}; // Maps tile index to player name
  String? selectedTileIndex; // Currently selected tile index

  Map<String, dynamic> gameData = {};
  String? playerTeam;
  bool isSpymaster = false;
  TextEditingController clueController = TextEditingController();
  int numberOfWords = 1;
  int remainingGuesses = 0;
  bool canEndTurn = false;
  bool isLoading = true; // Add this line

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    try {
      await _initializePlayerTeam();
      await _checkAndStartNewGame();
      _listenToGameData();
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error initializing game: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _initializePlayerTeam() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("No user is currently signed in!");
        return;
      }
      final currentPlayerUID = currentUser.uid;
      print("Current player UID: $currentPlayerUID");

      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .get();

      if (roomDoc.exists) {
        final data = roomDoc.data();
        print("Room document data: $data");

        if (data != null && data['players'] != null) {
          final players = Map<String, dynamic>.from(data['players']);
          print("Players data: $players");

          if (players.containsKey(currentPlayerUID)) {
            final playerData = players[currentPlayerUID];
            setState(() {
              playerTeam = playerData['team'];
              isSpymaster = playerData['role'] == 'Spymaster';
            });

            print("Player team initialized as: $playerTeam");
            print("Player is spymaster: $isSpymaster");
          } else {
            print("Current player not found in the room's players data.");
          }
        } else {
          print("Players data is null or invalid in the room document.");
        }
      } else {
        print("Room document does not exist!");
      }
    } catch (e) {
      print("Error initializing player team: $e");
    }
  }

  void _listenToGameData() {
    FirebaseFirestore.instance
        .collection('gameRooms')
        .doc(widget.roomId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          gameData = snapshot.data() ?? {};
        });

        // If gameOver is true, show the game over dialog
        if (gameData['gameOver'] == true) {
          String winner =
              gameData['winner'] ?? 'No team'; // Safely handle winner data
          _showGameOverDialog(winner);
        }
      }
    });
  }

  Future<void> _submitClue() async {
    if (clueController.text.isEmpty || numberOfWords < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Please enter a valid clue and number of words")),
      );
      return;
    }

    if (gameData['turn'] != playerTeam) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("It's not your team's turn!")),
      );
      return;
    }

    if (gameData['clueSubmitted'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Clue has already been given for this turn!")),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    String spymasterName = currentUser?.displayName ?? 'Unknown Spymaster';

    await FirebaseFirestore.instance
        .collection('gameRooms')
        .doc(widget.roomId)
        .update({
      'currentClue': clueController.text,
      'numberOfWords': numberOfWords,
      'clueSubmitted': true,
      'remainingGuesses': numberOfWords + 1,
      'canEndTurn': true,
      'log': FieldValue.arrayUnion([
        '${playerTeam?.toUpperCase()} Spymaster $spymasterName gave clue: ${clueController.text} ($numberOfWords)'
      ]),
    });

    clueController.clear();
  }

  Widget _buildGameLog() {
    List<String> log = List<String>.from(gameData['log'] ?? []);

    return Container(
      height: 100, // Fixed height for the log section
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 4),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              'Game Log',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              reverse: true, // Show most recent entries at the bottom
              itemCount: log.length,
              itemBuilder: (context, index) {
                final logEntry =
                    log[log.length - 1 - index]; // Reverse the order
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    logEntry,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTileContent(Map<String, dynamic> tile, int index) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final selectedBy = tile['selectedBy'];
    final bool isSelectedByCurrentUser =
        selectedBy != null && selectedBy['uid'] == currentUser?.uid;

    return Container(
      color: _getTileColor(tile),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tile['word'],
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (selectedBy != null) ...[
              SizedBox(height: 2),
              Text(
                selectedBy['name'].toString().split(' ')[0],
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                  color: selectedBy['team'] == 'blue'
                      ? Colors.blue[900]
                      : Colors.red[900],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (isSelectedByCurrentUser && tile['status'] != 'revealed') ...[
                SizedBox(height: 2),
                SizedBox(
                  height: 16,
                  width: 45,
                  child: ElevatedButton(
                    onPressed: () => _revealTile(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Submit',
                      style: TextStyle(fontSize: 8),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectTile(int index) async {
    if (isSpymaster) return;

    if (gameData['turn'] != playerTeam) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("It's not your team's turn!")),
      );
      return;
    }

    if (!gameData['clueSubmitted']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Wait for your Spymaster's clue!")),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final tiles = List.from(gameData['tiles']);
    final tile = tiles[index];
    if (tile['status'] == 'revealed') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("This tile has already been revealed!")),
      );
      return;
    }
    // Toggle selection when tapping the same tile
    if (tile['selectedBy']?['uid'] == currentUser.uid) {
      tiles[index]['selectedBy'] = null;
    } else {
      //Check if player still has guesses available
      int playerGuessCount =
          tiles.where((t) => t['selectedBy']?['uid'] == currentUser.uid).length;

      // if (playerGuessCount >= gameData['remainingGuesses']) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text("You've used all your available guesses!")),
      //   );
      //   return;
      // }

      // Add new selection
      tiles[index]['selectedBy'] = {
        'uid': currentUser.uid,
        'name': currentUser.displayName,
        'team': playerTeam,
      };
    }

    await FirebaseFirestore.instance
        .collection('gameRooms')
        .doc(widget.roomId)
        .update({'tiles': tiles});
  }
  // Widget _buildSubmitGuessButton() {
  //   if (isSpymaster ||
  //       gameData['turn'] != playerTeam ||
  //       selectedTileIndex == null) {
  //     return SizedBox.shrink();
  //   }

  //   return ElevatedButton(
  //     onPressed: () {
  //       if (selectedTileIndex != null) {
  //         _revealTile(int.parse(selectedTileIndex!));
  //         setState(() {
  //           selectedTiles.clear();
  //           selectedTileIndex = null;
  //         });
  //       }
  //     },
  //     style: ElevatedButton.styleFrom(
  //       backgroundColor: Colors.green,
  //       padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  //     ),
  //     child: Text('Submit Guess'),
  //   );
  // }

  Future<void> _checkAndStartNewGame() async {
    final roomDoc = await FirebaseFirestore.instance
        .collection('gameRooms')
        .doc(widget.roomId)
        .get();

    if (!roomDoc.exists) {
      await startNewGame(widget.roomId);
    }
  }

  Future<void> startNewGame(String? roomId) async {
    List<String> words = [
      'apple',
      'banana',
      'car',
      'dog',
      'elephant',
      'fish',
      'grape',
      'hat',
      'ice',
      'juice',
      'kangaroo',
      'lion',
      'monkey',
      'nut',
      'orange',
      'pizza',
      'quilt',
      'rocket',
      'sun',
      'tiger',
      'umbrella',
      'vampire',
      'water',
      'xylophone',
      'yellow',
    ];

    // Create tiles with their team assignments
    List<Map<String, dynamic>> tiles = [];

    // Add blue tiles (9)
    for (int i = 0; i < 9; i++) {
      tiles.add({
        'word': '',
        'status': 'hidden',
        'team': 'blue',
        'selectedBy': null,
      });
    }

    // Add red tiles (8)
    for (int i = 0; i < 8; i++) {
      tiles.add({
        'word': '',
        'status': 'hidden',
        'team': 'red',
        'selectedBy': null,
      });
    }

    // Add neutral tiles (7)
    for (int i = 0; i < 7; i++) {
      tiles.add({
        'word': '',
        'status': 'hidden',
        'team': 'white',
        'selectedBy': null,
      });
    }

    // Add assassin tile (1)
    tiles.add({
      'word': '',
      'status': 'hidden',
      'team': 'black',
      'selectedBy': null,
    });

    // Shuffle both the words and tiles
    words.shuffle(Random());
    tiles.shuffle(Random());

    // Assign words to tiles
    for (int i = 0; i < tiles.length; i++) {
      tiles[i]['word'] = words[i];
    }

    await FirebaseFirestore.instance.collection('gameRooms').doc(roomId).set({
      'tiles': tiles,
      'turn': 'blue',
      'blueScore': 9,
      'redScore': 8,
      'log': [],
      'clueSubmitted': false,
      'remainingGuesses': 0,
      'canEndTurn': false,
      'currentClue': '',
      'numberOfWords': 0,
      'gameOver': false,
      'winner': '',
    });

    print("Cards have been distributed and saved.");
  }

  // Future<void> _submitClue() async {
  //   if (clueController.text.isEmpty || numberOfWords < 1) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //           content: Text("Please enter a valid clue and number of words")),
  //     );
  //     return;
  //   }

  //   if (gameData['turn'] != playerTeam) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("It's not your team's turn!")),
  //     );
  //     return;
  //   }

  //   if (gameData['clueSubmitted'] == true) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Clue has already been given for this turn!")),
  //     );
  //     return;
  //   }

  //   await FirebaseFirestore.instance
  //       .collection('gameRooms')
  //       .doc(widget.roomId)
  //       .update({
  //     'currentClue': clueController.text,
  //     'numberOfWords': numberOfWords,
  //     'clueSubmitted': true,
  //     'remainingGuesses': numberOfWords,
  //     'canEndTurn': true,
  //   });

  //   clueController.clear();
  //   print("Clue submitted with $numberOfWords words allowed");
  // }

  Future<void> _endTurn() async {
    String nextTurn = (gameData['turn'] == 'blue') ? 'red' : 'blue';
    String currentTurn = gameData['turn'];

    // Check for end game conditions
    bool isGameOver = false;
    String winner = '';
    //clear team selections
    // Create a deep copy of the tiles array
    List<Map<String, dynamic>> updatedTiles = gameData['tiles'].map((tile) {
      var newTile = Map<String, dynamic>.from(tile);
      if (newTile['selectedBy']?['team'] == currentTurn) {
        newTile['selectedBy'] = null;
      }
      return newTile;
    }).toList();

    // Check if any team's words are all revealed
    int blueWordsLeft = gameData['tiles']
        .where((tile) => tile['team'] == 'blue' && tile['status'] != 'revealed')
        .length;
    int redWordsLeft = gameData['tiles']
        .where((tile) => tile['team'] == 'red' && tile['status'] != 'revealed')
        .length;

    if (blueWordsLeft == 0) {
      isGameOver = true;
      winner = 'blue';
    } else if (redWordsLeft == 0) {
      isGameOver = true;
      winner = 'red';
    }

    // Check if the black word is revealed
    bool blackWordRevealed = gameData['tiles']
        .any((tile) => tile['team'] == 'black' && tile['status'] == 'revealed');

    if (blackWordRevealed) {
      isGameOver = true;
      winner = (gameData['turn'] == 'blue') ? 'red' : 'blue';
    }

    if (isGameOver) {
      await FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(widget.roomId)
          .update({
        'gameOver': true,
        'winner': winner,
      });

      _showGameOverDialog(winner); // Show Game Over dialog
      return;
    }
    // List<Map<String, dynamic>> updatedTiles = List.from(gameData['tiles']);
    // for (int i = 0; i < updatedTiles.length; i++) {
    //   if (updatedTiles[i]['selectedBy']?['team'] == gameData['turn']) {
    //     updatedTiles[i]['selectedBy'] = null;
    //   }
    // }

    // Update the game state for the next turn
    try {
      // First, update just the tiles to clear selections
      await FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(widget.roomId)
          .update({
        'tiles': updatedTiles,
      });
      setState(() {
        gameData = {
          ...gameData,
          'tiles': updatedTiles,
          'turn': nextTurn,
          'currentClue': '',
          'numberOfWords': 0,
          'clueSubmitted': false,
          'remainingGuesses': 0,
          'canEndTurn': false,
        };
      });

      // Then update the rest of the game state
      await FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(widget.roomId)
          .update({
        'turn': nextTurn,
        'currentClue': '',
        'numberOfWords': 0,
        'clueSubmitted': false,
        'remainingGuesses': 0,
        'canEndTurn': false,
        'log': FieldValue.arrayUnion(
            ['${currentTurn.toUpperCase()} team\'s turn ended']),
      });

      print("Turn ended. Selections cleared for ${currentTurn} team.");
      print(
          "Updated tiles: ${updatedTiles.where((tile) => tile['selectedBy'] != null).length} selections remaining");
    } catch (e) {
      print("Error ending turn: $e");
    }
    print("Turn ended. It's now $nextTurn's turn.");
  }

  void _showGameOverDialog(String winner) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Game Over"),
          content: Text("$winner team has won the game!"),
          actions: [
            TextButton(
              onPressed: () async {
                // Delete the game room document
                await FirebaseFirestore.instance
                    .collection('gameRooms')
                    .doc(widget.roomId)
                    .delete()
                    .then((_) => print("Game room deleted successfully"))
                    .catchError((e) => print("Error deleting game room: $e"));

                // Delete the room document
                await FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(widget.roomId)
                    .delete()
                    .then((_) => print("Room deleted successfully"))
                    .catchError((e) => print("Error deleting room: $e"));

                // Navigate back to the homepage
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => HomePage(),
                  ),
                );
              },
              child: Text("Go Home"),
            ),
          ],
        );
      },
    );
  }

// Future<void> deleteRoomAndGameRoom() async {
//   try {
//     // Delete the game room document from 'gameRooms' collection
//     await FirebaseFirestore.instance
//         .collection('gameRooms')
//         .doc(widget.roomId)
//         .delete();

//     print("Game room document deleted successfully!");

//     // Delete the room document from 'rooms' collection
//     await FirebaseFirestore.instance
//         .collection('rooms')
//         .doc(widget.roomId)
//         .delete();

//     print("Room document deleted successfully!");

//     // Navigate players to the home page or a suitable fallback page
//     Navigator.of(context).pushReplacement(
//       MaterialPageRoute(
//         builder: (context) => HomePage(),
//       ),
//     );
//   } catch (e) {
//     print("Error while deleting room and game room: $e");
//   }
// }

  AppBar _buildScoreAppBar() {
    if (gameData.isEmpty) {
      return AppBar(
        backgroundColor: Colors.grey[900],
      );
    }
    return AppBar(
      backgroundColor: Colors.grey[900],
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Blue: ${gameData['blueScore'] ?? 9} left',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          Text(
            'VS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Red: ${gameData['redScore'] ?? 8} left',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _revealTile(int index) async {
    if (gameData['turn'] != playerTeam) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("It's not your team's turn!")),
      );
      return;
    }

    if (isSpymaster) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Spymasters cannot reveal tiles!")),
      );
      return;
    }

    if (!gameData['clueSubmitted']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Wait for your Spymaster's clue!")),
      );
      return;
    }

    if (gameData['remainingGuesses'] <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No more guesses allowed!")),
      );
      return;
    }

    final tile = gameData['tiles'][index];
    if (tile['status'] == 'revealed') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("This tile is already revealed!")),
      );
      return;
    }

    String tileTeam = tile['team'];
    String currentTurn = gameData['turn'];
    int remainingGuesses = gameData['remainingGuesses'] - 1;

    // Update the game state
    Map<String, dynamic> updates = {
      'tiles': List.from(gameData['tiles'])..[index]['status'] = 'revealed',
      'remainingGuesses': remainingGuesses,
      'log': FieldValue.arrayUnion([
        '${currentTurn.toUpperCase()} team revealed ${tile['word']} (${tile['team']} tile)'
      ]),
    };

    // Handle scoring
    if (tileTeam == 'blue') {
      updates['blueScore'] = FieldValue.increment(-1);
      if ((gameData['blueScore'] ?? 0) <= 1) {
        updates['gameOver'] = true;
        updates['winner'] = 'blue';
      }
    } else if (tileTeam == 'red') {
      updates['redScore'] = FieldValue.increment(-1);
      if ((gameData['redScore'] ?? 0) <= 1) {
        updates['gameOver'] = true;
        updates['winner'] = 'red';
      }
    }

    // Handle turn logic
    if (tileTeam == 'black') {
      updates['gameOver'] = true;
      updates['winner'] = currentTurn == 'blue' ? 'red' : 'blue';
    } else if (tileTeam != currentTurn || remainingGuesses <= 0) {
      // Check remaining guesses
      // End turn and reset for next team
      updates['turn'] = currentTurn == 'blue' ? 'red' : 'blue';
      updates['currentClue'] = '';
      updates['numberOfWords'] = 0;
      updates['clueSubmitted'] = false;
      updates['remainingGuesses'] = 0;
      updates['canEndTurn'] = false;

      // Add turn end message to log
      updates['log'] = FieldValue.arrayUnion([
        '${currentTurn.toUpperCase()} team\'s turn ended' +
            (remainingGuesses <= 0
                ? ' (out of guesses)'
                : ' (revealed wrong color)')
      ]);
    }

    // Apply updates
    await FirebaseFirestore.instance
        .collection('gameRooms')
        .doc(widget.roomId)
        .update(updates);

    // Show game over message if applicable
    if (updates.containsKey('winner')) {
      _showGameOverDialog(updates['winner']);
    }
  }

  Widget _buildClueSection() {
    if (!isSpymaster) return Container();

    return Column(
      children: [
        TextField(
          controller: clueController,
          decoration: InputDecoration(
            labelText: 'Enter Clue',
            border: OutlineInputBorder(),
          ),
        ),
        //SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Number of Words:', style: TextStyle(fontSize: 16)),
            DropdownButton<int>(
              value: numberOfWords,
              onChanged: (int? newValue) {
                setState(() {
                  numberOfWords = newValue!;
                });
              },
              items: List.generate(9, (index) {
                return DropdownMenuItem<int>(
                  value: index + 1,
                  child: Text('${index + 1}'),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGameStatus() {
    // Add null checks and default values
    bool clueSubmitted = gameData['clueSubmitted'] ?? false;
    String currentTurn = gameData['turn'] ?? '';
    String currentClue = gameData['currentClue'] ?? '';
    int numWords = gameData['numberOfWords'] ?? 0;
    int remainingGuesses = gameData['remainingGuesses'] ?? 0;
    bool canEndTurn = gameData['canEndTurn'] ?? false;

    if (!clueSubmitted) {
      return Text(
        isSpymaster && currentTurn == playerTeam
            ? "Give your team a clue!"
            : "Waiting for Spymaster's clue...",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      );
    }

    return Column(
      children: [
        Text(
          "Current Clue: $currentClue ($numWords)",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          "Remaining Guesses: $remainingGuesses",
          style: TextStyle(fontSize: 16),
        ),
        if (currentTurn == playerTeam && !isSpymaster)
          ElevatedButton(
            onPressed: _endTurn,
            child: Text('End Turn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
      ],
    );
  }

  Color _getTileColor(Map<String, dynamic> tile) {
    if (tile['status'] == 'revealed' || isSpymaster) {
      switch (tile['team']) {
        case 'blue':
          return Colors.blue;
        case 'red':
          return Colors.red;
        case 'black':
          return const Color.fromARGB(255, 58, 48, 48);
        default:
          return const Color.fromARGB(255, 232, 229, 229);
      }
    }
    return Colors.brown[100]!;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    String currentTurn = gameData['turn'] ?? 'blue';
    return Scaffold(
      backgroundColor: currentTurn == 'blue'
          ? const Color.fromARGB(255, 3, 72, 128)
          : const Color.fromARGB(255, 140, 0, 0),
      appBar: _buildScoreAppBar(),
      body: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                color: Colors.black.withOpacity(0),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildGameStatus(),
                if (isSpymaster) _buildClueSection(),
                if (isSpymaster)
                  ElevatedButton(
                    onPressed: _submitClue,
                    child: Text('Submit Clue'),
                  ),
                //SizedBox(height: 25),
                //_buildSubmitGuessButton(),
                SizedBox(height: 10),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: gameData['tiles']?.length ?? 0,
                    itemBuilder: (context, index) {
                      final tile = gameData['tiles'][index];
                      return GestureDetector(
                        onTap: () => _selectTile(index),
                        child: Card(
                          child: _buildTileContent(tile, index),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),
                _buildGameLog(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
