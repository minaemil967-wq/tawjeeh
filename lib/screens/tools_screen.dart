import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/geo_math.dart';
import '../models/antenna_model.dart';

/// شاشة حقيبة أدوات الفني الميدانية (Technician RF Toolkit)
class ToolsScreen extends StatefulWidget {
  final double initialDistanceMeters;
  final double initialAzimuth;
  final double initialTilt;
  final String localName;
  final String remoteName;
  final AntennaModel? initialAntenna;

  const ToolsScreen({
    super.key,
    this.initialDistanceMeters = 1500,
    this.initialAzimuth = 135.0,
    this.initialTilt = 1.5,
    this.localName = 'محطة A',
    this.remoteName = 'محطة B',
    this.initialAntenna,
  });

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 1. Link Budget State
  late TextEditingController _distController;
  late TextEditingController _freqController;
  late TextEditingController _txPowerController;
  late TextEditingController _antennaGainController;
  late TextEditingController _actualSignalController;
  AntennaModel _budgetAntenna = AntennaModel.presets[2]; // LiteBeam default

  // 2. Fresnel & Mast Height State
  late TextEditingController _obstacleController;

  // 3. Chain Imbalance State
  final _chain0Controller = TextEditingController(text: '-58');
  final _chain1Controller = TextEditingController(text: '-60');

  // 4. Solar Calculator State
  int _locoCount = 1;
  int _litebeamCount = 1;
  int _powerbeamCount = 0;
  int _switchCount = 1;
  double _autonomyHours = 24.0;

  // 5. Survey Report State
  final _techNameController = TextEditingController(text: 'مهندس / فني الشبكة');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    final dist = widget.initialDistanceMeters > 0 ? widget.initialDistanceMeters : 1500.0;
    _distController = TextEditingController(text: (dist / 1000.0).toStringAsFixed(2));
    _freqController = TextEditingController(text: '5.8');
    _txPowerController = TextEditingController(text: '23');
    _antennaGainController = TextEditingController(
      text: (widget.initialAntenna?.gainDbi ?? 23.0).toStringAsFixed(0),
    );
    _actualSignalController = TextEditingController(text: '');
    _obstacleController = TextEditingController(text: '0');

