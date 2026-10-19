
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import 'archive_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MSShortsApp());
}

const Color msPink = Color(0xFFFF2D79);
const Color msBlue = Color(0xFF247BFF);

class MSShortsApp extends StatelessWidget {
  const MSShortsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MS SHORTS VIP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: msPink,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class FeedVideo {
  final String title;
  final String creator;
  final String url;
  final bool local;

  const FeedVideo({
    required this.title,
    required this.creator,
    required this.url,
    this.local = false,
  });

  factory FeedVideo.fromArchive(ArchiveVideo video) => FeedVideo(
        title: video.title,
        creator: '@${video.creator}',
        url: video.url,
      );
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final PageController _pageController = PageController();
  final ImagePicker _picker = ImagePicker();

  List<FeedVideo> _videos = [];
  final Set<String> _liked = {};
  final Set<String> _saved = {};
  final Map<String, List<String>> _comments = {};

  int _tab = 0;
  bool _loading = true;
  String? _error;
  int _feedVersion = 0;

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
      final archive = await ArchiveService.fetchVideos();
      if (!mounted) return;

      setState(() {
        final localVideos = _videos.where((v) => v.local).toList();
        _videos = [
          ...localVideos,
          ...archive.map(FeedVideo.fromArchive),
        ];
        _loading = false;
        _feedVersion++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Internet Archive se videos load nahi hui.';
      });
    }
  }

  Future<void> _pickVideo() async {
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 1),
      );

      if (file == null || !mounted) return;

      final video = FeedVideo(
        title: 'My new video',
        creator: '@Mehndi_Babu',
        url: file.path,
        local: true,
      );

      setState(() {
        _videos.insert(0, video);
        _tab = 0;
        _feedVersion++;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Video is phone par add hui hai. Online upload abhi connected nahi hai.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video select nahi ho payi.')),
      );
    }
  }

  void _showComments(FeedVideo video) {
    final controller = TextEditingController();
    final key = video.url;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171717),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, refreshSheet) {
            final comments = _comments[key] ?? [];

            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SizedBox(
                height: 330,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: comments.isEmpty
                          ? const Center(child: Text('Abhi koi comment nahi'))
                          : ListView(
                              children: comments
                                  .map((c) => ListTile(
                                        leading: const CircleAvatar(
                                          child: Icon(Icons.person),
                                        ),
                                        title: Text(c),
                                      ))
                                  .toList(),
                            ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: 'Comment likhein...',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: msPink),
                          onPressed: () {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;

                            setState(() {
                              _comments.putIfAbsent(key, () => []).add(text);
                            });
                            controller.clear();
                            refreshSheet(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  void _showProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          videos: _videos,
          savedCount: _saved.length,
          likedCount: _liked.length,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: _tab == 2
                  ? const MessagesScreen()
                  : _tab == 3
                      ? _profilePreview()
                      : _buildFeed(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _header() {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Text(
            'MS',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: msPink,
            ),
          ),
          const Text(
            ' SHORTS VIP',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _tab = 0),
            child: const Text('Reels'),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: () {
              showSearch(
                context: context,
                delegate: VideoSearchDelegate(_videos),
              );
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications ke liye backend chahiye.'),
                ),
              );
            },
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    if (_loading && _videos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_videos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.video_library_outlined, size: 58),
              const SizedBox(height: 16),
              Text(_error ?? 'Abhi koi video nahi mili.'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadVideos,
                icon: const Icon(Icons.refresh),
                label: const Text('Dobara load karein'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          key: ValueKey(_feedVersion),
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: _videos.length,
          itemBuilder: (context, index) {
            final video = _videos[index];
            return ReelPage(
              video: video,
              liked: _liked.contains(video.url),
              saved: _saved.contains(video.url),
              commentsCount: _comments[video.url]?.length ?? 0,
              onLike: () {
                setState(() {
                  if (!_liked.add(video.url)) _liked.remove(video.url);
                });
              },
              onSave: () {
                setState(() {
                  if (!_saved.add(video.url)) _saved.remove(video.url);
                });
              },
              onComment: () => _showComments(video),
              onShare: () {
                Share.share('${video.title}\n${video.url}');
              },
            );
          },
        ),
        if (_loading)
          const Positioned(
            top: 8,
            right: 12,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _profilePreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 42,
            backgroundColor: msPink,
            child: Icon(Icons.person, size: 46),
          ),
          const SizedBox(height: 12),
          const Text(
            '@Mehndi_Babu',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text('${_videos.length} videos'),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _showProfile,
            child: const Text('Open Profile'),
          ),
          TextButton(
            onPressed: _loadVideos,
            child: const Text('Refresh videos'),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      height: 66,
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_filled, 'Home', 0),
          IconButton(
            tooltip: 'Upload video',
            onPressed: _pickVideo,
            icon: Container(
              width: 48,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: const LinearGradient(
                  colors: [msBlue, msPink],
                ),
              ),
              child: const Icon(Icons.add, size: 28),
            ),
          ),
          _navItem(Icons.chat_bubble_outline, 'Message', 2),
          _navItem(Icons.person_outline, 'Profile', 3),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = _tab == index;
    return InkWell(
      onTap: () {
        if (index == 3) {
          setState(() => _tab = 3);
          return;
        }
        setState(() => _tab = index);
      },
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? msPink : Colors.white70),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? msPink : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReelPage extends StatefulWidget {
  final FeedVideo video;
  final bool liked;
  final bool saved;
  final int commentsCount;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const ReelPage({
    super.key,
    required this.video,
    required this.liked,
    required this.saved,
    required this.commentsCount,
    required this.onLike,
    required this.onSave,
    required this.onComment,
    required this.onShare,
  });

  @override
  State<ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<ReelPage> {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _muted = false;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    VideoPlayerController? controller;

    try {
      controller = widget.video.local
          ? VideoPlayerController.file(File(widget.video.url))
          : VideoPlayerController.networkUrl(Uri.parse(widget.video.url));

      await controller.initialize().timeout(const Duration(seconds: 30));
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _busy = false;
      });
    } catch (_) {
      await controller?.dispose();
      if (!mounted) return;
      setState(() {
        _failed = true;
        _busy = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.url != widget.video.url) {
      _controller?.dispose();
      _controller = null;
      _failed = false;
      _busy = true;
      _initialize();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF101010)),
        if (controller != null && controller.value.isInitialized)
          GestureDetector(
            onTap: () {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
              setState(() {});
            },
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio > 0
                    ? controller.value.aspectRatio
                    : 9 / 16,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        if (_busy)
          const Center(child: CircularProgressIndicator()),
        if (_failed)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 44),
                const SizedBox(height: 8),
                const Text('Video play nahi hui'),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _failed = false;
                      _busy = true;
                    });
                    _initialize();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        Positioned(
          left: 14,
          right: 90,
          bottom: 25,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.video.creator,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              Text(widget.video.title, maxLines: 2),
              const SizedBox(height: 7),
              const Row(
                children: [
                  Icon(Icons.music_note, size: 17),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Original audio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          right: 8,
          bottom: 25,
          child: Column(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(height: 20),
              _action(
                widget.liked ? Icons.favorite : Icons.favorite_border,
                widget.liked ? msPink : Colors.white,
                'Like',
                widget.onLike,
              ),
              _action(
                Icons.comment,
                Colors.white,
                '${widget.commentsCount}',
                widget.onComment,
              ),
              _action(
                Icons.repeat,
                Colors.white,
                'Repost',
                () => _message('Repost feature ke liye shared backend chahiye.'),
              ),
              _action(
                Icons.bookmark,
                widget.saved ? msPink : Colors.white,
                'Save',
                widget.onSave,
              ),
              _action(
                Icons.share,
                Colors.white,
                'Share',
                widget.onShare,
              ),
              _action(
                _muted ? Icons.volume_off : Icons.volume_up,
                Colors.white,
                'Sound',
                () async {
                  _muted = !_muted;
                  await _controller?.setVolume(_muted ? 0 : 1);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _action(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              Icon(icon, size: 29, color: color),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final List<FeedVideo> videos;
  final int savedCount;
  final int likedCount;

  const ProfileScreen({
    super.key,
    required this.videos,
    required this.savedCount,
    required this.likedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 45,
              backgroundColor: msPink,
              child: Icon(Icons.person, size: 48),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              '@Mehndi_Babu',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat('Videos', videos.length),
              _stat('Liked', likedCount),
              _stat('Saved', savedCount),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'My videos',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          ...videos.map(
            (v) => ListTile(
              leading: const Icon(Icons.video_library),
              title: Text(v.title, maxLines: 1),
              subtitle: Text(v.local ? 'Phone video' : 'Internet Archive'),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Creator wallet and gifts need a secure server and payment integration.',
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        Text(label),
      ],
    );
  }
}

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 55),
            SizedBox(height: 15),
            Text(
              'Messages',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Real user-to-user messaging ke liye login aur backend connect karna hoga.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class VideoSearchDelegate extends SearchDelegate<void> {
  final List<FeedVideo> videos;

  VideoSearchDelegate(this.videos);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear),
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back),
      );

  @override
  Widget buildResults(BuildContext context) => _results();

  @override
  Widget buildSuggestions(BuildContext context) => _results();

  Widget _results() {
    final matches = videos
        .where(
          (v) =>
              v.title.toLowerCase().contains(query.toLowerCase()) ||
              v.creator.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    if (matches.isEmpty) {
      return const Center(child: Text('Koi video nahi mili.'));
    }

    return ListView(
      children: matches
          .map(
            (v) => ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: Text(v.title),
              subtitle: Text(v.creator),
            ),
          )
          .toList(),
    );
  }
}
