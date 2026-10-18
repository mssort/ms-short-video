
import 'package:flutter/material.dart';

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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  final List<String> titles = [
    'MS SHORTS VIP',
    'वीडियो अपलोड',
    'आपकी प्रोफ़ाइल',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ),
        backgroundColor: Colors.black,
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: const [
          HomeFeed(),
          UploadScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        backgroundColor: Colors.black,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'होम',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box),
            label: 'अपलोड',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'प्रोफ़ाइल',
          ),
        ],
      ),
    );
  }
}

class HomeFeed extends StatelessWidget {
  const HomeFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return PageView(
      scrollDirection: Axis.vertical,
      children: const [
        VideoPlaceholder(
          title: 'MS SHORTS VIP',
          subtitle: 'आपकी शॉर्ट वीडियो दुनिया',
        ),
        VideoPlaceholder(
          title: 'दूसरी वीडियो',
          subtitle: 'यह अभी डेमो स्क्रीन है',
        ),
      ],
    );
  }
}

class VideoPlaceholder extends StatelessWidget {
  final String title;
  final String subtitle;

  const VideoPlaceholder({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.play_circle_fill,
            color: Colors.redAccent,
            size: 90,
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 32),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(Icons.favorite_border, size: 30),
              Icon(Icons.comment_outlined, size: 30),
              Icon(Icons.share_outlined, size: 30),
            ],
          ),
        ],
      ),
    );
  }
}

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_call,
              size: 80,
              color: Colors.redAccent,
            ),
            SizedBox(height: 20),
            Text(
              'वीडियो अपलोड',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'अपलोड सुविधा अभी जोड़नी बाकी है।',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 45,
            child: Icon(Icons.person, size: 50),
          ),
          SizedBox(height: 20),
          Text(
            'MS SHORTS VIP',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text('आपकी प्रोफ़ाइल'),
        ],
      ),
    );
  }
}
