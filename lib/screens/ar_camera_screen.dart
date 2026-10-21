import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/link_model.dart';
import '../services/geo_math.dart';

/// شاشة كاميرا الواقع المعزز (AR Alignment HUD)
/// تتيح للفني النظر من خلف الأنتينا ورؤية نقطة الهدف الافتراضية فوق الأفق
class ArCameraScreen extends StatefulWidget {
  final LinkModel link;

  const ArCameraScreen({super.key, required this.link});

  @override
  State<ArCameraScreen> createState() => _ArCameraScreenState();
}

class _ArCameraScreenState extends State<ArCameraScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() => _isCameraReady = true);
        }
      } else {
        setState(() => _cameraError = 'لم يتم العثور على كاميرا في هذا الجهاز');
      }
    } catch (e) {
      setState(() => _cameraError = 'تعذر تشغيل الكاميرا: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double horizontalErr = widget.link.horizontalErrorAngle;
    final double verticalErr = widget.link.verticalErrorAngle;
    final bool isLocked = widget.link.alignmentState == AlignmentState.locked;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // معاينة الكاميرا الحية (أو شاشة افتراضية إذا لم تتوفر الكاميرا)
          if (_isCameraReady && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            Container(
              color: const Color(0xFF0F172A),
              child: Center(
                child: Text(
                  _cameraError ?? 'جاري تشغيل كاميرا التوجيه الميداني...',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),

          // شبكة وخطوط الاستهداف الميدانية (AR Target Reticle)
          LayoutBuilder(
            builder: (context, constraints) {
              // حساب إزاحة الهدف داخل إطار الشاشة بناءً على زاوية الانحراف
              // زاوية الرؤية الأفقية للكاميرا تقريباً 60 درجة (30 يمين و 30 شمال)
              final double screenW = constraints.maxWidth;
              final double screenH = constraints.maxHeight;

              final double fovH = 60.0;
              final double fovV = 45.0;

              final double targetX = (screenW / 2) + (horizontalErr / (fovH / 2)) * (screenW / 2);
              final double targetY = (screenH / 2) - (verticalErr / (fovV / 2)) * (screenH / 2);

              final bool isTargetInScreen = targetX >= 0 &&
                  targetX <= screenW &&
                  targetY >= 0 &&
                  targetY <= screenH;

              return Stack(
                children: [
                  // خط الأفق الافتراضي ومؤشر منتصف العدسة
                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isLocked ? Colors.greenAccent : Colors.white38,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isLocked ? Colors.greenAccent : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // علامة الاستهداف الافتراضية فوق الهدف البعيد
                  if (isTargetInScreen)
                    Positioned(
                      left: targetX - 32,
                      top: targetY - 32,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isLocked ? Colors.greenAccent : Colors.cyanAccent,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isLocked ? Colors.greenAccent : Colors.cyanAccent)
                                      .withOpacity(0.5),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.settings_input_antenna,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${widget.link.remotePoint?.deviceName ?? "الهدف"} (${GeoMath.formatDistance(widget.link.distanceMeters)})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // أسهم توجيه إذا كان الهدف خارج كادر الشاشة حالياً
                    Align(
                      alignment: horizontalErr > 0 ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amberAccent),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              horizontalErr > 0 ? Icons.arrow_forward : Icons.arrow_back,
                              color: Colors.amberAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'در ${horizontalErr.abs().toStringAsFixed(0)}°',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // الشريط العلوي وأزرار التحكم
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLocked ? Colors.greenAccent : Colors.cyanAccent,
                    ),
                  ),
                  child: Text(
                    isLocked
                        ? 'محاذاة كاملة ✅'
                        : 'انحراف: ${horizontalErr.abs().toStringAsFixed(1)}°',
                    style: TextStyle(
                      color: isLocked ? Colors.greenAccent : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
