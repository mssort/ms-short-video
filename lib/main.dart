

import 'package:flutter/material.dart';

void main() {
  runApp(const MSShortsApp());
}

class MSShortsApp extends StatelessWidget {
  const MSShortsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MS SHORTS VIP',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'MS SHORTS VIP',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          Icon(Icons.search),
          SizedBox(width: 16),
        ],
      ),
      body: PageView(
        scrollDirection: Axis.vertical,
        children: const [
          VideoPlaceholder(
            title: 'MS SHORTS VIP',
            subtitle: 'आपकी शॉर्ट वीडियो दुनिया',
          ),
          VideoPlaceholder(
            title: 'अगली वीडियो',
            subtitle: 'वीडियो प्लेयर बाद में जोड़ा जाएगा',
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.white70,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.play_circle_outline,
            color: Colors.redAccent,
            size: 90,
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border),
              SizedBox(width: 24),
              Icon(Icons.comment_outlined),
              SizedBox(width: 24),
              Icon(Icons.share_outlined),
            ],
          ),
        ],
      ),
    );
  }
}
