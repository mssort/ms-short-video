
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MSShortsApp());
}

class MSShortsApp extends StatelessWidget {
  const MSShortsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MS SHORTS VIP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.pinkAccent,
          secondary: Colors.purpleAccent,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class LocalVideo {
  final String path;
  final String caption;

  LocalVideo(this.path, {this.caption = 'मेरी नई वीडियो'});
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int tab = 0;
  String? avatarPath;
  String username = 'MS SHORTS VIP';

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      avatarPath = prefs.getString('avatarPath');
      username = prefs.getString('username') ?? 'MS SHORTS VIP';
    });
  }

  Future<void> pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final saved = await File(picked.path).copy('${dir.path}/$fileName');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatarPath', saved.path);

    if (!mounted) return;
    setState(() => avatarPath = saved.path);
  }

  ImageProvider? get avatarImage {
    if (avatarPath != null && File(avatarPath!).existsSync()) {
      return FileImage(File(avatarPath!));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: [
          VideoFeed(
            avatarPath: avatarPath,
            onUpload: () => setState(() => tab = 1),
          ),
          UploadPage(
            onVideoAdded: () => setState(() => tab = 0),
          ),
          const MessagesPage(),
          ProfilePage(
            username: username,
            avatarImage: avatarImage,
            onPickAvatar: pickAvatar,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                navButton(Icons.home_filled, 'होम', 0),
                GestureDetector(
                  onTap: () => setState(() => tab = 1),
                  child: Container(
                    width: 48,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: const LinearGradient(
                        colors: [Colors.pinkAccent, Colors.purpleAccent],
                      ),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 30),
                  ),
                ),
                navButton(Icons.chat_bubble_outline, 'मैसेज', 2),
                navButton(Icons.person_outline, 'प्रोफ़ाइल', 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget navButton(IconData icon, String label, int index) {
    return InkWell(
      onTap: () => setState(() => tab = index),
      child: SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: tab == index ? Colors.pinkAccent : Colors.white70),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: tab == index ? Colors.pinkAccent : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoFeed extends StatefulWidget {
  final String? avatarPath;
  final VoidCallback onUpload;

  const VideoFeed({
    super.key,
    required this.avatarPath,
    required this.onUpload,
  });

  @override
  State<VideoFeed> createState() => _VideoFeedState();
}

class _VideoFeedState extends State<VideoFeed> {
  final ImagePicker picker = ImagePicker();
  final List<LocalVideo> videos = [];
  final Map<int, bool> liked = {};
  final Map<int, bool> saved = {};
  final Map<int, bool> reposted = {};

  VideoPlayerController? controller;
  int currentPage = 0;
  bool initializing = false;

  @override
  void initState() {
    super.initState();
    loadVideos();
  }

  Future<void> loadVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList('localVideos') ?? [];
    final captions = prefs.getStringList('localCaptions') ?? [];

    if (!mounted) return;
    setState(() {
      for (int i = 0; i < paths.length; i++) {
        if (File(paths[i]).existsSync()) {
          videos.add(LocalVideo(
            paths[i],
            caption: i < captions.length ? captions[i] : 'मेरी नई वीडियो',
          ));
        }
      }
    });

    if (videos.isNotEmpty) {
      initializeVideo(0);
    }
  }

  Future<void> initializeVideo(int index) async {
    if (index < 0 || index >= videos.length || initializing) return;

    initializing = true;
    final old = controller;
    controller = null;
    if (old != null) {
      await old.dispose();
    }

    final next = VideoPlayerController.file(File(videos[index].path));
    controller = next;

    try {
      await next.initialize();
      await next.setLooping(true);
      await next.play();
    } catch (_) {
      // वीडियो फ़ाइल न चलने पर फ़ीड सुरक्षित रहेगी।
    }

    initializing = false;
    if (mounted) setState(() {});
  }

  Future<void> addVideo() async {
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final name = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final file = await File(picked.path).copy('${dir.path}/$name');

    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList('localVideos') ?? [];
    final captions = prefs.getStringList('localCaptions') ?? [];

    paths.add(file.path);
    captions.add('मेरी नई वीडियो');

    await prefs.setStringList('localVideos', paths);
    await prefs.setStringList('localCaptions', captions);

    if (!mounted) return;
    setState(() {
      videos.add(LocalVideo(file.path));
      currentPage = videos.length - 1;
    });
    await initializeVideo(currentPage);
  }

  void showComments() {
    final textController = TextEditingController();
    final comments = <String>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF191919),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SizedBox(
            height: 360,
            child: Column(
              children: [
                const Text(
                  'कमेंट',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                Expanded(
                  child: comments.isEmpty
                      ? const Center(child: Text('अभी कोई कमेंट नहीं है'))
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
                        controller: textController,
                        decoration: const InputDecoration(
                          hintText: 'कमेंट लिखें...',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        if (textController.text.trim().isEmpty) return;
                        setSheetState(() {
                          comments.add(textController.text.trim());
                          textController.clear();
                        });
                      },
                      icon: const Icon(Icons.send, color: Colors.pinkAccent),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: videos.isEmpty ? 1 : videos.length,
          onPageChanged: (index) {
            setState(() => currentPage = index);
            initializeVideo(index);
          },
          itemBuilder: (context, index) {
            if (videos.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_library_outlined,
                        size: 80, color: Colors.white54),
                    SizedBox(height: 16),
                    Text('MS SHORTS VIP',
                        style: TextStyle(
                            fontSize: 25, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('वीडियो जोड़ने के लिए नीचे + दबाएँ'),
                  ],
                ),
              );
            }

            final active = controller;
            if (index == currentPage &&
                active != null &&
                active.value.isInitialized) {
              return GestureDetector(
                onTap: () {
                  if (active.value.isPlaying) {
                    active.pause();
                  } else {
                    active.play();
                  }
                  setState(() {});
                },
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: active.value.size.width,
                      height: active.value.size.height,
                      child: VideoPlayer(active),
                    ),
                  ),
                ),
              );
            }

            return Container(
              color: const Color(0xFF111111),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.pinkAccent),
              ),
            );
          },
        ),
        Positioned(
          top: 42,
          left: 16,
          right: 16,
          child: Row(
            children: [
              const Text(
                'MS SHORTS VIP',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              const Text('Reels',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 18),
              const Text('Friends', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AlertDialog(
                      title: Text('वीडियो खोजें'),
                      content: Text(
                          'यह शुरुआती संस्करण है। ऑनलाइन वीडियो खोजने के लिए सर्वर कनेक्शन जोड़ना होगा।'),
                    ),
                  );
                },
                icon: const Icon(Icons.search),
              ),
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AlertDialog(
                      title: Text('नोटिफ़िकेशन'),
                      content: Text('अभी कोई नया नोटिफ़िकेशन नहीं है।'),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_none),
              ),
            ],
          ),
        ),
        if (videos.isNotEmpty)
          Positioned(
            right: 10,
            bottom: 85,
            child: Column(
              children: [
                actionButton(
                  icon: liked[currentPage] == true
                      ? Icons.favorite
                      : Icons.favorite_border,
                  label: 'लाइक',
                  color: liked[currentPage] == true
                      ? Colors.pinkAccent
                      : Colors.white,
                  onTap: () => setState(() {
                    liked[currentPage] = !(liked[currentPage] ?? false);
                  }),
                ),
                actionButton(
                  icon: Icons.mode_comment_outlined,
                  label: 'कमेंट',
                  onTap: showComments,
                ),
                actionButton(
                  icon: Icons.repeat,
                  label: 'रीपोस्ट',
                  color: reposted[currentPage] == true
                      ? Colors.pinkAccent
                      : Colors.white,
                  onTap: () => setState(() {
                    reposted[currentPage] =
                        !(reposted[currentPage] ?? false);
                  }),
                ),
                actionButton(
                  icon: Icons.send_outlined,
                  label: 'शेयर',
                  onTap: () => Share.share(
                    'MS SHORTS VIP पर मेरी वीडियो देखें!',
                  ),
                ),
                actionButton(
                  icon: saved[currentPage] == true
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  label: 'सेव',
                  color: saved[currentPage] == true
                      ? Colors.pinkAccent
                      : Colors.white,
                  onTap: () => setState(() {
                    saved[currentPage] = !(saved[currentPage] ?? false);
                  }),
                ),
              ],
            ),
          ),
        Positioned(
          left: 14,
          right: 90,
          bottom: 24,
          child: videos.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundImage: widget.avatarPath != null &&
                                  File(widget.avatarPath!).existsSync()
                              ? FileImage(File(widget.avatarPath!))
                              : null,
                          child: widget.avatarPath == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          '@MS_SHORTS_VIP',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'फॉलो सुविधा ऑनलाइन सर्वर से जोड़नी होगी।'),
                              ),
                            );
                          },
                          child: const Text('Follow'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(videos[currentPage].caption),
                    const SizedBox(height: 5),
                    const Text('♪ Original audio',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
        ),
        if (videos.isEmpty)
          Positioned(
            bottom: 95,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: addVideo,
                icon: const Icon(Icons.add),
                label: const Text('वीडियो चुनें'),
              ),
            ),
          ),
      ],
    );
  }

  Widget actionButton({
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
            Icon(icon, color: color, size: 31),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class UploadPage extends StatelessWidget {
  final VoidCallback onVideoAdded;

  const UploadPage({super.key, required this.onVideoAdded});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.video_call,
              size: 85, color: Colors.pinkAccent),
          const SizedBox(height: 18),
          const Text(
            'वीडियो अपलोड',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'गैलरी से वीडियो चुनकर अपने फ़ोन पर जोड़ें।',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onVideoAdded,
            icon: const Icon(Icons.video_library),
            label: const Text('होम पर जाएँ और + दबाएँ'),
          ),
        ],
      ),
    );
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 75, color: Colors.pinkAccent),
          SizedBox(height: 18),
          Text('मैसेज',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Text('असली मैसेजिंग के लिए ऑनलाइन बैकएंड जोड़ना होगा।'),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  final String username;
  final ImageProvider? avatarImage;
  final VoidCallback onPickAvatar;

  const ProfilePage({
    super.key,
    required this.username,
    required this.avatarImage,
    required this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onPickAvatar,
            child: CircleAvatar(
              radius: 52,
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? const Icon(Icons.add_a_photo, size: 35)
                  : null,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            username,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text('फ़ोटो बदलने के लिए ऊपर प्रोफ़ाइल पर दबाएँ।'),
        ],
      ),
    );
  }
}
