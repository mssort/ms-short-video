
import 'dart:convert';
import 'package:http/http.dart' as http;

class ArchiveVideo {
  final String id;
  final String title;
  final String uploader;
  final String url;

  const ArchiveVideo({
    required this.id,
    required this.title,
    required this.uploader,
    required this.url,
  });
}

class ArchiveService {
  static const String _searchUrl =
      'https://archive.org/advancedsearch.php';

  static const Set<String> _extensions = {
    'mp4',
    'm4v',
    'mov',
    'webm',
  };

  Future<List<ArchiveVideo>> fetchVideos({
    int maxPages = 1,
  }) async {
    final results = <ArchiveVideo>[];
    final seen = <String>{};

    const uploaders = [
      'mehndi_babu',
      'supriya_kumari',
    ];

    for (final uploader in uploaders) {
      for (var page = 1; page <= maxPages; page++) {
        final uri = Uri.parse(_searchUrl).replace(
          queryParameters: {
            'q': 'mediatype:movies AND uploader:$uploader',
            'fl[]': 'identifier,title',
            'rows': '30',
            'page': '$page',
            'output': 'json',
          },
        );

        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 20));

        if (response.statusCode != 200) {
          throw Exception('वीडियो सूची लोड नहीं हुई');
        }

        final decoded =
            jsonDecode(response.body) as Map<String, dynamic>;
        final data =
            decoded['response'] as Map<String, dynamic>;
        final docs = data['docs'] as List<dynamic>;

        if (docs.isEmpty) break;

        final ids = docs
            .whereType<Map<String, dynamic>>()
            .map((doc) => doc['identifier']?.toString() ?? '')
            .where((id) => id.isNotEmpty && !seen.contains(id))
            .toList();

        seen.addAll(ids);

        final videos = await Future.wait(
          ids.map((id) => _getVideo(id, uploader)),
        );

        results.addAll(videos.whereType<ArchiveVideo>());
      }
    }

    return results;
  }

  Future<ArchiveVideo?> _getVideo(
    String id,
    String uploader,
  ) async {
    try {
      final response = await http
          .get(Uri.https('archive.org', '/metadata/$id'))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return null;

      final data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final files = data['files'] as List<dynamic>? ?? [];

      final candidates = files
          .whereType<Map<String, dynamic>>()
          .where((file) {
            final name = file['name']?.toString() ?? '';
            final ext = name.contains('.')
                ? name.split('.').last.toLowerCase()
                : '';
            return _extensions.contains(ext) &&
                file['private'] != 'true';
          })
          .toList();

      if (candidates.isEmpty) return null;

      candidates.sort((a, b) {
        int score(Map<String, dynamic> file) {
          final name = file['name']?.toString().toLowerCase() ?? '';
          if (name.endsWith('.mp4')) return 0;
          if (name.endsWith('.m4v')) return 1;
          if (name.endsWith('.webm')) return 2;
          return 3;
        }

        return score(a).compareTo(score(b));
      });

      final fileName = candidates.first['name']?.toString();
      if (fileName == null || fileName.isEmpty) return null;

      final encodedPath = fileName
          .split('/')
          .map(Uri.encodeComponent)
          .join('/');

      return ArchiveVideo(
        id: id,
        title: data['metadata']?['title']?.toString() ?? id,
        uploader: uploader,
        url: 'https://archive.org/download/$id/$encodedPath',
      );
    } catch (_) {
      return null;
    }
  }
}
