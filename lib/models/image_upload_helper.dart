import 'dart:io';
import 'package:http/http.dart' as http;

class BunnyImageUploader {
  static const String storageZone = 'vaella-img';
  static const String cdnBaseUrl = 'https://vaella.b-cdn.net';
  static const String apiEndpoint =
      'https://storage.bunnycdn.com/$storageZone/';
  static const String apiKey = 'b23afd1a-087f-45e4-a2dd6d4a0807-fa20-407a';

  /// Palauttaa CDN-urlin, jos onnistuu. Heittää poikkeuksen jos epäonnistuu.
  static Future<String> uploadImage(File file, {String? fileName}) async {
    fileName ??=
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final uri = Uri.parse('$apiEndpoint$fileName');
    final bytes = await file.readAsBytes();

    final response = await http.put(
      uri,
      headers: {
        'AccessKey': apiKey,
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return '$cdnBaseUrl/$fileName';
    } else {
      throw Exception(
          'Image upload failed: ${response.statusCode} ${response.body}');
    }
  }
}
