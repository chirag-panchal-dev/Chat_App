import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/firebase/media_url_provider.dart';
import '../../../../core/l10n/l10n_ext.dart';

/// Full-screen video player: tap to play/pause, scrub along the bottom.
class VideoViewerScreen extends ConsumerStatefulWidget {
  const VideoViewerScreen({super.key, required this.path});
  final String path;

  @override
  ConsumerState<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends ConsumerState<VideoViewerScreen> {
  VideoPlayerController? _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final url = await ref.read(mediaUrlProvider(widget.path).future);
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      _c = c;
      await c.initialize();
      c.addListener(() {
        if (mounted) setState(() {});
      });
      await c.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = _c;
    final ready = c != null && c.value.isInitialized && !_failed;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child:
                  _failed
                      ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l.videoPlayError,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () {
                              ref.invalidate(mediaUrlProvider(widget.path));
                              _c?.dispose();
                              _c = null;
                              _load();
                            },
                            child: Text(l.retry),
                          ),
                        ],
                      )
                      : !ready
                      ? const CircularProgressIndicator()
                      : GestureDetector(
                        onTap: () => c.value.isPlaying ? c.pause() : c.play(),
                        child: AspectRatio(
                          aspectRatio: c.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(c),
                              if (!c.value.isPlaying)
                                const Icon(
                                  Icons.play_circle_fill_rounded,
                                  size: 72,
                                  color: Colors.white70,
                                ),
                            ],
                          ),
                        ),
                      ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                tooltip: l.closeViewer,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (ready)
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: VideoProgressIndicator(
                  c,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white30,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
