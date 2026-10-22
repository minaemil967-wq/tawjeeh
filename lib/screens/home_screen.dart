import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/geo_point.dart';
import '../services/sensor_service.dart';
import '../services/sync_service.dart';
import 'compass_alignment_screen.dart';
import 'manual_input_screen.dart';
import 'tools_screen.dart';

/// الشاشة الترحيبية واختيار طريقة التوجيه
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SensorService _sensorService = SensorService();
  final SyncService _syncService = SyncService();

  String _myDeviceName = 'محطة فنية';
  GeoPoint? _localPoint;
  double _currentHeading = 0.0;
  bool _isLoadingGps = true;

  @override
  void initState() {
    super.initState();
    _initSensors();
  }

  Future<void> _initSensors() async {
    final success = await _sensorService.initSensors();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى منح إذن الموقع GPS ليعمل البرنامج بدقة')),
      );
    }

    _sensorService.localPointStream.listen((point) {
      if (mounted) {
        setState(() {
          _localPoint = point;
          _isLoadingGps = false;
        });
      }
    });

    _sensorService.headingStream.listen((heading) {
      if (mounted) {
        setState(() => _currentHeading = heading);
      }
    });
  }

  /// إنشاء كود غرفة عشوائي ومباشرة الجلسة
  void _createLiveRoom() async {
    if (_localPoint == null) {
      _showGpsWaitDialog();
      return;
    }

    final randomCode = (1000 + math.Random().nextInt(9000)).toString();

    // إظهار مؤشر تحميل والاتصال بالوسيط
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      ),
    );

    await _syncService.joinRoom(roomCode: randomCode, deviceName: 'المحطة A');

    if (mounted) {
      Navigator.pop(context); // إغلاق التحميل
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CompassAlignmentScreen(
            title: 'جلسة حية: $randomCode',
            initialLocalPoint: _localPoint!,
            roomCode: randomCode,
          ),
        ),
      );
    }
  }

  /// الانضمام لغرفة قائمة بكود مرسل من الفني الآخر
  void _joinLiveRoomDialog() {
    if (_localPoint == null) {
      _showGpsWaitDialog();
      return;
    }

    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('الانضمام لغرفة الفني الآخر', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اكتب كود الجلسة (4 أرقام) الظاهر على شاشة هاتف الفني الآخر المقابل لك:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              autofocus: true,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
              decoration: InputDecoration(
                hintText: 'مثال: 5421',
                hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 1),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(context);

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  ),
                );

                await _syncService.joinRoom(roomCode: code, deviceName: 'المحطة B');

                if (mounted) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CompassAlignmentScreen(
                        title: 'جلسة حية: $code',
                        initialLocalPoint: _localPoint!,
                        roomCode: code,
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('انضم وبدء التوجيه'),
          ),
        ],
      ),
    );
  }

  void _showGpsWaitDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري التقاط إحداثيات الـ GPS بدقة، انتظر ثوانٍ...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.radar, color: Colors.cyanAccent),
            SizedBox(width: 10),
            Text('توجيه برو | محاذاة هوائيات الشبكات', style: TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.handyman_outlined, color: Colors.cyanAccent),
            tooltip: 'حقيبة أدوات الفني 🧰',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ToolsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة حالة الـ GPS والبوصلة المباشرة
            _buildDeviceStatusCard(),
            const SizedBox(height: 24),

            const Text(
              'اختر طريقة التوجيه:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),

            // خيار 1: إنشاء غرفة ربط حية (Live Room)
            _buildOptionCard(
              title: 'إنشاء غرفة ربط حية (Live Room)',
              subtitle: 'يقف كل فني بجوار قطعته، وتتم مزامنة الزوايا وتوجيه القطعتين لبعضهما لحظة بلحظة عبر النت',
              icon: Icons.wifi_tethering,
              color: Colors.cyanAccent,
              onTap: _createLiveRoom,
            ),
            const SizedBox(height: 14),

            // خيار 2: الانضمام لغرفة قائمة
            _buildOptionCard(
              title: 'الانضمام لغرفة قائمة بكود',
              subtitle: 'أدخل الكود الظاهر على شاشة الفني الآخر على البرج المقابل لبدء التوجيه المزدوج فوراً',
              icon: Icons.group_add,
              color: Colors.greenAccent,
              onTap: _joinLiveRoomDialog,
            ),
            const SizedBox(height: 14),

            // خيار 3: إدخال الإحداثيات يدوياً (وضع الأوفلاين)
            _buildOptionCard(
              title: 'توجيه يدوي / أوفلاين (بدون إنترنت)',
              subtitle: 'للمناطق النائية: كتابة إحداثيات البرج الآخر يدوياً أو لصقها من رسالة SMS أو خرائط جوجل',
              icon: Icons.edit_location_alt,
              color: Colors.amberAccent,
              onTap: () {
                if (_localPoint == null) {
                  _showGpsWaitDialog();
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManualInputScreen(localPoint: _localPoint!),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // خيار 4: حقيبة أدوات الفني الميدانية
            _buildOptionCard(
              title: 'حقيبة أدوات الفني الميدانية 🧰',
              subtitle: 'حاسبة الإشارة المتوقعة (dBm)، ارتفاع الصاري وفرينل، فحص توازن القطبين، والطاقة الشمسية، وتقرير الاستلام',
              icon: Icons.handyman,
              color: Colors.purpleAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ToolsScreen(
                      initialDistanceMeters: 1500,
                      localName: _myDeviceName,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // نصيحة معايرة البوصلة
            _buildCalibrationTip(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'حالة الحساسات في هاتفك',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isLoadingGps ? Colors.amber.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isLoadingGps ? 'جاري تثبيت GPS 🛰️' : 'GPS جاهز بدقة ممتازة ✅',
                  style: TextStyle(
                    color: _isLoadingGps ? Colors.amberAccent : Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_localPoint != null) ...[
            Text(
              'خط العرض: ${_localPoint!.latitude.toStringAsFixed(6)} | خط الطول: ${_localPoint!.longitude.toStringAsFixed(6)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'الارتفاع: ${_localPoint!.altitude.toStringAsFixed(1)} متر | دقة التحديد: ± ${_localPoint!.accuracy.toStringAsFixed(1)} متر',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ] else ...[
            const Text(
              'تأكد من فتح خدمة الموقع (Location / GPS) والوقوف في مكان مفتوح نحو السماء',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationTip() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.amberAccent, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'نصيحة ميدانية: قرب الأبراج الحديدية والهياكل المعدنية قد يحدث تشويش على بوصلة الهاتف المغناطيسية؛ حرّك الهاتف في الهواء على شكل رقم 8 لمعايرة الحساس قبل التثبيت النهائي للأنتينا.',
              style: TextStyle(color: Colors.amberAccent, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
