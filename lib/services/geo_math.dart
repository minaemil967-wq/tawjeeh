import 'dart:math' as math;

/// محرك الحسابات الجيوديسية والهندسية واللاسلكية (RF) لتوجيه هوائيات الشبكات
class GeoMath {
  static const double earthRadiusMeters = 6371000.0; // نصف قطر الأرض بالمتر

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

  /// حساب زاوية الميل الرأسي (Elevation / Tilt Angle) بالدرجات مع تصحيح انحناء الأرض
  static double calculateElevationAngle({
    required double alt1Meters,
    required double alt2Meters,
    required double distanceMeters,
    bool applyEarthCurvature = true,
  }) {
    if (distanceMeters <= 0) return 0.0;

    double effectiveAlt2 = alt2Meters;
    if (applyEarthCurvature) {
      final double earthDrop = (distanceMeters * distanceMeters) / (2.0 * earthRadiusMeters);
      effectiveAlt2 -= earthDrop;
    }

    final double deltaHeight = effectiveAlt2 - alt1Meters;
    final double angleRadians = math.atan2(deltaHeight, distanceMeters);
    return toDegrees(angleRadians);
  }

  /// حساب زاوية الانحراف الحالية بين وجهة الهاتف والزاوية المستهدفة (-180 إلى +180)
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
  static double calculateFresnelZoneMaxRadius({
    required double distanceMeters,
    double frequencyGhz = 5.8,
  }) {
    if (distanceMeters <= 0 || frequencyGhz <= 0) return 0.0;
    final double distanceKm = distanceMeters / 1000.0;
    return 8.656 * math.sqrt(distanceKm / frequencyGhz);
  }

  /// 1. حساب الفقد في الفضاء الحر (Free Space Path Loss - FSPL بالديسيبل)
  static double calculateFspl({
    required double distanceMeters,
    double frequencyGhz = 5.8,
  }) {
    if (distanceMeters <= 0) return 0.0;
    final double distanceKm = distanceMeters / 1000.0;
    // FSPL (dB) = 92.45 + 20*log10(d_km) + 20*log10(f_GHz)
    final double logD = math.log(distanceKm) / math.ln10;
    final double logF = math.log(frequencyGhz) / math.ln10;
    return 92.45 + (20.0 * logD) + (20.0 * logF);
  }

  /// 2. حساب قوة الإشارة المتوقعة (Expected RSSI بالـ dBm)
  static double calculateExpectedRssi({
    required double distanceMeters,
    double frequencyGhz = 5.8,
    double txPowerDbm = 23.0,
    double txGainDbi = 23.0,
    double rxGainDbi = 23.0,
    double cableLossDb = 1.0,
  }) {
    if (distanceMeters <= 0) return -90.0;
    final double fspl = calculateFspl(distanceMeters: distanceMeters, frequencyGhz: frequencyGhz);
    return txPowerDbm + txGainDbi + rxGainDbi - fspl - cableLossDb;
  }

  /// تقييم جودة الإشارة وسرعة النقل المتوقعة بناءً على قوة الإشارة
  static Map<String, String> evaluateSignalQuality(double rssiDbm) {
    if (rssiDbm >= -55) {
      return {'quality': 'مثالية وممتازة جداً 🚀', 'speed': 'أقصى سرعة (300+ Mbps / MCS9 256QAM)', 'color': 'green'};
    } else if (rssiDbm >= -65) {
      return {'quality': 'جيدة جداً ومستقرة ✅', 'speed': 'سرعة عالية (150 - 300 Mbps / MCS7-8)', 'color': 'green'};
    } else if (rssiDbm >= -75) {
      return {'quality': 'مقبولة ولكن حساسة للطقس ⚠️', 'speed': 'سرعة متوسطة (50 - 150 Mbps / MCS4-6)', 'color': 'amber'};
    } else {
      return {'quality': 'ضعيفة جداً ومعرضة للانقطاع ❌', 'speed': 'سرعة منخفضة (< 50 Mbps / MCS1-3)', 'color': 'red'};
    }
  }

  /// 3. حساب الحد الأدنى لارتفاع صاري / ماسورة الأنتينا لخلو منطقة فرينل وانحناء الأرض
  static double calculateMinMastHeight({
    required double distanceMeters,
    double frequencyGhz = 5.8,
    double obstacleHeightMeters = 0.0,
  }) {
    final double fresnelRadius = calculateFresnelZoneMaxRadius(
      distanceMeters: distanceMeters,
      frequencyGhz: frequencyGhz,
    );
    // خلو 60% من منطقة فرينل مطلوب كحد أدنى
    final double clearance60 = fresnelRadius * 0.6;
    
    // سهم انحناء كروية الأرض في المنتصف: h = d^2 / (8 * R)
    final double earthBulge = (distanceMeters * distanceMeters) / (8.0 * earthRadiusMeters);

    return clearance60 + earthBulge + obstacleHeightMeters;
  }

