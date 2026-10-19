
import 'dart:convert';
import 'package:http/http.dart' as http;

class ArchiveVideo {
  final String identifier;
  final String title;
  final String url;
  final String creator;

  const ArchiveVideo({
    required this.identifier,
    required this.title,
    required this.url,
    required this.creator,
  });
}

class ArchiveService {
  static const String _account = 'mehndi_babu';

  static Future<List<ArchiveVideo>> fetchVideos() async {
    final uri = Uri.https(
      'archive.org',
      '/advancedsearch.php',
      {
        'q': 'uploader:$_account AND mediatype:movies',
        'fl[]': ['identifier', 'title'],
        'rows': '100',
        'page': '1',
        'sort[]': ['date desc'],
        'output': 'json',
      },
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('Internet Archive se video list nahi mili.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final responseData = data['response'] as Map<String, dynamic>?;
    final docs = responseData?['docs'] as List<dynamic>? ?? [];

    final results = <ArchiveVideo>[];

    for (final entry in docs) {
      if (entry is! Map<String, dynamic>) continue;

      final id = entry['identifier']?.toString() ?? '';
      if (id.isEmpty) continue;

      try {
        final metadataResponse = await http
            .get(Uri.https('archive.org', '/metadata/$id'))
            .timeout(const Duration(seconds: 15));

        if (metadataResponse.statusCode != 200) continue;

        final metadata =
            jsonDecode(metadataResponse.body) as Map<String, dynamic>;
        final files = metadata['files'] as List<dynamic>? ?? [];

        final candidates = files.whereType<Map<String, dynamic>>().where((f) {
          final name = f['name']?.toString().toLowerCase() ?? '';
          return (name.endsWith('.mp4') ||
                  name.endsWith('.m4v') ||
                  name.endsWith('.webm')) &&
              !name.contains('_thumb') &&
              f['private'] != 'true';
        }).toList();

        if (candidates.isEmpty) continue;

        candidates.sort((a, b) {
          final aName = a['name']?.toString().toLowerCase() ?? '';
          final bName = b['name']?.toString().toLowerCase() ?? '';
          final aMp4 = aName.endsWith('.mp4') ? 0 : 1;
          final bMp4 = bName.endsWith('.mp4') ? 0 : 1;
          return aMp4.compareTo(bMp4);
        });

        final filename = candidates.first['name']?.toString() ?? '';
        if (filename.isEmpty) continue;

        final title = metadata['metadata']?['title']?.toString() ??
            entry['title']?.toString() ??
            'MS SHORTS VIP';

        results.add(
          ArchiveVideo(
            identifier: id,
            title: title,
            url: 'https://archive.org/download/$id/'
                '${Uri.encodeComponent(filename)}',
            creator: _account,
          ),
        );
      } catch (_) {
        // Ek video ki metadata fail hone par baaki videos load hoti rahengi.
      }
    }

    return results;
  }
}
