/// يمثل نقطة جغرافية لموقع أحد الأجهزة المتصلة
class GeoPoint {
  final String deviceId;
  final String deviceName;
  final double latitude;
  final double longitude;
  final double altitude; // بالأمتار
  final double accuracy; // دقة الـ GPS بالمتر
  final DateTime timestamp;
  final bool isSelected;

  const GeoPoint({
    this.deviceId = '',
    this.deviceName = 'موقع غير معروف',
    required this.latitude,
    required this.longitude,
    this.altitude = 0.0,
    this.accuracy = 0.0,
    required this.timestamp,
    this.isSelected = false,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'name': deviceName,
    'lat': latitude,
    'lon': longitude,
    'alt': altitude,
    'acc': accuracy,
    'time': timestamp.millisecondsSinceEpoch,
  };

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
    deviceId: json['deviceId'] as String? ?? json['senderId'] as String? ?? '',
    deviceName: json['name'] as String? ?? 'طرف الرابط',
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lon'] as num).toDouble(),
    altitude: (json['alt'] as num?)?.toDouble() ?? 0.0,
    accuracy: (json['acc'] as num?)?.toDouble() ?? 0.0,
    timestamp: json['time'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['time'] as int)
        : DateTime.now(),
  );

  GeoPoint copyWith({
    String? deviceId,
    String? deviceName,
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    DateTime? timestamp,
    bool? isSelected,
  }) {
    return GeoPoint(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
