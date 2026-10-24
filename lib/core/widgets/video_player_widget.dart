// lib/core/widgets/video_player_widget.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_colors.dart';

/// รองรับ states: loading/buffering/playing/paused/error/locked
/// videoUrl ต้องมาจาก getVideoAccessUrl() (Signed URL ที่หมดอายุ) เสมอ ไม่ embed URL ถาวร
class VideoPlayerWidget extends StatefulWidget {
  final String? videoUrl; // null = locked (ยังไม่ enroll)
  final void Function(Duration position, Duration total)? onProgress;

  const VideoPlayerWidget({super.key, required this.videoUrl, this.onProgress});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.videoUrl == null) return; // locked state, ไม่ต้องโหลด
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
      await controller.initialize();
      controller.addListener(_onTick);
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'โหลดวิดีโอไม่สำเร็จ';
        _loading = false;
      });
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    widget.onProgress?.call(c.value.position, c.value.duration);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Locked state — ยังไม่ enroll
    if (widget.videoUrl == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: AppColors.gray900,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, color: Colors.white54, size: 48),
                SizedBox(height: 8),
                Text('บทเรียนนี้ถูกล็อก กรุณาซื้อคอร์สก่อน', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      );
    }

    // Error state
    if (_error != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: AppColors.gray900,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.white)),
                TextButton(
                  onPressed: () => setState(() { _error = null; _loading = true; _init(); }),
                  child: const Text('ลองใหม่', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Loading state
    if (_loading || _controller == null) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: AppColors.gray900,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    final controller = _controller!;
    // Playing/Paused/Buffering state
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(controller),
          if (controller.value.isBuffering)
            const CircularProgressIndicator(color: Colors.white),
          _Controls(controller: controller),
        ],
      ),
    );
  }
}

class _Controls extends StatefulWidget {
  final VideoPlayerController controller;
  const _Controls({required this.controller});
  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black54,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              icon: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
              onPressed: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
            ),
            Expanded(
              child: VideoProgressIndicator(c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: AppColors.primary)),
            ),
            IconButton(
              icon: const Icon(Icons.fullscreen, color: Colors.white),
              onPressed: () {}, // TODO: fullscreen toggle
            ),
          ],
        ),
      ),
    );
  }
}