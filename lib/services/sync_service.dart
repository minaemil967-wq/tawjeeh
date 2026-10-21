import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/geo_point.dart';

/// خدمة المزامنة الحية متعددة الأجهزة (Multi-Peer Live Sync)
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  MqttServerClient? _client;
  String? _currentRoomCode;
  String? _myDeviceId;
  String _myDeviceName = 'محطة فنية';
  bool _isConnected = false;

  // قائمة الأجهزة المتصلة في الغرفة (خريطة بمعرف الجهاز)
  final Map<String, GeoPoint> _peersMap = {};
  String? _selectedPeerId;

  final _peersListController = StreamController<List<GeoPoint>>.broadcast();
  Stream<List<GeoPoint>> get peersStream => _peersListController.stream;

  final _selectedPeerController = StreamController<GeoPoint?>.broadcast();
  Stream<GeoPoint?> get selectedPeerStream => _selectedPeerController.stream;

  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  Timer? _pruneTimer;
  Timer? _heartbeatTimer;
  GeoPoint? _lastPublishedPoint;

  bool get isConnected => _isConnected;
  String? get currentRoomCode => _currentRoomCode;
  String? get myDeviceId => _myDeviceId;
  String get myDeviceName => _myDeviceName;
  List<GeoPoint> get currentPeers => _peersMap.values.toList();
  GeoPoint? get selectedPeer => _selectedPeerId != null ? _peersMap[_selectedPeerId] : null;

  void setDeviceName(String name) {
    _myDeviceName = name.trim();
    if (_lastPublishedPoint != null) {
      publishMyLocation(_lastPublishedPoint!);
    }
  }

  void selectPeer(String deviceId) {
    if (_peersMap.containsKey(deviceId)) {
      _selectedPeerId = deviceId;
      _selectedPeerController.add(_peersMap[deviceId]);
      _notifyPeersUpdated();
    }
  }

  /// بدء الانضمام لغرفة بمفتاح سري (مثلاً 5421)
  Future<bool> joinRoom({
    required String roomCode,
    String? deviceName,
  }) async {
    _currentRoomCode = roomCode.trim().toUpperCase();
    if (deviceName != null && deviceName.isNotEmpty) {
      _myDeviceName = deviceName;
    }
    _myDeviceId = 'dev_${DateTime.now().millisecondsSinceEpoch % 100000}';
    _peersMap.clear();
    _selectedPeerId = null;

    try {
      // الاتصال بوسيط MQTT الموثوق
      _client = MqttServerClient.withPort('broker.emqx.io', 'tawjeeh_${_myDeviceId}', 1883);
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 20;
      _client!.autoReconnect = true;

      final connMessage = MqttConnectMessage()
          .withClientIdentifier('tawjeeh_${_myDeviceId}')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      _client!.connectionMessage = connMessage;

      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        _isConnected = true;
        _connectionStateController.add(true);

        // الاشتراك في موضوع الغرفة الموحد
        final topic = 'tawjeeh/room/$_currentRoomCode/coords';
        _client!.subscribe(topic, MqttQos.atLeastOnce);

        _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
          final recMess = c[0].payload as MqttPublishMessage;
          final pt = utf8.decode(recMess.payload.message);

          try {
            final data = jsonDecode(pt) as Map<String, dynamic>;
            final senderId = (data['deviceId'] ?? data['senderId']) as String?;

            // تجاهل الرسائل الصادرة من نفس الجهاز
            if (senderId != null && senderId != _myDeviceId) {
              final peerPoint = GeoPoint.fromJson(data).copyWith(deviceId: senderId);
              _peersMap[senderId] = peerPoint;

              // إذا لم يكن هناك جهاز مستهدف مختار بعد، نختار أول جهاز يظهر تلقائياً
              if (_selectedPeerId == null || !_peersMap.containsKey(_selectedPeerId)) {
                _selectedPeerId = senderId;
                _selectedPeerController.add(peerPoint);
              } else if (_selectedPeerId == senderId) {
                _selectedPeerController.add(peerPoint);
              }

              _notifyPeersUpdated();
            }
          } catch (e) {
            debugPrint('خطأ في معالجة إحداثيات الجهاز البعيد: $e');
          }
        });

        // تشغيل مؤقت لتنظيف الأجهزة التي انقطعت لأكثر من 45 ثانية
        _pruneTimer?.cancel();
        _pruneTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pruneInactivePeers());

        return true;
      }
    } catch (e) {
      debugPrint('فشل الاتصال بالغرفة السحابية: $e');
      _isConnected = false;
      _connectionStateController.add(false);
    }
    return false;
  }

  /// إرسال إحداثيات موقعي الحالي لجميع الأجهزة في الغرفة
  void publishMyLocation(GeoPoint point) {
    if (!_isConnected || _client == null || _currentRoomCode == null) return;

    _lastPublishedPoint = point;

    try {
      final topic = 'tawjeeh/room/$_currentRoomCode/coords';
      final payload = point.toJson();
      payload['deviceId'] = _myDeviceId;
      payload['name'] = _myDeviceName;

      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode(payload));

      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    } catch (e) {
      debugPrint('خطأ في إرسال الموقع: $e');
    }
  }

  void _pruneInactivePeers() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    _peersMap.forEach((key, value) {
      if (now.difference(value.timestamp).inSeconds > 45) {
        expiredKeys.add(key);
      }
    });

    if (expiredKeys.isNotEmpty) {
      for (final k in expiredKeys) {
        _peersMap.remove(k);
      }
      if (_selectedPeerId != null && !_peersMap.containsKey(_selectedPeerId)) {
        _selectedPeerId = _peersMap.isNotEmpty ? _peersMap.keys.first : null;
        _selectedPeerController.add(selectedPeer);
      }
      _notifyPeersUpdated();
    }
  }

  void _notifyPeersUpdated() {
    final list = _peersMap.entries.map((e) {
      return e.value.copyWith(isSelected: e.key == _selectedPeerId);
    }).toList();
    _peersListController.add(list);
  }

  /// مغادرة الغرفة
  void leaveRoom() {
    _pruneTimer?.cancel();
    _heartbeatTimer?.cancel();
    try {
      _client?.disconnect();
    } catch (_) {}
    _isConnected = false;
    _currentRoomCode = null;
    _peersMap.clear();
    _selectedPeerId = null;
    _connectionStateController.add(false);
    _peersListController.add([]);
    _selectedPeerController.add(null);
  }
}
