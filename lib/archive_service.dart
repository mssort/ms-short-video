import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ArchiveVideo {
  final String id;
  final String title;
  final String url;
  final String uploader;
  final int likes;
  final int views;

  ArchiveVideo({
    required this.id,
    required this.title,
    required this.url,
    required this.uploader,
    this.likes = 0,
    this.views = 0,
  });

  factory ArchiveVideo.fromJson(Map<String, dynamic> json) {
    // 1. Direct Playable Stream URL resolution
    final archiveUrl = json['archiveDownloadUrl'] as String?;
    final videoUrl = json['videoUrl'] as String? ?? '';
    
    String finalUrl = '';
    if (archiveUrl != null && archiveUrl.startsWith('http')) {
      finalUrl = archiveUrl;
    } else if (videoUrl.startsWith('http')) {
      finalUrl = videoUrl;
    } else {
      finalUrl = 'https://ms-sort-video-studio.ai.studio$videoUrl';
    }

    // 2. Clean uploader username
    String rawUser = json['username'] as String? ?? 'Mehndi_Babu';
    if (rawUser.startsWith('@')) {
      rawUser = rawUser.substring(1);
    }

    return ArchiveVideo(
      id: json['id'] as String? ?? 'vid_${DateTime.now().millisecondsSinceEpoch}',
      title: json['caption'] as String? ?? json['description'] as String? ?? 'MS Shorts VIP Video',
      url: finalUrl,
      uploader: rawUser,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      views: (json['views'] as num?)?.toInt() ?? 0,
    );
  }
}

class ArchiveService {
  final http.Client _client = http.Client();
  static const String baseUrl = 'https://ms-sort-video-studio.ai.studio';

  /// 1. लाइव सर्वर से सभी 20+ ओरिजिनल वीडियो लाना
  Future<List<ArchiveVideo>> fetchVideos({int maxPages = 1}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/reels');
      final response = await _client.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list
            .map((item) => ArchiveVideo.fromJson(item as Map<String, dynamic>))
            .where((v) => v.url.isNotEmpty)
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching videos from server: $e');
      return [];
    }
  }

  /// 2. ऐप से सीधे अनलिमिटेड क्लाउड स्टोरेज पर वीडियो अपलोड करना
  /// (नोट: यह हमारे सुरक्षित बैकएंड से जाता है, इसलिए कोई सीक्रेट की लीक नहीं होती!)
  Future<bool> uploadVideoFile({
    required Uint8List fileBytes,
    required String fileName,
    required String caption,
    String username = 'Mehndi_Babu',
  }) async {
    try {
      // Step A: Upload file bytes to cloud storage backend
      final uploadUri = Uri.parse('$baseUrl/api/archive/upload');
      final request = http.Request('POST', uploadUri);
      request.headers['x-filename'] = fileName;
      request.bodyBytes = fileBytes;

      final streamedResponse = await request.send().timeout(const Duration(minutes: 3));
      final responseBody = await streamedResponse.stream.bytesToString();
      
      if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 201) {
        print('Upload failed: $responseBody');
        return false;
      }

      final Map<String, dynamic> uploadData = jsonDecode(responseBody);
      final String cloudUrl = uploadData['archiveDownloadUrl'] ?? uploadData['videoUrl'] ?? '';

      // Step B: Save reel metadata in Firestore database
      final reelUri = Uri.parse('$baseUrl/api/reels');
      final reelPayload = jsonEncode({
        'id': 'reel_${DateTime.now().millisecondsSinceEpoch}',
        'caption': caption.isNotEmpty ? caption : 'New reel uploaded via MS Shorts App 🔥',
        'username': username.startsWith('@') ? username : '@$username',
        'videoUrl': cloudUrl,
        'archiveDownloadUrl': cloudUrl,
        'isUserUploaded': true,
        'visibility': 'public',
        'likes': 1,
        'views': 1,
        'createdAt': DateTime.now().toIso8601String(),
      });

      final reelResponse = await _client.post(
        reelUri,
        headers: {'Content-Type': 'application/json'},
        body: reelPayload,
      );

      return reelResponse.statusCode == 200 || reelResponse.statusCode == 201;
    } catch (e) {
      print('Upload error: $e');
      return false;
    }
  }

  void close() {
    _client.close();
  }
}
