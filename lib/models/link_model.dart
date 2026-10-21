import 'package:flutter/foundation.dart';
import 'geo_point.dart';
import 'antenna_model.dart';
import '../services/geo_math.dart';

enum AlignmentState {
  searching,  // جاري البحث أو بعيد جداً (> 25°)
  approaching, // يقترب من الزاوية (بين 5° و 25°)
  locked,     // متطابق تماماً في نطاق فتحة الإشارة (أقل من نصف زاوية الحزمة)
}

/// يمثل حالة الرابط اللاسلكي الكامل بين النقطتين
class LinkModel {
  final GeoPoint localPoint;
  final GeoPoint? remotePoint;
  final AntennaModel antenna;
  final double currentCompassHeading;
  final double currentDevicePitch; // زاوية الميل الرأسي للهاتف

  const LinkModel({
    required this.localPoint,
    this.remotePoint,
    required this.antenna,
    this.currentCompassHeading = 0.0,
    this.currentDevicePitch = 0.0,
  });

  /// المسافة بالأمتار
  double get distanceMeters {
    if (remotePoint == null) return 0.0;
    return GeoMath.calculateDistanceMeters(
      lat1: localPoint.latitude,
      lon1: localPoint.longitude,
      lat2: remotePoint!.latitude,
      lon2: remotePoint!.longitude,
    );
  }

  /// زاوية السمت المستهدفة (0 إلى 360 درجة)
  double get targetBearing {
    if (remotePoint == null) return 0.0;
    return GeoMath.calculateBearing(
      lat1: localPoint.latitude,
      lon1: localPoint.longitude,
      lat2: remotePoint!.latitude,
      lon2: remotePoint!.longitude,
    );
  }

  /// زاوية الميل الرأسي المستهدفة (درجات صعود/هبوط)
  double get targetElevationAngle {
    if (remotePoint == null) return 0.0;
    return GeoMath.calculateElevationAngle(
      alt1Meters: localPoint.altitude,
      alt2Meters: remotePoint!.altitude,
      distanceMeters: distanceMeters,
    );
  }

  /// مقدار الخطأ الأفقي الحالي (درجات الفرق بين اتجاه الموبايل والهدف)
  double get horizontalErrorAngle {
    if (remotePoint == null) return 0.0;
    return GeoMath.calculateHeadingDifference(
      currentHeadingDegrees: currentCompassHeading,
      targetBearingDegrees: targetBearing,
    );
  }

  /// مقدار الخطأ الرأسي الحالي (الفرق بين زاوية رفع الهاتف وزاوية الهدف)
  double get verticalErrorAngle {
    if (remotePoint == null) return 0.0;
    return targetElevationAngle - currentDevicePitch;
  }

  /// حالة المحاذاة الحالية
  AlignmentState get alignmentState {
    if (remotePoint == null) return AlignmentState.searching;
    final double absError = horizontalErrorAngle.abs();
    final double halfBeam = antenna.horizontalBeamwidth / 2.0;

    if (absError <= mathClamp(halfBeam * 0.4, 1.5, 4.0)) {
      return AlignmentState.locked;
    } else if (absError <= halfBeam) {
      return AlignmentState.approaching;
    } else {
      return AlignmentState.searching;
    }
  }

  /// أقصى نصف قطر لمنطقة فرينل
  double get fresnelRadius =>
      GeoMath.calculateFresnelZoneMaxRadius(distanceMeters: distanceMeters);

  static double mathClamp(double val, double min, double max) {
    if (val < min) return min;
    if (val > max) return max;
    return val;
  }
}
