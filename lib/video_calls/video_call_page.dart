import 'package:flutter/material.dart';
import 'video_call_services.dart';
import 'video_call_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> checkCameraPermission() async {
  PermissionStatus cameraStatus = await Permission.camera.status;
  PermissionStatus micStatus = await Permission.microphone.status;

  // Request permissions if not granted
  if (cameraStatus.isDenied) {
    await Permission.camera.request();
  }
  if (micStatus.isDenied) {
    await Permission.microphone.request();
  }

  if (cameraStatus.isGranted && micStatus.isGranted) {
    print("Camera and Microphone permissions granted");
  } else {
    print("Permissions denied or permanently denied");
  }
}

int hostUid = FirebaseAuth.instance.currentUser?.uid.hashCode ?? 0;

class VideoCallPage extends StatefulWidget {
  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  bool _isInitialized = false;
  bool _isLoading = true; // Track loading state for video initialization

  @override
  void initState() {
    super.initState();
    _initializeVideoCall();
    int currentUserUid = FirebaseAuth.instance.currentUser?.uid.hashCode ?? 0;
    print("Current User UID as int: $currentUserUid");

    checkCameraPermission(); // Ensure permissions are requested at the start
  }

  // Initialize Agora SDK
  Future<void> _initializeVideoCall() async {
    print("Starting Agora initialization...");
    try {
      // Try initializing Agora with the appId and hostUid
      await VideoCallService.initializeAgora(
          "aafa3e4b023041bf9cf09b6aebb7bf14", hostUid);
      print("Agora initialization successful");
    } catch (e) {
      print("Agora initialization failed: $e");
    }
    setState(() {
      _isInitialized = true;
      if (_isInitialized) print("true");
      _isLoading = false; // Stop loading once initialization is complete
      print("Video Call Initialized: $_isInitialized");
    });
  }

  @override
  void dispose() {
    VideoCallService.leaveChannel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Video Call")),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator() // Show loading until initialization is complete
            : _isInitialized
                ? // In your VideoCallPage or where the widget is used
                VideoCallWidget(
                    hostUid:
                        FirebaseAuth.instance.currentUser?.uid.hashCode ?? 0)
                : Text("Failed to initialize video call."),
      ),
    );
  }
}
