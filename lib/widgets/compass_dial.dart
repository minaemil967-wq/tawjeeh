import 'dart:math' as math;
import 'package:flutter/material.dart';

/// قرص البوصلة الهندسي الدائري المتطور لتوجيه الأنتينا
class CompassDial extends StatelessWidget {
  final double currentHeading;   // زاوية وجهة الهاتف الحالية
  final double targetBearing;    // زاوية الهدف المحسوبة
  final double horizontalBeamwidth; // زاوية فتحة الإشارة
  final bool isLocked;           // هل تم التطابق؟

  const CompassDial({
    super.key,
    required this.currentHeading,
    required this.targetBearing,
    required this.horizontalBeamwidth,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double size = math.min(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          alignment: Alignment.center,
          children: [
            // خلفية البوصلة الدوارة (تلف مع دوران الهاتف بحيث يشير الشمال للشمال الحقيقي)
            Transform.rotate(
              angle: -currentHeading * (math.pi / 180.0),
              child: CustomPaint(
                size: Size(size, size),
                painter: _CompassFacePainter(),
              ),
            ),

            // قوس وسهم اتجاه الهدف
            Transform.rotate(
              angle: (targetBearing - currentHeading) * (math.pi / 180.0),
              child: CustomPaint(
                size: Size(size, size),
                painter: _TargetPointerPainter(
                  beamwidth: horizontalBeamwidth,
                  isLocked: isLocked,
                ),
              ),
            ),

            // مؤشر رأس الهاتف الثابت في الأعلى (خط التوجيه المباشر)
            Positioned(
              top: (constraints.maxHeight - size) / 2 + 8,
              child: Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: isLocked ? Colors.greenAccent : Colors.amberAccent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: (isLocked ? Colors.greenAccent : Colors.amberAccent)
                          .withOpacity(0.8),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),

            // الدائرة المركزية مع القراءات الرقمية
            Container(
              width: size * 0.38,
              height: size * 0.38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E293B),
                    const Color(0xFF0F172A),
                  ],
                ),
                border: Border.all(
                  color: isLocked ? Colors.greenAccent : Colors.cyan.withOpacity(0.5),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isLocked
                        ? Colors.greenAccent.withOpacity(0.4)
                        : Colors.cyan.withOpacity(0.2),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${currentHeading.toStringAsFixed(0)}°',
                    style: TextStyle(
                      fontSize: size * 0.08,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? Colors.greenAccent : Colors.white,
                    ),
                  ),
                  Text(
                    isLocked ? 'محاذاة تامة' : 'وجهة الهاتف',
                    style: TextStyle(
                      fontSize: size * 0.035,
                      color: isLocked ? Colors.greenAccent : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// رسم تدريجات وأرقام وجهات البوصلة
class _CompassFacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final circlePaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, circlePaint);

    final borderPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..width = 2.0;
    canvas.drawCircle(center, radius - 2, borderPaint);

    final tickPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1.5;

    final majorTickPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2.5;

    // رسم 72 تدريج (كل 5 درجات)
    for (int i = 0; i < 360; i += 5) {
      final isMajor = (i % 30 == 0);
      final isQuarter = (i % 90 == 0);
      final angle = i * (math.pi / 180.0);
      final tickLength = isQuarter ? 14.0 : (isMajor ? 10.0 : 6.0);

      final p1 = Offset(
        center.dx + (radius - 4) * math.sin(angle),
        center.dy - (radius - 4) * math.cos(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 4 - tickLength) * math.sin(angle),
        center.dy - (radius - 4 - tickLength) * math.cos(angle),
      );

      canvas.drawLine(p1, p2, isMajor ? majorTickPaint : tickPaint);
    }

    // كتابة الأحرف الأساسية (شمال N، شرق E، جنوب S، غرب W)
    _drawText(canvas, 'N', center.dx, center.dy - radius + 24, Colors.redAccent, 18);
    _drawText(canvas, 'E', center.dx + radius - 24, center.dy, Colors.white70, 16);
    _drawText(canvas, 'S', center.dx, center.dy + radius - 24, Colors.white70, 16);
    _drawText(canvas, 'W', center.dx - radius + 24, center.dy, Colors.white70, 16);
  }

  void _drawText(Canvas canvas, String text, double x, double y, Color color, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// رسم سهم اتجاه الهدف وقوس زاوية الشعاع (Beamwidth Arc)
class _TargetPointerPainter extends CustomPainter {
  final double beamwidth;
  final bool isLocked;

  _TargetPointerPainter({
    required this.beamwidth,
    required this.isLocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final targetColor = isLocked ? Colors.greenAccent : const Color(0xFF00E5FF);

    // 1. رسم قوس فتحة شعاع الأنتينا (Beamwidth)
    final arcPaint = Paint()
      ..color = targetColor.withOpacity(isLocked ? 0.35 : 0.18)
      ..style = PaintingStyle.fill;

    final halfAngleRad = (beamwidth / 2.0) * (math.pi / 180.0);
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      -math.pi / 2 - halfAngleRad,
      halfAngleRad * 2,
      true,
      arcPaint,
    );

    // 2. رسم سهم الهدف الحاد والمضيء
    final arrowPaint = Paint()
      ..color = targetColor
      ..style = PaintingStyle.fill;

    final arrowPath = Path();
    final topPoint = Offset(center.dx, center.dy - radius + 4);
    arrowPath.moveTo(topPoint.dx, topPoint.dy);
    arrowPath.lineTo(topPoint.dx - 14, topPoint.dy + 26);
    arrowPath.lineTo(topPoint.dx, topPoint.dy + 20);
    arrowPath.lineTo(topPoint.dx + 14, topPoint.dy + 26);
    arrowPath.close();

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _TargetPointerPainter oldDelegate) {
    return oldDelegate.beamwidth != beamwidth || oldDelegate.isLocked != isLocked;
  }
}
