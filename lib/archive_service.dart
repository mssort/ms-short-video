
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

  static const Set<String> _videoExtensions = {
    'mp4',
    'm4v',
    'mov',
    'webm',
  };

  Future<List<ArchiveVideo>> fetchVideos({
    int maxPages = 3,
  }) async {
    final Map<String, ArchiveVideo> results = {};

    // Add every known uploader here, using their exact
    // Internet Archive username.
    const uploaders = [
      'mehndi_babu',
      'supriya_kumari',
    ];

    for (final uploader in uploaders) {
      for (var page = 1; page <= maxPages; page++) {
        final query = 'mediatype:movies AND uploader:$uploader';

        final uri = Uri.parse(_searchUrl).replace(
          queryParameters: {
            'q': query,
            'fl[]': 'identifier,title',
            'rows': '50',
            'page': '$page',
            'output': 'json',
          },
        );

        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 25));

        if (response.statusCode != 200) {
          throw Exception(
            'Internet Archive search failed: ${response.statusCode}',
          );
        }

        final decoded =
            jsonDecode(response.body) as Map<String, dynamic>;
        final responseData =
            decoded['response'] as Map<String, dynamic>;
        final docs = responseData['docs'] as List<dynamic>;

        if (docs.isEmpty) break;

        for (final entry in docs) {
          final doc = entry as Map<String, dynamic>;
          final id = doc['identifier']?.toString() ?? '';
          if (id.isEmpty || results.containsKey(id)) continue;

          try {
            final video = await _getVideo(id, uploader);
            if (video != null) results[id] = video;
          } catch (_) {
            // Skip an unavailable item and continue loading others.
          }
        }
      }
    }

    return results.values.toList();
  }

  Future<ArchiveVideo?> _getVideo(
    String id,
    String uploader,
  ) async {
    final uri = Uri.https(
      'archive.org',
      '/metadata/$id',
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final files = data['files'] as List<dynamic>? ?? [];

    final candidates = files
        .whereType<Map<String, dynamic>>()
        .where((file) {
          final name = file['name']?.toString() ?? '';
          final ext = name.contains('.')
              ? name.split('.').last.toLowerCase()
              : '';
          return _videoExtensions.contains(ext) &&
              file['private'] != 'true';
        })
        .toList();

    if (candidates.isEmpty) return null;

    // Prefer MP4 for wider Android compatibility.
    candidates.sort((a, b) {
      int score(Map<String, dynamic> file) {
        final name = file['name']?.toString().toLowerCase() ?? '';
        if (name.endsWith('.mp4')) return 0;
        if (name.endsWith('.m4v')) return 1;
        if (name.endsWith('.mov')) return 2;
        return 3;
      }

      return score(a).compareTo(score(b));
    });

    final fileName = candidates.first['name']?.toString();
    if (fileName == null || fileName.isEmpty) return null;

    final title =
        data['metadata']?['title']?.toString() ?? id;

    final encodedPath = fileName
        .split('/')
        .map(Uri.encodeComponent)
        .join('/');

    return ArchiveVideo(
      id: id,
      title: title,
      uploader: uploader,
      url: 'https://archive.org/download/$id/$encodedPath',
    );
  }
}
