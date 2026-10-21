
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.redAccent,
          surface: Colors.black,
        ),
        useMaterial3: true,
      ),
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
  final PageController _pages = PageController();

  List<ArchiveVideo> _videos = [];
  VideoPlayerController? _player;

  final Set<String> _liked = {};
  final Set<String> _saved = {};
  final Set<String> _following = {};
  final Map<String, List<String>> _comments = {};

  int _index = 0;
  int _bottomIndex = 0;
  int _request = 0;
  bool _loading = true;
  bool _showFollowing = false;
  String? _error;

  List<ArchiveVideo> get _visibleVideos {
    if (!_showFollowing) return _videos;
    return _videos
        .where((v) => _following.contains(v.uploader))
        .toList();
  }

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
      final result = await _service.fetchVideos();

      if (!mounted) return;

      setState(() {
        _videos = result;
        _loading = false;
      });

      if (result.isEmpty) {
        setState(() {
          _error = 'अभी कोई सार्वजनिक वीडियो नहीं मिली।';
        });
        return;
      }

      await _play(0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'वीडियो लोड नहीं हुई। इंटरनेट जाँचें और Retry करें।';
      });
    }
  }

  Future<void> _play(int index) async {
    final list = _visibleVideos;
    if (index < 0 || index >= list.length) return;

    final ticket = ++_request;
    final old = _player;
    _player = null;

    if (mounted) {
      setState(() {
        _index = index;
        _error = null;
      });
    }

    if (old != null) {
      try {
        await old.pause();
        await old.dispose();
      } catch (_) {}
    }

    if (!mounted || ticket != _request) return;

    VideoPlayerController? next;

    try {
      next = VideoPlayerController.networkUrl(
        Uri.parse(list[index].url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      _player = next;
      await next.initialize();

      if (!mounted || ticket != _request) {
        if (identical(_player, next)) _player = null;
        await next.dispose();
        return;
      }

      await next.setLooping(true);
      await next.setVolume(1);
      await next.play();

      if (mounted && ticket == _request) setState(() {});
    } catch (_) {
      if (ticket != _request) return;

      if (identical(_player, next)) _player = null;

      if (next != null) {
        try {
          await next.dispose();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _error = 'वीडियो नहीं चली। दोबारा कोशिश करें।';
        });
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _togglePlay() async {
    final p = _player;
    if (p == null || !p.value.isInitialized) return;

    try {
      if (p.value.isPlaying) {
        await p.pause();
      } else {
        await p.play();
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _like(ArchiveVideo video) {
    setState(() {
      if (!_liked.add(video.id)) _liked.remove(video.id);
    });
  }

  void _save(ArchiveVideo video) {
    setState(() {
      if (!_saved.add(video.id)) _saved.remove(video.id);
    });
    _message(_saved.contains(video.id)
        ? 'Saved'
        : 'Saved items से हटाया गया');
  }

  void _follow(ArchiveVideo video) {
    setState(() {
      if (!_following.add(video.uploader)) {
        _following.remove(video.uploader);
      }
    });
  }

  void _showComments(ArchiveVideo video) {
    final input = TextEditingController();
    final comments = _comments.putIfAbsent(video.id, () => []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF191919),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Comments',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (comments.isEmpty)
              const Text('अभी कोई कमेंट नहीं है।'),
            ...comments.map(
              (comment) => ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(comment),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    decoration: const InputDecoration(
                      hintText: 'कमेंट लिखें...',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final text = input.text.trim();
                    if (text.isEmpty) return;
                    setState(() => comments.add(text));
                    input.clear();
                    Navigator.pop(context);
                    _showComments(video);
                  },
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _more(ArchiveVideo video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF191919),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('Save video'),
              onTap: () {
                Navigator.pop(context);
                _save(video);
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Playback speed'),
              onTap: () async {
                Navigator.pop(context);
                final p = _player;
                if (p == null || !p.value.isInitialized) return;
                final speed = p.value.playbackSpeed >= 1.5 ? 1.0 : 1.5;
                await p.setPlaybackSpeed(speed);
                _message('Playback speed: ${speed}x');
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off),
              title: const Text('Not interested'),
              onTap: () {
                Navigator.pop(context);
                if (_visibleVideos.length > 1) {
                  final next = (_index + 1) % _visibleVideos.length;
                  _pages.animateToPage(
                    next,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report video'),
              onTap: () {
                Navigator.pop(context);
                _message('Report भेजने के लिए सर्वर सेटअप बाकी है।');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => _bottomIndex = index);

    switch (index) {
      case 0:
        break;
      case 1:
        _message('वीडियो अपलोड के लिए सर्वर सेटअप बाकी है।');
        break;
      case 2:
        _message('Messages के लिए सर्वर सेटअप बाकी है।');
        break;
      case 3:
        _message(
          'Profile: ${_following.length} Following • ${_saved.length} Saved',
        );
        break;
    }
  }

  @override
  void dispose() {
    _request++;
    _pages.dispose();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videos = _visibleVideos;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        titleSpacing: 16,
        title: const Text(
          '♛ MS SHORTS VIP',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () {
              final input = TextEditingController();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Search videos'),
                  content: TextField(
                    controller: input,
                    decoration: const InputDecoration(
                      hintText: 'वीडियो का नाम खोजें',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        final q = input.text.toLowerCase();
                        Navigator.pop(context);
                        final found = _videos.indexWhere(
                          (v) => v.title.toLowerCase().contains(q),
                        );
                        if (found >= 0) {
                          _message('वीडियो मिली: ${_videos[found].title}');
                        } else {
                          _message('कोई वीडियो नहीं मिली।');
                        }
                      },
                      child: const Text('Search'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _message('Notifications के लिए सर्वर सेटअप बाकी है।'),
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadVideos,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : videos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.video_library_outlined, size: 52),
                      const SizedBox(height: 12),
                      Text(_error ?? 'कोई वीडियो उपलब्ध नहीं है।'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadVideos,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() => _showFollowing = false);
                            _play(0);
                          },
                          child: Text(
                            'For You',
                            style: TextStyle(
                              color: !_showFollowing
                                  ? Colors.redAccent
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _showFollowing = true);
                            _play(0);
                          },
                          child: Text(
                            'Following',
                            style: TextStyle(
                              color: _showFollowing
                                  ? Colors.redAccent
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pages,
                        scrollDirection: Axis.vertical,
                        itemCount: videos.length,
                        onPageChanged: _play,
                        itemBuilder: (context, index) {
                          final video = videos[index];
                          final active = index == _index;
                          final p = active ? _player : null;

                          return GestureDetector(
                            onTap: _togglePlay,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                const ColoredBox(color: Colors.black),
                                if (p != null && p.value.isInitialized)
                                  Center(
                                    child: AspectRatio(
                                      aspectRatio: p.value.aspectRatio > 0
                                          ? p.value.aspectRatio
                                          : 9 / 16,
                                      child: VideoPlayer(p),
                                    ),
                                  ),
                                if (active &&
                                    (p == null || !p.value.isInitialized))
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                if (active && _error != null)
                                  Center(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _play(index),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('फिर से चलाएँ'),
                                    ),
                                  ),
                                Positioned(
                                  left: 14,
                                  right: 82,
                                  bottom: 20,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text('@${video.uploader}'),
                                          ),
                                          TextButton(
                                            onPressed: () => _follow(video),
                                            child: Text(
                                              _following.contains(video.uploader)
                                                  ? 'Following'
                                                  : 'Follow',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Text(
                                        '♫ Original audio',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  bottom: 100,
                                  child: Column(
                                    children: [
                                      const CircleAvatar(
                                        child: Icon(Icons.person),
                                      ),
                                      const SizedBox(height: 14),
                                      IconButton(
                                        onPressed: () => _like(video),
                                        icon: Icon(
                                          _liked.contains(video.id)
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: _liked.contains(video.id)
                                              ? Colors.red
                                              : Colors.white,
                                          size: 30,
                                        ),
                                      ),
                                      const Text('Like'),
                                      const SizedBox(height: 8),
                                      IconButton(
                                        onPressed: () => _showComments(video),
                                        icon: const Icon(
                                          Icons.comment_outlined,
                                          size: 28,
                                        ),
                                      ),
                                      const Text('Comment'),
                                      const SizedBox(height: 8),
                                      IconButton(
                                        onPressed: () => _save(video),
                                        icon: Icon(
                                          _saved.contains(video.id)
                                              ? Icons.bookmark
                                              : Icons.bookmark_border,
                                          size: 28,
                                        ),
                                      ),
                                      const Text('Save'),
                                      const SizedBox(height: 8),
                                      IconButton(
                                        onPressed: () => _message(
                                          'Share के लिए share_plus integration बाकी है।',
                                        ),
                                        icon: const Icon(
                                          Icons.share_outlined,
                                          size: 28,
                                        ),
                                      ),
                                      const Text('Share'),
                                      IconButton(
                                        onPressed: () => _more(video),
                                        icon: const Icon(Icons.more_vert),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.white70,
        currentIndex: _bottomIndex,
        onTap: _selectTab,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle, size: 32),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            label: 'Message',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
