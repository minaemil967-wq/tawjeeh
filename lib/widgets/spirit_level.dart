import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ميزان الماء الهندسي (Spirit Level) لقياس وضبط زاوية الميل الرأسي (Elevation Tilt)
class SpiritLevel extends StatelessWidget {
  final double currentPitch;      // زاوية ميل الهاتف الحالية
  final double targetElevation;  // زاوية الميل المطلوبة للرابط
  final double verticalBeamwidth;// زاوية الحزمة الرأسية

  const SpiritLevel({
    super.key,
    required this.currentPitch,
    required this.targetElevation,
    required this.verticalBeamwidth,
  });

  @override
  Widget build(BuildContext context) {
    final double error = targetElevation - currentPitch;
    final bool isTiltAligned = error.abs() <= (verticalBeamwidth / 2.0);

    // حساب موضع الفقاعة على المقياس من -1.0 إلى +1.0
    // حيث 0.0 يعني تطابق زاوية الميل تماماً
    final double clampedError = error.clamp(-15.0, 15.0);
    final double normalizedOffset = clampedError / 15.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTiltAligned ? Colors.greenAccent : Colors.white12,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.height_rounded,
                    color: isTiltAligned ? Colors.greenAccent : Colors.amberAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'الميل الرأسي (Tilt)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                'المطلوب: ${targetElevation >= 0 ? '+' : ''}${targetElevation.toStringAsFixed(1)}°',
                style: TextStyle(
                  color: isTiltAligned ? Colors.greenAccent : Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // أنبوبة ميزان الماء التفاعلية
          LayoutBuilder(
            builder: (context, constraints) {
              final double tubeWidth = constraints.maxWidth;
              const double bubbleWidth = 44.0;
              final double maxTravel = (tubeWidth - bubbleWidth) / 2;
              final double bubbleX = maxTravel * normalizedOffset;

              return Container(
                height: 36,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // خطوط المنتصف (علامات التوجيه الصحيح)
                    Container(
                      width: 52,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.greenAccent.withOpacity(0.5), width: 1.5),
                          right: BorderSide(color: Colors.greenAccent.withOpacity(0.5), width: 1.5),
                        ),
                      ),
                    ),

                    // الفقاعة التفاعلية المتحركة
                    Transform.translate(
                      offset: Offset(bubbleX, 0),
                      child: Container(
                        width: bubbleWidth,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isTiltAligned
                                ? [Colors.greenAccent, Colors.green]
                                : [Colors.amberAccent, Colors.orange],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: (isTiltAligned ? Colors.greenAccent : Colors.amberAccent)
                                  .withOpacity(0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${currentPitch >= 0 ? '+' : ''}${currentPitch.toStringAsFixed(0)}°',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // إرشاد لفظي لحركة الرفع أو الخفض
          Text(
            isTiltAligned
                ? 'زاوية الميل الرأسي مضبوطة تماماً ✅'
                : error > 0
                    ? 'ارفع رأس الأنتينا للأعلى بمقدار ${error.abs().toStringAsFixed(1)}°'
                    : 'اخفض رأس الأنتينا للأسفل بمقدار ${error.abs().toStringAsFixed(1)}°',
            style: TextStyle(
              fontSize: 12,
              color: isTiltAligned ? Colors.greenAccent : Colors.amberAccent,
            ),
          ),
        ],
      ),
    );
  }
}
