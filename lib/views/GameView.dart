import 'package:codenames_bgu/views/homepage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:ui';
import 'dart:async';

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
  Timer? spymasterTimer;
  int remainingTime = 90; // 90 seconds for spymaster
  bool isTimerActive = false;

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
        final newGameData = snapshot.data() ?? {};

        // Check if turn has changed
        if (newGameData['turn'] != gameData['turn']) {
          // Reset and start timer if it's spymaster's turn
          if (isSpymaster && newGameData['turn'] == playerTeam) {
            startSpymasterTimer();
          } else {
            cancelSpymasterTimer();
          }
        }

        setState(() {
          gameData = newGameData;
        });

        // If gameOver is true, show the game over dialog
        if (gameData['gameOver'] == true) {
          cancelSpymasterTimer();
          String winner = gameData['winner'] ?? 'No team';
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
    cancelSpymasterTimer();
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
  void startSpymasterTimer() {
    isTimerActive = true;
    remainingTime = 90;
    spymasterTimer?.cancel(); // Cancel any existing timer

    spymasterTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingTime > 0) {
          remainingTime--;
        } else {
          // Time's up - end spymaster's turn
          timer.cancel();
          isTimerActive = false;
          _autoEndTurn();
        }
      });
    });
  }

  void cancelSpymasterTimer() {
    spymasterTimer?.cancel();
    isTimerActive = false;
  }

  Future<void> _autoEndTurn() async {
    if (!mounted) return;

    String currentTurn = gameData['turn'];
    String nextTurn = (currentTurn == 'blue') ? 'red' : 'blue';

    try {
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
            ['${currentTurn.toUpperCase()} Spymaster ran out of time!']),
      });

      setState(() {
        remainingTime = 90;
        isTimerActive = false;
      });
    } catch (e) {
      print("Error auto-ending turn: $e");
    }
  }

  @override
  void dispose() {
    spymasterTimer?.cancel();
    super.dispose();
  }

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
    if (roomId == null) return;

    try {
      // Fetch the selected language from Firestore
      DocumentSnapshot roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .get();

      if (!roomDoc.exists) {
        print("Room document does not exist.");
        return;
      }

      Map<String, dynamic>? roomData = roomDoc.data() as Map<String, dynamic>?;
      String selectedLanguage = roomData?['language'] ?? 'English';

      // Define word lists for different languages
      Map<String, List<String>> wordLists = {
        'English': [
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
          'airplane',
          'balloon',
          'candle',
          'door',
          'egg',
          'fire',
          'goat',
          'house',
          'jungle',
          'koala',
          'leaf',
          'moon',
          'night',
          'octopus',
          'pencil',
          'queen',
          'robot',
          'star',
          'tree',
          'unicorn',
          'volcano',
          'whale',
          'x-ray',
          'yarn',
          'zebra',
          'ant',
          'ball',
          'cat',
          'doghouse',
          'elephant',
          'fishbowl',
          'giraffe',
          'hurricane',
          'island',
          'jet',
          'key',
          'log',
          'mountain',
          'neutron',
          'octopus',
          'plane',
          'quicksand',
          'rain',
          'sea',
          'train',
          'underwater',
          'vacuum',
          'wind',
          'xylophone',
          'yellowstone',
          'zone',
          'acorn',
          'butterfly',
          'clown',
          'dinosaur',
          'eggplant',
          'feather',
          'garden',
          'hiking',
          'ink',
          'jellyfish',
          'kiwi',
          'lava',
          'mushroom',
          'nest',
          'owl',
          'pyramid',
          'quicksand',
          'radio',
          'skyscraper',
          'treehouse',
          'umbrella',
          'volcano',
          'waterfall',
          'xenon',
          'yogurt',
          'zeppelin',
          'astronaut',
          'ballerina',
          'cliff',
          'dolphin',
          'earthquake',
          'fairy',
          'glove',
          'haunted',
          'illuminated',
          'jungle',
          'knight',
          'lighthouse',
          'maple',
          'needle',
          'octagon',
          'puzzle',
          'quicksilver',
          'rodeo',
          'sunflower',
          'tornado',
          'umbrella',
          'vulture',
          'wolverine',
          'x-ray',
          'yawn',
          'zigzag',
          'acrobats',
          'ballet',
          'circus',
          'diamond',
          'envelope',
          'fountain',
          'grapefruit',
          'helicopter',
          'insect',
          'jungle',
          'kite',
          'lighthouse',
          'marshmallow',
          'nerd',
          'oasis',
          'plumber',
          'quilt',
          'radioactive',
          'shadow',
          'turtle',
          'unicorn',
          'volcano',
          'watermelon',
          'xylophone',
          'yellow',
          'zombie',
          'aeroplane',
          'broccoli',
          'clock',
          'denim',
          'elephant',
          'fairy',
          'gorilla',
          'hippopotamus',
          'iron',
          'juice',
          'kite',
          'lemon',
          'mouse',
          'nightmare',
          'piano',
          'quilt',
          'reindeer',
          'saxophone',
          'tiger',
          'underwater',
          'vulture',
          'whale',
          'xylophone',
          'yak',
          'zebra',
          'antelope',
          'basketball',
          'catfish',
          'drum',
          'elephant',
          'foot',
          'guitar',
          'hockey',
          'iceberg',
          'jazz',
          'kettle',
          'lighthouse',
          'manatee',
          'noodles',
          'octopus',
          'parrot',
          'quail',
          'raccoon',
          'shark',
          'tree',
          'ukulele',
          'vacuum',
          'woodpecker',
          'xenophobia',
          'yo-yo',
          'zinc',
          'airplane',
          'bulb',
          'crystal',
          'dog',
          'eagle',
          'fountain',
          'giraffe',
          'hurricane',
          'ink',
          'jellyfish',
          'kitten',
          'lighthouse',
          'marble',
          'noodle',
          'pencil',
          'quicksilver',
          'river',
          'sun',
          'tiger',
          'umbrella',
          'violet',
          'water',
          'yogurt',
          'zebra',
          'abacus',
          'bird',
          'cup',
          'drum',
          'elephant',
          'furnace',
          'grass',
          'hamster',
          'inkwell',
          'juice',
          'keypad',
          'letter',
          'mosaic',
          'nutmeg',
          'oven',
          'parrot',
          'quilt',
          'robot',
          'strawberry',
          'tornado',
          'uncle',
          'volcano',
          'whistle',
          'x-ray',
          'yarn',
          'zebra',
          'accordion',
          'balloon',
          'cloud',
          'doghouse',
          'eggplant',
          'fan',
          'ghost',
          'hunter',
          'iPhone',
          'jacket',
          'knife',
          'lollipop',
          'mousepad',
          'nightmare',
          'pen',
          'quilt',
          'rocket',
          'snowflake',
          'teacup',
          'underwear',
          'vulture',
          'watch',
          'yawn',
          'zephyr',
          'astronaut',
          'backpack',
          'cloud',
          'disco',
          'earring',
          'fall',
          'grape',
          'helicopter',
          'illuminator',
          'jacket',
          'key',
          'lighthouse',
          'mushroom',
          'noodle',
          'olympics',
          'puzzle',
          'quiet',
          'rabbit',
          'saxophone',
          'treehouse',
          'universe',
          'volcano',
          'wildlife',
          'xenon',
          'yellow',
          'zookeeper'
        ],
        'Arabic': [
          'تفاحة',
          'موز',
          'سيارة',
          'كلب',
          'فيل',
          'سمك',
          'عنب',
          'قبعة',
          'ثلج',
          'عصير',
          'كنغر',
          'أسد',
          'قرد',
          'جوز',
          'برتقال',
          'بيتزا',
          'لحاف',
          'صاروخ',
          'شمس',
          'نمر',
          'مظلة',
          'مصاص دماء',
          'ماء',
          'إكسيلفون',
          'أصفر',
          'طائرة',
          'بالون',
          'شمعة',
          'باب',
          'بيض',
          'نار',
          'ماعز',
          'منزل',
          'غابة',
          'كوالا',
          'ورقة',
          'قمر',
          'ليل',
          'أخطبوط',
          'قلم',
          'ملكة',
          'روبوت',
          'نجم',
          'شجرة',
          'وحيد القرن',
          'بركان',
          'حوت',
          'أشعة إكس',
          'خيط',
          'زebra',
          'نملة',
          'كرة',
          'قطة',
          'منزل الكلب',
          'أفيال',
          'حوض السمك',
          'زرافة',
          'إعصار',
          'جزيرة',
          'طائرة',
          'مفتاح',
          'سجل',
          'جبل',
          'نيوترون',
          'أخطبوط',
          'طائرة',
          'رمال متحركة',
          'مطر',
          'بحر',
          'قطار',
          'تحت الماء',
          'فراغ',
          'ريح',
          'أشعة إكس',
          'يلوستون',
          'منطقة',
          'بلوط',
          'فراشة',
          'مهرج',
          'ديناصور',
          'باذنجان',
          'ريشة',
          'حديقة',
          'تسلق الجبال',
          'حبر',
          'قنديل البحر',
          'كيوي',
          'حمم',
          'فطر',
          'عش',
          'بومة',
          'هرم',
          'رمال متحركة',
          'راديو',
          'ناطحة سحاب',
          'منزل الشجرة',
          'مظلة',
          'بركان',
          'شلال',
          'زينون',
          'زبادي',
          'منطاد',
          'رائد فضاء',
          'راقصة باليه',
          'منحدر',
          'دولفين',
          'زلزال',
          'جنية',
          'قفاز',
          'ممسوك',
          'مضيء',
          'غابة',
          'فارس',
          'منارة',
          'قيقب',
          'إبرة',
          'مثمن',
          'ألغاز',
          'فضة',
          'خطف',
          'شروق الشمس',
          'كلب البحر',
          'آلة موسيقية',
          'غراب',
          'غابة',
          'فنلندا',
          'مظلة',
          'قوس قزح',
          'حقيبة الظهر',
          'كرة سلة',
          'سمك الق catfish',
          'طبلة',
          'أفيال',
          'قدم',
          'غيتار',
          'هوكي',
          'جبل جليدي',
          'جاز',
          'غلاية',
          'منارة',
          'مهاجم',
          'خفافيش',
          'حيوان مائي',
          'نجمة البحر',
          'غروب',
          'قمر',
          'شاطئ',
          'أمواج',
          'أنابيب',
          'انفجار',
          'خريطة',
          'طبول',
          'شجرة',
          'شواطئ',
          'سكيت',
          'طائرة',
          'يوم الأرض',
          'حصان',
          'غسالة',
          'دب',
          'خنزير',
          'سيارة',
          'قلعة',
          'مفتاح',
          'قنينة',
          'فأر',
          'ساحرة',
          'مطر',
          'ريح',
          'كرة القدم',
          'معكرونة',
          'زلزال',
          'عاصفة',
          'بيت',
          'نجم',
          'زهرة',
          'شمسية',
          'أرنب',
          'سباحة',
          'مصور',
          'تي شيرت',
          'قميص',
          'قلادة',
          'حديقة الحيوانات',
          'سلة',
          'إقلاع',
          'هبوط',
          'مسبح',
          'قلب',
          'رمل',
          'لعبة',
          'كتابة',
          'مائدة',
          'رسومات',
          'ديك',
          'علم',
          'سبورة',
          'مسرح',
          'غرفة',
          'مطعم',
          'مقهى',
          'كتب',
          'سياحة',
          'منزل',
          'قائمة',
          'مرشدة',
          'جبل',
          'أنف',
          'تليفزيون',
          'ثلاجة',
          'أبواب',
          'شعر',
          'مفتاح',
          'أسطورة',
          'طب',
          'شخصية',
          'درس',
          'ألغاز',
          'مقلاة',
          'سفرة',
          'مغسلة',
          'حسابات',
          'لوحة',
          'كتابة',
          'عين',
          'نص',
          'زراعة',
          'معمل',
          'مهمة',
          'قصة',
          'دور',
          'خدمة',
          'خدمة شحن',
          'تسوق',
          'الحديقة',
          'جميع',
          'أجهزة',
          'عين',
          'جميلة',
          'الحب',
          'طاولة',
          'جري',
          'باب',
          'دواء',
          'علاج',
          'تدريب',
          'تنظيف',
          'قراءة',
          'هواء',
          'محطة',
          'سيارة',
          'قوات',
          'دليل',
          'كنز',
          'شريعة',
          'قناة',
          'قطار',
          'دبابة',
          'ترجمة',
          'مبنى',
          'نهاية',
          'حروب',
          'إيجابي',
          'كوكب',
          'كأس',
          'خيال',
          'معسكر',
          'المحارب',
          'حماية',
          'نقل',
          'ختم',
          'سياحة',
          'بيتزا',
          'صحة',
          'غرفة',
          'طعام',
          'وجبة',
          'قوة',
          'مباراة'
        ],
        'Hebrew': [
          'תפוח',
          'בננה',
          'מכונית',
          'כלב',
          'פיל',
          'דג',
          'ענבים',
          'כובע',
          'קרח',
          'מיץ',
          'קנגורו',
          'אריה',
          'קוף',
          'אגוז',
          'תפוז',
          'פיצה',
          'שמיכה',
          'רקטה',
          'שמש',
          'נמר',
          'מטריה',
          'ערפד',
          'מים',
          'קסילופון',
          'צהוב',
          'מטוס',
          'בלון',
          'נר',
          'דלת',
          'ביצה',
          'אש',
          'עז',
          'בית',
          'יער',
          'קואלה',
          'דף',
          'ירח',
          'לילה',
          'תמנון',
          'עט',
          'מלכה',
          'רובוט',
          'כוכב',
          'עץ',
          'קרנף',
          'הר געש',
          'לווייתן',
          'קרני רנטגן',
          'חוט',
          'זברה',
          'נמלה',
          'כדור',
          'חתול',
          'בית כלבים',
          'פיל',
          'אקווריום',
          'סופה',
          'אי',
          'מטוס',
          'מפתח',
          'ספר',
          'הר',
          'נויטרון',
          'תמנון',
          'מטוס',
          'חול',
          'גשם',
          'ים',
          'רכבת',
          'מתחת למים',
          'חלל',
          'רוח',
          'קרני רנטגן',
          'יוסטון',
          'אזור',
          'אלון',
          'פרפר',
          'ליצנים',
          'דינוזואר',
          'חציל',
          'נוצה',
          'גן',
          'טיפוס הרים',
          'דיו',
          'מדוזה',
          'קיווי',
          'לבה',
          'פטרייה',
          'קן',
          'ינשוף',
          'פירמידה',
          'חול',
          'רדיו',
          'גורדי שחקים',
          'בית על עץ',
          'מטריה',
          'הר געש',
          'מפלים',
          'זינון',
          'יוגורט',
          'כדור פורח',
          'אסטרונאוט',
          'בלרינה',
          'מדרון',
          'דולפין',
          'רעידת אדמה',
          'פיה',
          'כפפה',
          'נעול',
          'מואר',
          'יער',
          'רוכב',
          'מגדלור',
          'אדר',
          'מחט',
          'מצולע',
          'חידות',
          'כסף',
          'חטיפה',
          'זריחה',
          'כלב ים',
          'כלי נגינה',
          'עורב',
          'יער',
          'פינלנד',
          'מטריה',
          'קשת',
          'תיק גב',
          'כדורסל',
          'דג חתול',
          'תוף',
          'פיל',
          'רגל',
          'גיטרה',
          'הוקי',
          'קרחון',
          'מגדלור',
          'תוקף',
          'עטלפים',
          'חיית מים',
          'כוכב ים',
          'שקיעה',
          'ירח',
          'חוף',
          'גלים',
          'צינור',
          'פיצוץ',
          'מפה',
          'תופים',
          'עץ',
          'חופים',
          'סקייט',
          'מטוס',
          'יום כדור הארץ',
          'סוס',
          'מכונת כביסה',
          'דוב',
          'חזיר',
          'מכונית',
          'טירה',
          'מפתח',
          'בקבוק',
          'עכבר',
          'מכשפה',
          'גשם',
          'רוח',
          'כדורגל',
          'פסטה',
          'רעידת אדמה',
          'סופה',
          'בית',
          'כוכב',
          'פרח',
          'מטרייה',
          'ארנב',
          'שחייה',
          'צלם',
          'חולצה',
          'סוודר',
          'תכשיט',
          'גן חיות',
          'סל',
          'המראה',
          'נחיתה',
          'בריכה',
          'לב',
          'חול',
          'משחק',
          'כתיבה',
          'שולחן',
          'ציורים',
          'תרנגול',
          'דגל',
          'לוח לבן',
          'תיאטרון',
          'חדר',
          'מסעדה',
          'קפה',
          'ספרים',
          'תיירות',
          'בית',
          'רשימה',
          'מדריך',
          'הר',
          'אף',
          'טלויזיה',
          'מקרר',
          'דלתות',
          'שיער',
          'מפתח',
          'אגדה',
          'רפואה',
          'דמות',
          'שיעור',
          'חידות',
          'מחבת',
          'שולחן אוכל',
          'כיור',
          'חשבונאות',
          'לוח',
          'כתיבה',
          'עין',
          'טקסט',
          'חקלאות',
          'מעבדה',
          'משימה',
          'סיפור',
          'תפקיד',
          'שירות',
          'שירות משלוח',
          'קניות',
          'הגינה',
          'כל',
          'מכשירים',
          'עין',
          'יפה',
          'אהבה',
          'שולחן',
          'ריצה',
          'דלת',
          'תרופה',
          'טיפול',
          'אימון',
          'ניקוי',
          'קריאה',
          'אוויר',
          'תחנה',
          'מכונית',
          'כוחות',
          'מדריך',
          'אוצר',
          'חוק',
          'ערוץ',
          'רכבת',
          'טנק',
          'תרגום',
          'בניין',
          'סוף',
          'מלחמות',
          'חיובי',
          'כוכב',
          'גביע',
          'דמיון',
          'מחנה',
          'לוחם',
          'הגנה',
          'הובלה',
          'חותם',
          'תיירות',
          'פיצה',
          'בריאות',
          'חדר',
          'אוכל',
          'ארוחה',
          'כוח',
          'תחרות'
        ],
      };

// Get the words for the selected language and pick 25 random ones
      List<String> words =
          List.from(wordLists[selectedLanguage] ?? wordLists['English']!);
      words.shuffle(Random());
      List<String> selectedWords = words.take(25).toList();

// Create the tiles with team assignments
      List<Map<String, dynamic>> tiles = [];

// 9 Blue tiles
      for (int i = 0; i < 9; i++) {
        tiles.add({
          'word': '',
          'status': 'hidden',
          'team': 'blue',
          'selectedBy': null,
        });
      }

// 8 Red tiles
      for (int i = 0; i < 8; i++) {
        tiles.add({
          'word': '',
          'status': 'hidden',
          'team': 'red',
          'selectedBy': null,
        });
      }

// 7 White tiles (neutral)
      for (int i = 0; i < 7; i++) {
        tiles.add({
          'word': '',
          'status': 'hidden',
          'team': 'white',
          'selectedBy': null,
        });
      }

// 1 Black tile (assassin)
      tiles.add({
        'word': '',
        'status': 'hidden',
        'team': 'black',
        'selectedBy': null,
      });

// Shuffle the tile assignments randomly
      tiles.shuffle(Random());

// Assign the selected 25 words to the shuffled tiles
      for (int i = 0; i < tiles.length; i++) {
        tiles[i]['word'] = selectedWords[i];
      }

      // Save game data
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

      print("Cards have been distributed in $selectedLanguage and saved.");
    } catch (e) {
      print("Error starting new game: $e");
    }
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
    String currentTurn = gameData['turn'];
    String nextTurn = (currentTurn == 'blue') ? 'red' : 'blue';

    // Fix the type casting issue
    List<dynamic> originalTiles = List.from(gameData['tiles']);
    List<Map<String, dynamic>> updatedTiles = originalTiles.map((tile) {
      Map<String, dynamic> newTile = Map<String, dynamic>.from(tile);
      if (newTile['selectedBy']?['team'] == currentTurn) {
        newTile['selectedBy'] = null;
      }
      return newTile;
    }).toList();

    // Check for end game conditions
    bool isGameOver = false;
    String winner = '';

    // Check if any team's words are all revealed
    int blueWordsLeft = updatedTiles
        .where((tile) => tile['team'] == 'blue' && tile['status'] != 'revealed')
        .length;
    int redWordsLeft = updatedTiles
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
    bool blackWordRevealed = updatedTiles
        .any((tile) => tile['team'] == 'black' && tile['status'] == 'revealed');

    if (blackWordRevealed) {
      isGameOver = true;
      winner = (currentTurn == 'blue') ? 'red' : 'blue';
    }

    try {
      if (isGameOver) {
        await FirebaseFirestore.instance
            .collection('gameRooms')
            .doc(widget.roomId)
            .update({
          'gameOver': true,
          'winner': winner,
          'tiles': updatedTiles,
        });

        _showGameOverDialog(winner);
        return;
      }

      // Update game state if not game over
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
        'tiles': updatedTiles,
        'log': FieldValue.arrayUnion(
            ['${currentTurn.toUpperCase()} team\'s turn ended']),
      });

      print("Turn ended. Selections cleared for ${currentTurn} team.");
    } catch (e) {
      print("Error ending turn: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error ending turn: $e")),
      );
    }
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
    bool clueSubmitted = gameData['clueSubmitted'] ?? false;
    String currentTurn = gameData['turn'] ?? '';
    String currentClue = gameData['currentClue'] ?? '';
    int numWords = gameData['numberOfWords'] ?? 0;
    int remainingGuesses = gameData['remainingGuesses'] ?? 0;
    bool canEndTurn = gameData['canEndTurn'] ?? false;

    return Column(
      children: [
        // Turn Indicator and Timer in a Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Turn Indicator
            Container(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: currentTurn == playerTeam
                    ? (currentTurn == 'blue' ? Colors.blue : Colors.red)
                    : Colors.grey[700],
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
                border: currentTurn == playerTeam
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    currentTurn == playerTeam
                        ? Icons.arrow_forward
                        : Icons.hourglass_empty,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    currentTurn == playerTeam
                        ? "YOUR TURN!"
                        : "${currentTurn.toUpperCase()} TEAM'S TURN",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),

            // Timer
            if (isTimerActive)
              Container(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: remainingTime <= 10 ? Colors.red : Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '$remainingTime',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        // Rest of your existing content
        if (!clueSubmitted)
          Text(
            isSpymaster && currentTurn == playerTeam
                ? "Give your team a clue!"
                : "Waiting for Spymaster's clue...",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          )
        else
          Column(
            children: [
              Text(
                "Current Clue: $currentClue ($numWords)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "Remaining Guesses: $remainingGuesses",
                style: TextStyle(fontSize: 16),
              ),
              if (currentTurn == playerTeam && !isSpymaster && canEndTurn)
                ElevatedButton(
                  onPressed: _endTurn,
                  child: Text('End Turn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
            ],
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
