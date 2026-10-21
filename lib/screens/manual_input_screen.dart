import 'package:flutter/material.dart';
import '../models/geo_point.dart';
import 'compass_alignment_screen.dart';

/// شاشة إدخال إحداثيات الطرف الآخر يدوياً (وضع الأماكن المنعزلة بدون إنترنت)
class ManualInputScreen extends StatefulWidget {
  final GeoPoint localPoint;

  const ManualInputScreen({super.key, required this.localPoint});

  @override
  State<ManualInputScreen> createState() => _ManualInputScreenState();
}

class _ManualInputScreenState extends State<ManualInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'البرج البعيد');
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _altController = TextEditingController(text: '0');
  final _pasteBoxController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _altController.dispose();
    _pasteBoxController.dispose();
    super.dispose();
  }

  /// استخراج الإحداثيات تلقائياً إذا قام المستخدم بلصق نص من خرائط جوجل
  void _parseGoogleMapsString(String text) {
    final regex = RegExp(r'(-?\d+\.\d+)[,\s]+(-?\d+\.\d+)');
    final match = regex.firstMatch(text);
    if (match != null) {
      setState(() {
        _latController.text = match.group(1)!;
        _lonController.text = match.group(2)!;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم استخراج خطوط الطول والعرض بنجاح!')),
      );
    }
  }

  void _startAlignment() {
    if (_formKey.currentState!.validate()) {
      final remotePoint = GeoPoint(
        latitude: double.parse(_latController.text.trim()),
        longitude: double.parse(_lonController.text.trim()),
        altitude: double.tryParse(_altController.text.trim()) ?? 0.0,
        deviceName: _nameController.text.trim(),
        timestamp: DateTime.now(),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CompassAlignmentScreen(
            title: 'توجيه يدوي: ${remotePoint.deviceName}',
            initialLocalPoint: widget.localPoint,
            initialRemotePoint: remotePoint,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('إدخال إحداثيات الطرف البعيد'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // مربع اللصق السريع من خرائط جوجل أو رسائل الواتساب
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.content_paste_go, color: Colors.cyanAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'لصق سريع من خرائط جوجل أو رسالة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _pasteBoxController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'الصق الرابط أو النص مثل: 30.0444, 31.2357',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check, color: Colors.cyanAccent),
                          onPressed: () => _parseGoogleMapsString(_pasteBoxController.text),
                        ),
                      ),
                      onChanged: _parseGoogleMapsString,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // حقول الإدخال اليدوية
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'اسم الموقع / البرج البعيد',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.edit_location_alt, color: Colors.cyanAccent),
                ),
                validator: (val) => val == null || val.isEmpty ? 'يرجى كتابة اسم' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _latController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'خط العرض (Latitude) مثل: 30.044420',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.map, color: Colors.cyanAccent),
                ),
                validator: (val) {
                  final n = double.tryParse(val ?? '');
                  if (n == null || n < -90 || n > 90) return 'يرجى إدخال خط عرض صحيح (-90 إلى 90)';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _lonController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'خط الطول (Longitude) مثل: 31.235712',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.explore, color: Colors.cyanAccent),
                ),
                validator: (val) {
                  final n = double.tryParse(val ?? '');
                  if (n == null || n < -180 || n > 180) return 'يرجى إدخال خط طول صحيح (-180 إلى 180)';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _altController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'الارتفاع بالمتر فوق سطح البحر (اختياري)',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.height, color: Colors.cyanAccent),
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.navigation, size: 22),
                label: const Text(
                  'بدء التوجيه الآن بالبوصلة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _startAlignment,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
