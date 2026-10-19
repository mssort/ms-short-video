
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'archive_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MsShortsApp());
}

class MsShortsApp extends StatelessWidget {
  const MsShortsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MS SHORTS VIP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const VideoFeedPage(),
    );
  }
}

class VideoFeedPage extends StatefulWidget {
  const VideoFeedPage({super.key});

  @override
  State<VideoFeedPage> createState() => _VideoFeedPageState();
}

class _VideoFeedPageState extends State<VideoFeedPage> {
  final ArchiveService _service = ArchiveService();
  final PageController _pageController = PageController();

  List<ArchiveVideo> _videos = [];
  VideoPlayerController? _controller;

  bool _loading = true;
  bool _changingVideo = false;
  String? _error;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final videos = await _service.fetchVideos();

      if (!mounted) return;

      setState(() {
        _videos = videos;
        _loading = false;
      });

      if (videos.isNotEmpty) {
        await _playVideo(0);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'वीडियो लोड नहीं हुईं। इंटरनेट जाँचकर दोबारा कोशिश करें।';
      });
    }
  }

  Future<void> _playVideo(int index) async {
    if (_changingVideo ||
        index < 0 ||
        index >= _videos.length) {
      return;
    }

    _changingVideo = true;
    final previous = _controller;
    _controller = null;

    try {
      if (previous != null) {
        await previous.pause();
        await previous.dispose();
      }

      if (!mounted) return;

      final next = VideoPlayerController.networkUrl(
        Uri.parse(_videos[index].url),
      );

      _controller = next;
      await next.initialize();

      if (!mounted || _controller != next) {
        await next.dispose();
        return;
      }

      await next.setLooping(true);
      await next.play();

      if (mounted) {
        setState(() {
          _currentIndex = index;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'यह वीडियो नहीं चल सकी। अगली वीडियो आज़माएँ।';
        });
      }
    } finally {
      _changingVideo = false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'MS SHORTS VIP',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _loadVideos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh videos',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _videos.isEmpty
              ? _message(
                  _error!,
                  onRetry: _loadVideos,
                )
              : _videos.isEmpty
                  ? _message(
                      'अभी कोई वीडियो नहीं मिली।',
                      onRetry: _loadVideos,
                    )
                  : PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: _videos.length,
                      onPageChanged: (index) {
                        setState(() {
                          _error = null;
                        });
                        _playVideo(index);
                      },
                      itemBuilder: (context, index) {
                        final video = _videos[index];
                        final active = index == _currentIndex;
                        final player = active ? _controller : null;

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Colors.black),
                            if (player != null &&
                                player.value.isInitialized)
                              Center(
                                child: AspectRatio(
                                  aspectRatio:
                                      player.value.aspectRatio,
                                  child: VideoPlayer(player),
                                ),
                              )
                            else if (active)
                              const Center(
                                child: CircularProgressIndicator(),
                              ),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 24,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    video.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('@${video.uploader}'),
                                  const SizedBox(height: 12),
                                  if (active && player != null)
                                    IconButton(
                                      onPressed: () {
                                        if (player.value.isPlaying) {
                                          player.pause();
                                        } else {
                                          player.play();
                                        }
                                        setState(() {});
                                      },
                                      icon: Icon(
                                        player.value.isPlaying
                                            ? Icons.pause_circle
                                            : Icons.play_circle,
                                        size: 42,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
    );
  }

  Widget _message(
    String message, {
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('दोबारा कोशिश करें'),
            ),
          ],
        ),
      ),
    );
  }
}
