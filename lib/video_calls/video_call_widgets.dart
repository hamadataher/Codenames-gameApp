import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'video_call_services.dart';

class VideoCallWidget extends StatelessWidget {
  final int hostUid;

  VideoCallWidget({required this.hostUid});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Local video view (host's own video)
        AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: VideoCallService.engine,
            canvas: VideoCanvas(uid: hostUid),  // Use hostUid for local view
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: VideoCallService.engine,
              canvas: VideoCanvas(uid: 1),  // Use remote user's UID (you can dynamically change this)
            ),
          ),
        ),
      ],
    );
  }
}
