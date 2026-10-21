import 'dart:math' as math;

/// محرك الحسابات الجيوديسية والهندسية لتوجيه هوائيات الشبكات
class GeoMath {
  static const double earthRadiusMeters = 6371000.0; // نصف قطر الأرض التقريبي بالمتر

  /// تحويل الدرجات إلى راديان
  static double toRadians(double degrees) => degrees * (math.pi / 180.0);

  /// تحويل الراديان إلى درجات
  static double toDegrees(double radians) => radians * (180.0 / math.pi);

  /// حساب المسافة بين نقطتين بالمتر باستخدام صيغة هافرسين (Haversine Formula)
  static double calculateDistanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final double phi1 = toRadians(lat1);
    final double phi2 = toRadians(lat2);
    final double deltaPhi = toRadians(lat2 - lat1);
    final double deltaLambda = toRadians(lon2 - lon1);

    final double a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) * math.cos(phi2) *
        math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// حساب زاوية السمت الأفقية (Azimuth / Bearing) بالدرجات من 0 إلى 360
  /// تعبر عن اتجاه النقطة 2 بالنسبة للنقطة 1 نسبة للشمال الجغرافي
  static double calculateBearing({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final double phi1 = toRadians(lat1);
    final double phi2 = toRadians(lat2);
    final double deltaLambda = toRadians(lon2 - lon1);

    final double y = math.sin(deltaLambda) * math.cos(phi2);
    final double x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    final double initialBearingRadians = math.atan2(y, x);
    final double bearingDegrees = (toDegrees(initialBearingRadians) + 360.0) % 360.0;
    return bearingDegrees;
  }

  /// حساب زاوية الميل الرأسي (Elevation / Tilt Angle) بالدرجات
  /// القيمة الموجبة تعني توجيه الأنتينا لأعلى، والسالبة تعني توجيهها لأسفل
  /// مع تطبيق تصحيح انحناء الأرض للمسافات الطويلة
  static double calculateElevationAngle({
    required double alt1Meters,
    required double alt2Meters,
    required double distanceMeters,
    bool applyEarthCurvature = true,
  }) {
    if (distanceMeters <= 0) return 0.0;

    // تصحيح انحناء كروية الأرض: drop = d^2 / (2 * R)
    double effectiveAlt2 = alt2Meters;
    if (applyEarthCurvature) {
      final double earthDrop = (distanceMeters * distanceMeters) / (2.0 * earthRadiusMeters);
      effectiveAlt2 -= earthDrop;
    }

    final double deltaHeight = effectiveAlt2 - alt1Meters;
    final double angleRadians = math.atan2(deltaHeight, distanceMeters);
    return toDegrees(angleRadians);
  }

  /// حساب زاوية الانحراف الحالية بين وجهة الهاتف والزاوية المستهدفة
  /// القيمة تتراوح بين -180 إلى +180:
  /// - قيمة سالبة: در لليسار
  /// - قيمة موجبة: در لليمين
  /// - صفر (أو قرب الصفر): أنت في اتجاه الهدف تماماً
  static double calculateHeadingDifference({
    required double currentHeadingDegrees,
    required double targetBearingDegrees,
  }) {
    double diff = (targetBearingDegrees - currentHeadingDegrees) % 360.0;
    if (diff > 180.0) {
      diff -= 360.0;
    } else if (diff < -180.0) {
      diff += 360.0;
    }
    return diff;
  }

  /// حساب أقصى نصف قطر لمنطقة فرينل الأولى (First Fresnel Zone Radius) بالمتر
  /// مهم جداً لفحص خلو مسار الإشارة من المباني والأشجار
  /// التردد الافتراضي: 5.8 GHz لأجهزة النانو ستيشن الشائعة
  static double calculateFresnelZoneMaxRadius({
    required double distanceMeters,
    double frequencyGhz = 5.8,
  }) {
    if (distanceMeters <= 0 || frequencyGhz <= 0) return 0.0;
    final double distanceKm = distanceMeters / 1000.0;
    // F1(radius) = 8.656 * sqrt(D_km / f_GHz) at midpoint
    return 8.656 * math.sqrt(distanceKm / frequencyGhz);
  }

  /// تحويل الزاوية إلى الاتجاه النصفي للبوصلة بالعربية والإنجليزية
  static String formatCardinalDirection(double bearingDegrees) {
    const directionsAr = [
      'شمال (N)', 'شمال شرق (NNE)', 'شمال شرق (NE)', 'شرق شمال شرق (ENE)',
      'شرق (E)', 'شرق جنوب شرق (ESE)', 'جنوب شرق (SE)', 'جنوب جنوب شرق (SSE)',
      'جنوب (S)', 'جنوب غرب (SSW)', 'جنوب غرب (SW)', 'غرب جنوب غرب (WSW)',
      'غرب (W)', 'غرب شمال غرب (WNW)', 'شمال غرب (NW)', 'شمال شمال غرب (NNW)',
    ];

    final int index = ((bearingDegrees + 11.25) % 360.0 / 22.5).floor();
    return directionsAr[index % 16];
  }

  /// تنسيق المسافة لعرض مفهوم (أمتار أو كيلومترات)
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(1)} متر';
    } else {
      return '${(meters / 1000.0).toStringAsFixed(2)} كم';
    }
  }
}