    if (widget.initialAntenna != null) {
      _budgetAntenna = widget.initialAntenna!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _distController.dispose();
    _freqController.dispose();
    _txPowerController.dispose();
    _antennaGainController.dispose();
    _actualSignalController.dispose();
    _obstacleController.dispose();
    _chain0Controller.dispose();
    _chain1Controller.dispose();
    _techNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('حقيبة أدوات الفني الميدانية 🧰', style: TextStyle(fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.cyanAccent,
          tabs: const [
            Tab(icon: Icon(Icons.calculate), text: 'الإشارة المتوقعة'),
            Tab(icon: Icon(Icons.height), text: 'ارتفاع الماسورة'),
            Tab(icon: Icon(Icons.compare_arrows), text: 'توازن القطبين'),
            Tab(icon: Icon(Icons.wb_sunny), text: 'الطاقة الشمسية'),
            Tab(icon: Icon(Icons.description), text: 'تقرير الاستلام'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLinkBudgetTab(),
          _buildMastHeightTab(),
          _buildChainImbalanceTab(),
          _buildSolarCalculatorTab(),
          _buildSurveyReportTab(),
        ],
      ),
    );
  }

  // --- TAB 1: LINK BUDGET & EXPECTED RSSI ---
  Widget _buildLinkBudgetTab() {
    final double distKm = double.tryParse(_distController.text) ?? 1.5;
    final double distMeters = distKm * 1000.0;
    final double freqGhz = double.tryParse(_freqController.text) ?? 5.8;
    final double txPower = double.tryParse(_txPowerController.text) ?? 23.0;
    final double gain = double.tryParse(_antennaGainController.text) ?? 23.0;
    final double? actualSignal = double.tryParse(_actualSignalController.text);

    final double expectedRssi = GeoMath.calculateExpectedRssi(
      distanceMeters: distMeters,
      frequencyGhz: freqGhz,
      txPowerDbm: txPower,
      txGainDbi: gain,
      rxGainDbi: gain,
    );

    final double fspl = GeoMath.calculateFspl(distanceMeters: distMeters, frequencyGhz: freqGhz);
    final eval = GeoMath.evaluateSignalQuality(expectedRssi);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // بطاقة النتيجة البارزة
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              children: [
                const Text('قوة الإشارة المتوقعة نظرياً (Expected RSSI)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  '${expectedRssi.toStringAsFixed(0)} dBm',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 36, fontWeight: FontWeight.bold),
                ),
                Text(eval['quality']!, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(eval['speed']!, style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                const Divider(color: Colors.white12, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('فقد الفضاء (FSPL): ${fspl.toStringAsFixed(1)} dB', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    Text('المسافة: ${distKm.toStringAsFixed(2)} كم', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // مقارنة مع الإشارة الفعلية المحققة على الجهاز
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('قارن مع القراءة الحالية على airOS / MikroTik:', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _actualSignalController,
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'اكتب الإشارة الحالية مثل: -65',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (actualSignal != null) ...[
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final diff = (actualSignal - expectedRssi).abs();
                    if (diff <= 3) {
                      return Text('ممتاز! الإشارة المحققة مطابقة للحسابات تماماً (فارق $diff dB) ✅', style: const TextStyle(color: Colors.greenAccent, fontSize: 12));
                    } else if (diff <= 7) {
                      return Text('فارق $diff dB عن المثالي ⚠️ يلزم ضبط خفيف للتوجيه للوصول للفص الرئيسي.', style: const TextStyle(color: Colors.amberAccent, fontSize: 12));
                    } else {
                      return Text('فارق كبير ($diff dB) ❌ أنت متصل على فص جانبي (Side Lobe) أو يوجد عائق يقطع مسار الإشارة!', style: const TextStyle(color: Colors.redAccent, fontSize: 12));
                    }
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // حقول الإدخال
          _buildInputRow('المسافة (كم):', _distController),
          _buildInputRow('التردد (GHz):', _freqController),
          _buildInputRow('قوة البث (Tx Power dBm):', _txPowerController),
          _buildInputRow('كسب الهوائي (Antenna Gain dBi):', _antennaGainController),
        ],
      ),
    );
  }

  // --- TAB 2: MAST HEIGHT & FRESNEL CLEARANCE ---
  Widget _buildMastHeightTab() {
    final double distKm = double.tryParse(_distController.text) ?? 1.5;
    final double distMeters = distKm * 1000.0;
    final double freqGhz = double.tryParse(_freqController.text) ?? 5.8;
    final double obstacleH = double.tryParse(_obstacleController.text) ?? 0.0;

    final double fresnelMax = GeoMath.calculateFresnelZoneMaxRadius(distanceMeters: distMeters, frequencyGhz: freqGhz);
    final double minMastHeight = GeoMath.calculateMinMastHeight(
      distanceMeters: distMeters,
      frequencyGhz: freqGhz,
      obstacleHeightMeters: obstacleH,
    );

    // سهم انحناء الأرض في المنتصف
    final double earthBulge = (distMeters * distMeters) / (8.0 * GeoMath.earthRadiusMeters);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              children: [
                const Text('الحد الأدنى الموصى به لارتفاع الصاري (الماسورة)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  '${minMastHeight.toStringAsFixed(1)} متر',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const Text('فوق أعلى نقطة في السطح لضمان خلو مسار الإشارة', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const Divider(color: Colors.white12, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('نصف قطر فرينل 100%: ${fresnelMax.toStringAsFixed(1)}م', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    Text('انحناء كروية الأرض: ${earthBulge.toStringAsFixed(2)}م', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildInputRow('المسافة بين الطرفين (كم):', _distController),
          _buildInputRow('تردد الإشارة (GHz):', _freqController),
          _buildInputRow('ارتفاع عائق وسيط متوقع (أشجار/مباني بالمتر):', _obstacleController),

          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amberAccent, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'قاعدة ذهبية: يجب أن يظل ما لا يقل عن 60% من نصف قطر منطقة فرينل الأولى خالياً تماماً من أي عوائق حتى لا تتشتت حزمة البيانات.',
                    style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: DUAL POLARITY / CHAIN IMBALANCE ---
  Widget _buildChainImbalanceTab() {
    final double c0 = double.tryParse(_chain0Controller.text) ?? -58.0;
    final double c1 = double.tryParse(_chain1Controller.text) ?? -60.0;
    final result = GeoMath.evaluateChainImbalance(chain0Dbm: c0, chain1Dbm: c1);

    Color resColor = Colors.greenAccent;
    if (result['color'] == 'amber') resColor = Colors.amberAccent;
    if (result['color'] == 'red') resColor = Colors.redAccent;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: resColor, width: 2),
            ),
            child: Column(
              children: [
                Text('فارق الاستقطاب: ${result['delta'].toStringAsFixed(1)} dB', style: TextStyle(color: resColor, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(result['status'], style: TextStyle(color: resColor, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  result['advice'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildInputRow('قراءة القناة الأولى Vertical (Chain 0 dBm):', _chain0Controller),
          _buildInputRow('قراءة القناة الثانية Horizontal (Chain 1 dBm):', _chain1Controller),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('كيف تعالج عدم توازن القنوات ميدانياً؟', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(height: 6),
                Text(
                  '1. تدوير خفيف للأنتينا حول محورها (Skew / Rotation).\n2. التأكد من أن الأنتينا مستوية رأسياً وأفقياً بنسبة 90 درجة.\n3. التأكد من عدم وجود أسلاك حديدية أو ماسورة مجاورة تكسر الموجة الأفقية أو الرأسية.',
                  style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 4: SOLAR & BATTERY CALCULATOR ---
  Widget _buildSolarCalculatorTab() {
    final double totalWatts = (_locoCount * 7.0) +
        (_litebeamCount * 7.0) +
        (_powerbeamCount * 8.5) +
        (_switchCount * 5.0);

    final solar = GeoMath.calculateSolarSystem(
      totalWatts: totalWatts,
      autonomyHours: _autonomyHours,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // كارت النتائج
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.5), width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إجمالي استهلاك النقطة:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('${totalWatts.toStringAsFixed(1)} واط', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const Divider(color: Colors.white12, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _solarStat('لوح الطاقة الشمسية', '${solar['panelWatts']} واط', Icons.solar_power),
                    _solarStat('بطارية 12V Gel', '${solar['batteryAh']} Ah', Icons.battery_charging_full),
                    _solarStat('منظم الشحن', '${solar['controllerAmps']} أمبير', Icons.speed),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text('الأجهزة المركبة في الموقع النائي:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),

          _counterTile('NanoStation Loco / M5 (7W)', _locoCount, (c) => setState(() => _locoCount = c)),
          _counterTile('LiteBeam 5AC Gen2 (7W)', _litebeamCount, (c) => setState(() => _litebeamCount = c)),
          _counterTile('PowerBeam / IsoStation (8.5W)', _powerbeamCount, (c) => setState(() => _powerbeamCount = c)),
          _counterTile('PoE Switch / ToughSwitch (5W)', _switchCount, (c) => setState(() => _switchCount = c)),

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('مدة التشغيل الاحتياطية بدون شمس:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              DropdownButton<double>(
                value: _autonomyHours,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: 24.0, child: Text('24 ساعة (يوم كامل)')),
                  DropdownMenuItem(value: 48.0, child: Text('48 ساعة (يومان)')),
                  DropdownMenuItem(value: 72.0, child: Text('72 ساعة (3 أيام)')),
                ],
                onChanged: (v) => setState(() => _autonomyHours = v!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _solarStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.amberAccent, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _counterTile(String label, int value, ValueChanged<int> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.white54, size: 20),
                onPressed: value > 0 ? () => onChanged(value - 1) : null,
              ),
              Text('$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent, size: 20),
                onPressed: () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 5: SURVEY REPORT GENERATOR ---
  Widget _buildSurveyReportTab() {
    final double distKm = double.tryParse(_distController.text) ?? 1.5;
    final double distMeters = distKm * 1000.0;
    final double expectedRssi = GeoMath.calculateExpectedRssi(
      distanceMeters: distMeters,
      txGainDbi: double.tryParse(_antennaGainController.text) ?? 23.0,
      rxGainDbi: double.tryParse(_antennaGainController.text) ?? 23.0,
    );

    final reportText = GeoMath.generateSurveyReportText(
      localSiteName: widget.localName,
      remoteSiteName: widget.remoteName,
      distanceMeters: distMeters,
      azimuthDegrees: widget.initialAzimuth,
      tiltDegrees: widget.initialTilt,
      antennaName: _budgetAntenna.name,
      expectedRssi: expectedRssi,
      actualRssi: double.tryParse(_actualSignalController.text),
      chain0: double.tryParse(_chain0Controller.text),
      chain1: double.tryParse(_chain1Controller.text),
      technicianName: _techNameController.text.trim(),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _techNameController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'اسم الفني المسؤول عن التركيب:',
              labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyan.withOpacity(0.4)),
            ),
            child: Text(
              reportText,
              style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.5, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.share),
            label: const Text('مشاركة التقرير عبر WhatsApp / الحافظة', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: reportText));
              Share.share(reportText, subject: 'تقرير توثيق رابط لاسلكي');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          SizedBox(
            width: 100,
            height: 38,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}
