import 'dart:convert';

import 'package:http/http.dart' as http;

/// Change this if you ever move the backend.
const kBaseUrl = 'https://ai-trip-planner-agent-u4v3.onrender.com';

class ChatMsg {
  final String role; // 'user' | 'assistant'
  String text;
  ChatMsg(this.role, this.text);
  bool get isUser => role == 'user';
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class WayfarerApi {
  final http.Client _client = http.Client();

  /// GET /api/history?sid=...  ->  {"messages":[{"role","content"}]}
  Future<List<ChatMsg>> history(String sid) async {
    final res = await _client
        .get(Uri.parse('$kBaseUrl/api/history').replace(queryParameters: {'sid': sid}))
        .timeout(const Duration(seconds: 75));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['messages'] as List)
        .map((m) => ChatMsg(m['role'] as String, m['content'] as String))
        .toList();
  }

  /// POST /api/clear {"session_id": ...}
  Future<void> clear(String sid) async {
    await _client.post(
      Uri.parse('$kBaseUrl/api/clear'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'session_id': sid}),
    );
  }

  /// POST /api/chat {"session_id","message"}  ->  streamed text/plain (markdown).
  /// Yields text chunks as the AI writes them.
  Stream<String> chat(String sid, String message) async* {
    final req = http.Request('POST', Uri.parse('$kBaseUrl/api/chat'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({'session_id': sid, 'message': message});

    final res = await _client.send(req).timeout(const Duration(seconds: 90));

    if (res.statusCode != 200) {
      final body = await res.stream.bytesToString();
      throw ApiException(body.isEmpty ? 'Something went wrong (${res.statusCode}).' : body);
    }
    yield* res.stream.transform(utf8.decoder);
  }
}
