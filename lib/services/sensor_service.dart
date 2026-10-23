import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/geo_point.dart';

/// خدمة قراءة الحساسات المتكاملة (GPS، البوصلة، زاوية الميل، والاهتزازات)
class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  final _localPointController = StreamController<GeoPoint>.broadcast();
  Stream<GeoPoint> get localPointStream => _localPointController.stream;

  final _headingController = StreamController<double>.broadcast();
  Stream<double> get headingStream => _headingController.stream;

  final _pitchController = StreamController<double>.broadcast();
  Stream<double> get pitchStream => _pitchController.stream;

  GeoPoint? _lastPoint;
  double _lastHeading = 0.0;
  double _lastPitch = 0.0;
  bool _hasVibrator = false;
  DateTime _lastVibeTime = DateTime.now();

  GeoPoint? get lastPoint => _lastPoint;
  double get lastHeading => _lastHeading;
  double get lastPitch => _lastPitch;

  /// تهيئة الحساسات وطلب الأذونات
  Future<bool> initSensors() async {
    // فحص إذن الموقع الجغرافي
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // بدء التقاط الـ GPS بدقة عالية
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1, // كل متر واحد
      ),
    ).listen((Position pos) {
      final point = GeoPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        altitude: pos.altitude,
        accuracy: pos.accuracy,
        deviceName: 'أنت',
        timestamp: DateTime.now(),
      );
      _lastPoint = point;
      _localPointController.add(point);
    });

    // بدء التقاط البوصلة الرقمية
    _compassSub = FlutterCompass.events?.listen((event) {
      final heading = event.heading ?? 0.0;
      final normalizedHeading = (heading + 360.0) % 360.0;
      _lastHeading = normalizedHeading;
      _headingController.add(normalizedHeading);
    });

    // بدء التقاط الجيروسكوب/التسارع لحساب ميل الهاتف (Pitch Angle)
    _accelSub = accelerometerEventStream().listen((AccelerometerEvent event) {
      // حساب زاوية الرفع للأعلى والأسفل (Pitch)
      // عند رفع الهاتف في وضع عمودي يكون Pitch = 0°
      final double pitchRadians = math.atan2(
        event.y,
        math.sqrt(event.x * event.x + event.z * event.z),
      );
      final double pitchDegrees = pitchRadians * (180.0 / math.pi);
      _lastPitch = pitchDegrees;
      _pitchController.add(pitchDegrees);
    });

    return true;
  }

  /// إطلاق اهتزاز تفاعلي عند الاقتراب أو التطابق
  void triggerAlignmentHaptic(double errorDegrees) {
    final now = DateTime.now();
    final absErr = errorDegrees.abs();

    if (absErr <= 2.0) {
      // تطابق كامل: اهتزاز مستمر خفيف
      if (now.difference(_lastVibeTime).inMilliseconds > 200) {
        HapticFeedback.heavyImpact();
        _lastVibeTime = now;
      }
    } else if (absErr <= 8.0) {
      // اقتراب: نبضات متباعدة
      if (now.difference(_lastVibeTime).inMilliseconds > 600) {
        HapticFeedback.lightImpact();
        _lastVibeTime = now;
      }
    }
  }

  void dispose() {
    _positionSub?.cancel();
    _compassSub?.cancel();
    _accelSub?.cancel();
  }
}
