import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  late final MqttServerClient client;

  Function(Map<String, dynamic>)? onMessage;

  final String broker;
  final int port;
  final String topic;

  MqttService({
    this.broker = 'broker.hivemq.com',
    this.port = 1883,
    this.topic = 'ecowitt/weather',
  }) {
    client = MqttServerClient(
      broker,
      'flutter_skysense_${DateTime.now().millisecondsSinceEpoch}',
    );

    client.port = port;
    client.keepAlivePeriod = 20;
    client.logging(on: false);

    client.autoReconnect = true;
    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;
    client.onSubscribed = (t) => _log("✅ Subscribed: $t");
    client.onAutoReconnect = () => _log("🟡 Auto reconnect...");
    client.onAutoReconnected = () => _log("🟢 Auto reconnected");
  }

  Future<void> connect() async {
    final connMessage = MqttConnectMessage()
        .withClientIdentifier(client.clientIdentifier)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } catch (e) {
      _log("❌ MQTT connect error: $e");
      client.disconnect();
      return;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      subscribe();
    } else {
      _log("❌ MQTT not connected. status=${client.connectionStatus}");
    }
  }

  void subscribe() {
    if (client.connectionStatus?.state != MqttConnectionState.connected) return;

    client.subscribe(topic, MqttQos.atMostOnce);

    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> events) {
      final recMess = events.first.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      try {
        final data = jsonDecode(payload);
        if (data is Map<String, dynamic>) {
          onMessage?.call(data);
        } else if (data is Map) {
          onMessage?.call(data.cast<String, dynamic>());
        }
      } catch (_) {
        // bukan json -> abaikan
      }
    });
  }

  void disconnect() {
    try {
      client.disconnect();
    } catch (_) {}
  }

  void _onConnected() => _log("🟢 MQTT connected to $broker:$port");
  void _onDisconnected() => _log("🟠 MQTT disconnected");

  void _log(String msg) {
    // ignore: avoid_print
    print(msg);
  }
}
