
import 'dart:async';
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

  static const String _metadataUrl = 'https://archive.org/metadata';

  static const Set<String> _videoExtensions = {
    'mp4',
    'm4v',
    'webm',
    'mov',
  };

  final http.Client _client;

  ArchiveService({http.Client? client})
      : _client = client ?? http.Client();

  Future<List<ArchiveVideo>> fetchVideos({
    int maxPages = 1,
    int rowsPerPage = 30,
  }) async {
    final Map<String, ArchiveVideo> results = {};

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
            'rows': '$rowsPerPage',
            'page': '$page',
            'output': 'json',
          },
        );

        try {
          final response = await _client
              .get(uri)
              .timeout(const Duration(seconds: 20));

          if (response.statusCode != 200) continue;

          final decoded =
              jsonDecode(response.body) as Map<String, dynamic>;
          final responseData =
              decoded['response'] as Map<String, dynamic>?;

          final docs = responseData?['docs'] as List<dynamic>? ?? [];

          if (docs.isEmpty) break;

          for (final entry in docs) {
            if (entry is! Map<String, dynamic>) continue;

            final id = entry['identifier']?.toString() ?? '';
            if (id.isEmpty || results.containsKey(id)) continue;

            try {
              final video = await _getVideo(id, uploader);
              if (video != null) results[id] = video;
            } catch (_) {
              // Skip a failed item instead of stopping the whole feed.
            }
          }
        } on TimeoutException {
          continue;
        } on FormatException {
          continue;
        } catch (_) {
          continue;
        }
      }
    }

    return results.values.toList();
  }

  Future<ArchiveVideo?> _getVideo(
    String id,
    String uploader,
  ) async {
    final uri = Uri.https('archive.org', '/metadata/$id');

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawFiles = data['files'] as List<dynamic>? ?? [];

    final candidates = rawFiles
        .whereType<Map<String, dynamic>>()
        .where((file) {
          final name = file['name']?.toString() ?? '';
          final extension = name.contains('.')
              ? name.split('.').last.toLowerCase()
              : '';

          final privateValue = file['private']?.toString() ?? 'false';

          return _videoExtensions.contains(extension) &&
              privateValue != 'true' &&
              !name.endsWith('_thumb.jpg') &&
              !name.endsWith('.torrent');
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

    final rawTitle = data['metadata'] is Map<String, dynamic>
        ? (data['metadata'] as Map<String, dynamic>)['title']
        : null;

    final title = rawTitle?.toString().trim().isNotEmpty == true
        ? rawTitle.toString().trim()
        : id;

    final encodedPath =
        fileName.split('/').map(Uri.encodeComponent).join('/');

    return ArchiveVideo(
      id: id,
      title: title,
      uploader: uploader,
      url: 'https://archive.org/download/$id/$encodedPath',
    );
  }

  void close() {
    _client.close();
  }
}