  /// 4. فحص عدم توازن القطبين (Dual-Polarity / Chain Imbalance Diagnostic)
  static Map<String, dynamic> evaluateChainImbalance({
    required double chain0Dbm,
    required double chain1Dbm,
  }) {
    final double delta = (chain0Dbm - chain1Dbm).abs();
    if (delta <= 2.0) {
      return {
        'delta': delta,
        'status': 'متطابق وسليم تماماً ✅',
        'advice': 'الاستقطابان الرأسي والأفقي متوازنان، لا داعي لأي تعديل.',
        'color': 'green',
      };
    } else if (delta <= 4.5) {
      return {
        'delta': delta,
        'status': 'انحراف طفيف ⚠️',
        'advice': 'فارق طفيف بين القناتين. قم بتعديل دوران الأنتينا الخفيف حول محورها لتقليل الفارق.',
        'color': 'amber',
      };
    } else {
      return {
        'delta': delta,
        'status': 'خلل كبير في التوازن ❌',
        'advice': 'فارق كبير (${delta.toStringAsFixed(1)} dB). الأنتينا مائلة، أو يوجد عائق ملاصق يكسر أحد الاستقطابين (Vertical أو Horizontal).',
        'color': 'red',
      };
    }
  }

  /// 5. حاسبة الطاقة الشمسية وسعة البطاريات للنقاط النائية
  static Map<String, dynamic> calculateSolarSystem({
    required double totalWatts,
    double autonomyHours = 24.0,
    double peakSunHours = 5.0,
    double systemVoltage = 12.0,
    double batteryDod = 0.5, // 50% عمق التفريغ للبطاريات الجل للحفاظ على عمرها
  }) {
    final double dailyWh = totalWatts * 24.0;
    // قدرة الألواح المطلوبة مع احتساب فواقد الشحن 25%
    final double requiredPanelWatts = (dailyWh / peakSunHours) * 1.25;
    // سعة البطارية المطلوبة بالأمبير/ساعة
    final double requiredBatteryAh = (dailyWh * (autonomyHours / 24.0)) / (systemVoltage * batteryDod);
    // منظم الشحن المطلوب بالأمبير
    final double controllerAmps = (requiredPanelWatts / systemVoltage) * 1.2;

    return {
      'dailyWh': dailyWh,
      'panelWatts': requiredPanelWatts.ceil(),
      'batteryAh': requiredBatteryAh.ceil(),
      'controllerAmps': controllerAmps.ceil(),
    };
  }

  /// 6. توليد تقرير استلام وتوثيق الرابط بصيغة نصية واضحة للمشاركة
  static String generateSurveyReportText({
    required String localSiteName,
    required String remoteSiteName,
    required double distanceMeters,
    required double azimuthDegrees,
    required double tiltDegrees,
    required String antennaName,
    required double expectedRssi,
    double? actualRssi,
    double? chain0,
    double? chain1,
    String? technicianName,
  }) {
    final dateStr = DateTime.now().toString().substring(0, 16);
    final eval = evaluateSignalQuality(actualRssi ?? expectedRssi);

    return '''
📋 تقرير توثيق واستلام رابط لاسلكي (Point-to-Point Link)
-----------------------------------------------
📅 تاريخ ووقت القياس: $dateStr
👷 الفني المسؤول: ${technicianName ?? 'فني الشبكات'}
📡 نوع الهوائي المعتمد: $antennaName

📍 بيانات طرفي الرابط:
• المحطة الأولى: $localSiteName
• المحطة الثانية: $remoteSiteName
• المسافة المباشرة: ${formatDistance(distanceMeters)}

📐 زوايا التوجيه المحققة:
• زاوية السمت (البوصلة): ${azimuthDegrees.toStringAsFixed(1)}° (${formatCardinalDirection(azimuthDegrees)})
• زاوية الميل الرأسي: ${tiltDegrees >= 0 ? '+' : ''}${tiltDegrees.toStringAsFixed(1)}°

📶 قياسات الإشارة والتردد:
• الإشارة المتوقعة نظرياً: ${expectedRssi.toStringAsFixed(0)} dBm
${actualRssi != null ? '• الإشارة الفعلية المحققة: ${actualRssi.toStringAsFixed(0)} dBm' : ''}
${chain0 != null && chain1 != null ? '• توازن القطبين (V/H): ${chain0.toStringAsFixed(0)} / ${chain1.toStringAsFixed(0)} dBm (فارق: ${(chain0 - chain1).abs().toStringAsFixed(1)} dB)' : ''}
• تقييم جودة واستقرار الرابط: ${eval['quality']}
• سعة النقل المقدرة: ${eval['speed']}

تم الفحص والتوجيه باستخدام: برنامج توجيه برو (Tawjeeh Pro)
-----------------------------------------------
''';
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
