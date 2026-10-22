import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
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
          primary: Colors.pinkAccent,
          secondary: Colors.pinkAccent,
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

class _VideoFeedPageState extends State<VideoFeedPage> with WidgetsBindingObserver {
  final ArchiveService _service = ArchiveService();
  final PageController _pageController = PageController();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();

  List<ArchiveVideo> _videos = [];
  final Set<String> _liked = {};
  final Set<String> _saved = {};
  final Set<String> _followed = {};
  final Set<String> _hidden = {};
  final Map<String, List<String>> _comments = {};
  final Map<String, int> _likeCounts = {};
  final Map<String, int> _viewCounts = {};

  VideoPlayerController? _controller;
  VideoPlayerController? _preloadController;

  bool _loading = true;
  bool _busy = false;
  bool _showFollowing = false;
  bool _muted = false;
  bool _searching = false;
  bool _isUploading = false;
  String? _error;
  int _currentIndex = 0;
  int _bottomIndex = 0;
  double _playbackSpeed = 1.0;

  List<ArchiveVideo> get _visibleVideos {
    var list = _videos.where((v) => !_hidden.contains(v.id)).toList();

    if (_searchController.text.trim().isNotEmpty) {
      final query = _searchController.text.trim().toLowerCase();
      list = list.where((v) {
        return v.title.toLowerCase().contains(query) ||
            v.uploader.toLowerCase().contains(query);
      }).toList();
    }

    if (_showFollowing) {
      list = list.where((v) => _followed.contains(v.uploader)).toList();
    }

    return list;
  }

