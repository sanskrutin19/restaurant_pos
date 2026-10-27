import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final String url;
  final Function(dynamic) onMessage;
  final Function() onDisconnect;

  WebSocketService({
    required this.url,
    required this.onMessage,
    required this.onDisconnect,
  });

  void connect() {
    try {
      final wsUrl = '${url.replaceFirst("http", "ws")}/ws';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.stream.listen(
        (message) {
          final decoded = jsonDecode(message);
          onMessage(decoded);
        },
        onDone: () {
          onDisconnect();
        },
        onError: (error) {
          onDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      onDisconnect();
    }
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
