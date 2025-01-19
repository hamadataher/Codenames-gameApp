import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  static Future<void> requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }
}