  ArchiveVideo? get _currentVideo {
    final list = _visibleVideos;
    if (_currentIndex < 0 || _currentIndex >= list.length) return null;
    return list[_currentIndex];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVideos();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _controller?.pause();
      _preloadController?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller?.play();
    }
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
        _currentIndex = 0;
      });

      if (videos.isEmpty) {
        setState(() {
          _error = 'अभी कोई वीडियो नहीं मिली। रिफ्रेश करें।';
        });
        return;
      }

      for (var v in videos) {
        _likeCounts[v.id] = v.likes;
        _viewCounts[v.id] = v.views;
      }

      await _playVideo(0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'सर्वर से वीडियो लोड नहीं हुई। इंटरनेट जाँचें।';
      });
    }
  }

  Future<void> _playVideo(int index) async {
    final list = _visibleVideos;
    if (_busy || index < 0 || index >= list.length) return;

    _busy = true;
    final old = _controller;
    final oldPreload = _preloadController;

    _controller = null;
    _preloadController = null;

    try {
      if (old != null) {
        await old.pause();
        await old.dispose();
      }
      if (oldPreload != null) {
        await oldPreload.pause();
        await oldPreload.dispose();
      }

      if (!mounted) return;

      final next = VideoPlayerController.networkUrl(
        Uri.parse(list[index].url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      _controller = next;
      await next.initialize();

      if (!mounted || _controller != next) {
        await next.dispose();
        return;
      }

      await next.setLooping(true);
      await next.setVolume(_muted ? 0 : 1);
      await next.setPlaybackSpeed(_playbackSpeed);
      await next.play();

      if (!mounted) return;

      setState(() {
        _currentIndex = index;
        _loading = false;
        _error = null;
        _viewCounts[list[index].id] = (_viewCounts[list[index].id] ?? 0) + 1;
      });

      _prepareNextVideo(index + 1);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'यह वीडियो लोड नहीं हुई। अगली वीडियो देखें।';
        });
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _prepareNextVideo(int index) async {
    final list = _visibleVideos;
    if (index < 0 || index >= list.length || !mounted) return;

    try {
      final next = VideoPlayerController.networkUrl(
        Uri.parse(list[index].url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return;
      }

      await next.setLooping(true);
      await next.setVolume(0);
      await next.pause();

      final previous = _preloadController;
      _preloadController = next;
      if (previous != null) {
        await previous.dispose();
      }
    } catch (_) {}
  }

  Future<void> _retryVideo() async {
    if (_videos.isEmpty) {
      await _loadVideos();
      return;
    }
    await _playVideo(_currentIndex);
  }

  void _toggleLike(ArchiveVideo video) {
    setState(() {
      if (_liked.contains(video.id)) {
        _liked.remove(video.id);
        _likeCounts[video.id] = ((_likeCounts[video.id] ?? 0) - 1).clamp(0, 1 << 30);
      } else {
        _liked.add(video.id);
        _likeCounts[video.id] = (_likeCounts[video.id] ?? 0) + 1;
      }
    });
  }

  void _toggleFollow(ArchiveVideo video) {
    setState(() {
      if (_followed.contains(video.uploader)) {
        _followed.remove(video.uploader);
      } else {
        _followed.add(video.uploader);
      }
    });
    _toast(_followed.contains(video.uploader)
        ? 'अब आप @${video.uploader} को फॉलो कर रहे हैं'
        : 'फॉलो हटाया गया');
  }

  void _toggleSave(ArchiveVideo video) {
    setState(() {
      if (_saved.contains(video.id)) {
        _saved.remove(video.id);
      } else {
        _saved.add(video.id);
      }
    });
    _toast(_saved.contains(video.id) ? 'वीडियो सेव हुई' : 'सेव हटाई गई');
  }

  Future<void> _showComments(ArchiveVideo video) async {
    final input = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, refreshSheet) {
            final comments = _comments[video.id] ?? [];
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: Column(
                  children: [
                    Text(
                      'Comments (${comments.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const Divider(),
                    Expanded(
                      child: comments.isEmpty
                          ? const Center(child: Text('अभी कोई कमेंट नहीं है। पहला कमेंट करें!'))
                          : ListView.builder(
                              itemCount: comments.length,
                              itemBuilder: (_, i) => ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person)),
                                title: Text(comments[i]),
                              ),
                            ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: input,
                            decoration: const InputDecoration(
                              hintText: 'कमेंट लिखें...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final value = input.text.trim();
                            if (value.isEmpty) return;
                            setState(() {
                              _comments.putIfAbsent(video.id, () => []);
                              _comments[video.id]!.add(value);
                            });
                            input.clear();
                            refreshSheet(() {});
                          },
                          icon: const Icon(Icons.send, color: Colors.pinkAccent),
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
    );
    input.dispose();
  }

  Future<void> _shareVideo(ArchiveVideo video) async {
    try {
      await Share.share('${video.title}\n${video.url}\n\nMS SHORTS VIP');
    } catch (_) {
      _toast('शेयर नहीं हो सका।');
    }
  }

  /// 3. वीडियो चुनने और सीधे सर्वर पर अपलोड करने का 100% वर्किंग फंक्शन
  Future<void> _pickAndUploadVideo() async {
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60), // 60 सेकंड की लिमिट
      );

      if (file == null || !mounted) return;

      final captionController = TextEditingController(text: '#MSShortsVIP #MehndiBabu');

      final shouldUpload = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('वीडियो पब्लिश करें', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('चुनी गई फाइल: ${file.name}', style: const TextStyle(fontSize: 12, color: Colors.pinkAccent)),
              const SizedBox(height: 12),
              TextField(
                controller: captionController,
                decoration: const InputDecoration(
                  labelText: 'कैप्शन / हैशटैग',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('रद्द करें', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('अपलोड करें 🚀', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (shouldUpload != true) return;

      setState(() => _isUploading = true);
      _toast('वीडियो अपलोड हो रही है... कृपया प्रतीक्षा करें');

      final Uint8List bytes = await file.readAsBytes();
      final success = await _service.uploadVideoFile(
        fileBytes: bytes,
        fileName: file.name,
        caption: captionController.text.trim(),
        username: 'Mehndi_Babu',
      );

      setState(() => _isUploading = false);

      if (success) {
        _toast('✅ वीडियो सफलतापूर्वक अपलोड हो गई और लाइव है!');
        await _loadVideos(); // नया वीडियो फ़ीड में तुरंत दिखाने के लिए
      } else {
        _toast('❌ अपलोड में समस्या आई। पुनः प्रयास करें।');
      }
    } catch (e) {
      setState(() => _isUploading = false);
      _toast('वीडियो चुनने में समस्या हुई।');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, size: 31, color: color),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo(ArchiveVideo video, int index) {
    final active = index == _currentIndex;
    final player = active ? _controller : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (player != null && player.value.isInitialized)
          GestureDetector(
            onTap: () {
              setState(() {
                player.value.isPlaying ? player.pause() : player.play();
              });
            },
            child: Center(
              child: AspectRatio(
                aspectRatio: player.value.aspectRatio > 0 ? player.value.aspectRatio : 9 / 16,
                child: VideoPlayer(player),
              ),
            ),
          )
        else if (active)
          Center(
            child: _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _retryVideo,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(color: Colors.pinkAccent),
          ),
        
        // Pause Icon Overlay
        if (active && player != null && player.value.isInitialized && !player.value.isPlaying)
          const Center(
            child: Icon(Icons.play_arrow_rounded, size: 76, color: Colors.white70),
          ),

        // Top Header
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium, color: Colors.amber, size: 27),
                  const SizedBox(width: 6),
                  const Text('MS SHORTS VIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const Spacer(),
                  IconButton(
                    onPressed: _loadVideos,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
          ),
        ),

        // Tabs (For You / Following)
        Positioned(
          top: 95,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _feedTab('✨ आपके लिए', false),
              const SizedBox(width: 22),
              _feedTab('👥 Following', true),
            ],
          ),
        ),

        // Right Action Bar
        Positioned(
          right: 10,
          bottom: 112,
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _toggleFollow(video),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 23,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    Icon(
                      _followed.contains(video.uploader) ? Icons.check_circle : Icons.add_circle,
                      color: Colors.pinkAccent,
                      size: 22,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              _actionButton(
                icon: _liked.contains(video.id) ? Icons.favorite : Icons.favorite_border,
                label: '${_likeCounts[video.id] ?? 0}',
                color: _liked.contains(video.id) ? Colors.pinkAccent : Colors.white,
                onTap: () => _toggleLike(video),
              ),
              _actionButton(
                icon: Icons.comment,
                label: '${(_comments[video.id] ?? []).length}',
                onTap: () => _showComments(video),
              ),
              _actionButton(
                icon: _saved.contains(video.id) ? Icons.bookmark : Icons.bookmark_border,
                label: 'Save',
                color: _saved.contains(video.id) ? Colors.amber : Colors.white,
                onTap: () => _toggleSave(video),
              ),
              _actionButton(
                icon: Icons.share,
                label: 'Share',
                onTap: () => _shareVideo(video),
              ),
              _actionButton(
                icon: _muted ? Icons.volume_off : Icons.volume_up,
                label: _muted ? 'Muted' : 'Sound',
                onTap: () {
                  setState(() => _muted = !_muted);
                  _controller?.setVolume(_muted ? 0 : 1);
                },
              ),
            ],
          ),
        ),

        // Bottom Video Info
        Positioned(
          left: 15,
          right: 78,
          bottom: 92,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@${video.uploader}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 7),
              Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(Icons.music_note, size: 16),
                  const SizedBox(width: 4),
                  const Text('Original Audio - MS Shorts VIP', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 12),
                  const Icon(Icons.remove_red_eye_outlined, size: 16, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text('${_viewCounts[video.id] ?? 0}', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _feedTab(String title, bool following) {
    final selected = _showFollowing == following;
    return GestureDetector(
      onTap: () {
        setState(() {
          _showFollowing = following;
          _currentIndex = 0;
          _error = null;
        });
        if (_visibleVideos.isNotEmpty) {
          _playVideo(0);
        } else {
          _controller?.pause();
        }
      },
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Colors.white : Colors.white60,
            ),
          ),
          const SizedBox(height: 5),
          if (selected)
            Container(width: 28, height: 3, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 62,
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _bottomButton(Icons.home_filled, 'Home', 0),
            IconButton(
              tooltip: 'Upload video',
              onPressed: _isUploading ? null : _pickAndUploadVideo,
              icon: _isUploading
                  ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.pinkAccent))
                  : const Icon(Icons.add_box_rounded, color: Colors.pinkAccent, size: 34),
            ),
            _bottomButton(Icons.person_outline, 'Profile', 3),
          ],
        ),
      ),
    );
  }

  Widget _bottomButton(IconData icon, String label, int index) {
    return InkWell(
      onTap: () {
        setState(() => _bottomIndex = index);
        if (index == 0) {
          _controller?.play();
        } else if (index == 3) {
          _controller?.pause();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfilePage(
                savedCount: _saved.length,
                followingCount: _followed.length,
                likedCount: _liked.length,
              ),
            ),
          );
        }
      },
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _bottomIndex == index ? Colors.pinkAccent : Colors.white70, size: 25),
            Text(label, style: TextStyle(fontSize: 10, color: _bottomIndex == index ? Colors.pinkAccent : Colors.white70)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = _visibleVideos;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading && _videos.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : videos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.video_library_outlined, size: 58, color: Colors.white54),
                        const SizedBox(height: 16),
                        Text(_error ?? 'अभी कोई वीडियो नहीं मिली।', textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          onPressed: _loadVideos,
                          child: const Text('Refresh / Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: videos.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                          _error = null;
                        });
                        _playVideo(index);
                      },
                      itemBuilder: (context, index) {
                        return _buildVideo(videos[index], index);
                      },
                    ),
                    Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomBar()),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _searchController.dispose();
    _controller?.dispose();
    _preloadController?.dispose();
    _service.close();
    super.dispose();
  }
}

class ProfilePage extends StatelessWidget {
  final int savedCount;
  final int followingCount;
  final int likedCount;

  const ProfilePage({
    super.key,
    required this.savedCount,
    required this.followingCount,
    required this.likedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 42,
            child: Icon(Icons.person, size: 45),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              '@Mehndi_Babu',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite_outline, color: Colors.pinkAccent),
              title: const Text('Liked videos'),
              trailing: Text('$likedCount'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bookmark_outline, color: Colors.amber),
              title: const Text('Saved videos'),
              trailing: Text('$savedCount'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Following'),
              trailing: Text('$followingCount'),
            ),
          ),
        ],
      ),
    );
  }
}
