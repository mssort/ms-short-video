
import 'dart:convert';
import 'package:http/http.dart' as http;

class ArchiveVideo {
  final String identifier;
  final String title;
  final String videoUrl;
  final String? thumbnailUrl;

  const ArchiveVideo({
    required this.identifier,
    required this.title,
    required this.videoUrl,
    this.thumbnailUrl,
  });

  factory ArchiveVideo.fromJson(Map<String, dynamic> json) {
    return ArchiveVideo(
      identifier: json['identifier']?.toString() ?? '',
      title: json['title']?.toString() ?? 'MS SHORTS VIP',
      videoUrl: json['videoUrl']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString(),
    );
  }
}

class ArchiveService {
  static const String account =
      'https://archive.org/advancedsearch.php';

  static Future<List<ArchiveVideo>> fetchVideos() async {
    final uri = Uri.parse(account).replace(
      queryParameters: {
        'q': 'collection:opensource_movies AND mediatype:movies',
        'fl[]': 'identifier,title',
        'sort[]': 'date desc',
        'rows': '100',
        'page': '1',
        'output': 'json',
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Internet Archive se videos nahi mil payin.');
    }

    final decoded = jsonDecode(response.body);
    final docs = decoded['response']['docs'] as List;

    final List<ArchiveVideo> videos = [];

    for (final item in docs) {
      final id = item['identifier']?.toString() ?? '';
      if (id.isEmpty) continue;

      try {
        final metadataResponse = await http.get(
          Uri.parse('https://archive.org/metadata/$id'),
        );

        if (metadataResponse.statusCode != 200) continue;

        final metadata = jsonDecode(metadataResponse.body);
        final files = metadata['files'] as List? ?? [];

        final videoFiles = files.where((file) {
          final name = file['name']?.toString().toLowerCase() ?? '';
          return name.endsWith('.mp4') ||
              name.endsWith('.m4v') ||
              name.endsWith('.webm');
        }).toList();

        if (videoFiles.isEmpty) continue;

        final fileName = videoFiles.first['name'].toString();
        final encodedName = Uri.encodeComponent(fileName);

        videos.add(
          ArchiveVideo(
            identifier: id,
            title: item['title']?.toString() ?? id,
            videoUrl:
                'https://archive.org/download/$id/$encodedName',
          ),
        );
      } catch (_) {
        // Ek video mein error ho to baaki videos load hoti rahengi.
      }
    }

    return videos;
  }
}
