import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoCallService {
  static const String appId = "aafa3e4b023041bf9cf09b6aebb7bf14";
  static const String channelName = "game_room"; // Example channel name
  static late RtcEngine _engine;

  // Initialize the Agora RTC engine
  static Future<void> initializeAgora(String appId, int hostUid) async {
    try {
      print("Requesting permissions...");
      await requestPermissions();
    } catch (e) {
      print("Error requesting permissions: $e");
    }

    try {
      print("Creating Agora RTC engine...");
      _engine = await createAgoraRtcEngine();
    } catch (e) {
      print("Error creating Agora RTC engine: $e");
    }

    try {
      print("Initializing Agora engine...");
      await _engine.initialize(RtcEngineContext(appId: appId));
    } catch (e) {
      print("Error initializing Agora engine: $e");
    }

    try {
      print("Setting up local video...");
      int localViewId = 12345;
      await _engine.setupLocalVideo(VideoCanvas(
        uid: hostUid,
        view: localViewId,
      ));
    } catch (e) {
      print("Error setting up local video: $e");
    }

    // Register event handler
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          print("Joined channel successfully: ${connection.channelId}");
        },
        onError: (errorCode, errorMessage) {
          print(
              "Failed to join channel. Error code: $errorCode, message: $errorMessage");
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print("User $remoteUid joined the channel");
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          print("User $remoteUid went offline");
        },
      ),
    );

    // Join the channel using the host's UID
    await _engine.joinChannel(
        token:
            "007eJxTYODOfv/4WVnc3L6TFnuXTo449DJf+4PiiewbqbevTM4Vl9+lwJCYmJZonGqSZGBkbGBimJRmmZxmYJlklpialGSelGZoEju5ML0hkJHhQ8UxZkYGCATxORnSE3NT44vy83MZGAD8PCUb", // Token
        channelId: channelName, // Channel name
        uid: hostUid, // Host's UID
        options: ChannelMediaOptions() // ChannelMediaOptions
        );
    print(hostUid);
  }

  static get engine => _engine;
  // Request permissions for microphone and camera
  static Future<void> requestPermissions() async {
    await [
      Permission.microphone,
      Permission.camera,
    ].request();
  }

  // Leave the Agora channel
  static void leaveChannel() {
    _engine.leaveChannel();
  }
}
