import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/geo_point.dart';
import '../models/antenna_model.dart';
import '../models/link_model.dart';
import '../services/geo_math.dart';
import '../services/sync_service.dart';
import '../services/sensor_service.dart';
import '../widgets/compass_dial.dart';
import '../widgets/spirit_level.dart';
import 'ar_camera_screen.dart';
import 'tools_screen.dart';

/// الشاشة الميدانية الرئيسية مع دعم تعدد الأجهزة واختيار الهدف
class CompassAlignmentScreen extends StatefulWidget {
  final String title;
  final GeoPoint initialLocalPoint;
  final GeoPoint? initialRemotePoint;
  final String? roomCode;

  const CompassAlignmentScreen({
    super.key,
    required this.title,
    required this.initialLocalPoint,
    this.initialRemotePoint,
    this.roomCode,
  });

  @override
  State<CompassAlignmentScreen> createState() => _CompassAlignmentScreenState();
}

class _CompassAlignmentScreenState extends State<CompassAlignmentScreen> {
  late GeoPoint _localPoint;
  GeoPoint? _remotePoint;
  List<GeoPoint> _connectedPeers = [];
  AntennaModel _selectedAntenna = AntennaModel.presets[0];

  double _currentHeading = 0.0;
  double _currentPitch = 0.0;
  bool _soundAndHapticEnabled = true;

  final SensorService _sensorService = SensorService();
  final SyncService _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    _localPoint = widget.initialLocalPoint;
    _remotePoint = widget.initialRemotePoint;

    // الاستماع لقراءات الموقع والبوصلة
    _sensorService.localPointStream.listen((point) {
      if (mounted) {
        setState(() => _localPoint = point);
        if (widget.roomCode != null) {
          _syncService.publishMyLocation(point);
        }
      }
    });

    _sensorService.headingStream.listen((heading) {
      if (mounted) {
        setState(() => _currentHeading = heading);
        _checkAlignmentFeedback();
      }
    });

    _sensorService.pitchStream.listen((pitch) {
      if (mounted) {
        setState(() => _currentPitch = pitch);
      }
    });

    // الاستماع لقائمة الأجهزة المتصلة وتحديد الهدف النشط
    if (widget.roomCode != null) {
      _syncService.peersStream.listen((peers) {
        if (mounted) {
          setState(() => _connectedPeers = peers);
        }
      });

      _syncService.selectedPeerStream.listen((peer) {
        if (mounted) {
          setState(() => _remotePoint = peer);
        }
      });
    }
  }

  void _checkAlignmentFeedback() {
    if (_remotePoint == null || !_soundAndHapticEnabled) return;

    final targetBearing = GeoMath.calculateBearing(
      lat1: _localPoint.latitude,
      lon1: _localPoint.longitude,
      lat2: _remotePoint!.latitude,
      lon2: _remotePoint!.longitude,
    );

    final error = GeoMath.calculateHeadingDifference(
      currentHeadingDegrees: _currentHeading,
      targetBearingDegrees: targetBearing,
    );

    _sensorService.triggerAlignmentHaptic(error);
  }

  /// نافذة اختيار وتغيير الجهاز المستهدف من بين الأجهزة المتصلة في الغرفة
  void _showPeersPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الأجهزة المتصلة بالغرفة (${_connectedPeers.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'كود: ${widget.roomCode}',
                      style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              if (_connectedPeers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'لا يوجد أجهزة أخرى متصلة حالياً..\nقم بفتح التطبيق على هاتف ثانٍ أو ثالث وأدخل نفس كود الغرفة',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, height: 1.4),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _connectedPeers.length,
                    itemBuilder: (context, index) {
                      final peer = _connectedPeers[index];
                      final isCurrentTarget = peer.deviceId == _remotePoint?.deviceId;

                      final dist = GeoMath.calculateDistanceMeters(
                        lat1: _localPoint.latitude,
                        lon1: _localPoint.longitude,
                        lat2: peer.latitude,
                        lon2: peer.longitude,
                      );

                      final bearing = GeoMath.calculateBearing(
                        lat1: _localPoint.latitude,
                        lon1: _localPoint.longitude,
                        lat2: peer.latitude,
                        lon2: peer.longitude,
                      );

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCurrentTarget
                              ? Colors.greenAccent.withOpacity(0.2)
                              : Colors.white10,
                          child: Icon(
                            Icons.phone_android,
                            color: isCurrentTarget ? Colors.greenAccent : Colors.white70,
                          ),
                        ),
                        title: Text(
                          peer.deviceName.isNotEmpty ? peer.deviceName : 'هاتف ${index + 1}',
                          style: TextStyle(
                            color: isCurrentTarget ? Colors.greenAccent : Colors.white,
                            fontWeight: isCurrentTarget ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          'المسافة: ${GeoMath.formatDistance(dist)} | الزاوية: ${bearing.toStringAsFixed(0)}° (${GeoMath.formatCardinalDirection(bearing)})',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        trailing: isCurrentTarget
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('الهدف الحالي ✅', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.cyanAccent,
                              ),
                              onPressed: () {
                                _syncService.selectPeer(peer.deviceId);
                                Navigator.pop(context);
                              },
                              child: const Text('توجيه نحوه'),
                            ),
                        onTap: () {
                          _syncService.selectPeer(peer.deviceId);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAntennaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'اختر موديل الهوائي (الأنتينا)',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: AntennaModel.presets.length,
                  itemBuilder: (context, index) {
                    final item = AntennaModel.presets[index];
                    final isSelected = item.id == _selectedAntenna.id;

                    return ListTile(
                      leading: Icon(
                        Icons.settings_input_antenna,
                        color: isSelected ? Colors.greenAccent : Colors.white60,
                      ),
                      title: Text(
                        item.name,
                        style: TextStyle(
                          color: isSelected ? Colors.greenAccent : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        'زاوية الشعاع: ${item.horizontalBeamwidth}° | الكسب: ${item.gainDbi} dBi',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                          : null,
                      onTap: () {
                        setState(() => _selectedAntenna = item);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final link = LinkModel(
      localPoint: _localPoint,
      remotePoint: _remotePoint,
      antenna: _selectedAntenna,
      currentCompassHeading: _currentHeading,
      currentDevicePitch: _currentPitch,
    );

    final bool isLocked = link.alignmentState == AlignmentState.locked;
    final bool isApproaching = link.alignmentState == AlignmentState.approaching;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 15)),
            if (widget.roomCode != null)
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _connectedPeers.isNotEmpty ? Colors.greenAccent : Colors.amberAccent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'كود: ${widget.roomCode} | ${_connectedPeers.length} أجهزة متصلة',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          // زر استعراض الأجهزة المتصلة والتبديل بينها
          if (widget.roomCode != null)
            IconButton(
              icon: Stack(
                alignment: Alignment.topRight,
                children: [
                  const Icon(Icons.devices, color: Colors.cyanAccent),
                  if (_connectedPeers.isNotEmpty)
                    CircleAvatar(
                      radius: 7,
                      backgroundColor: Colors.green,
                      child: Text(
                        '${_connectedPeers.length}',
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              tooltip: 'قائمة الأجهزة المتصلة',
              onPressed: _showPeersPicker,
            ),
          IconButton(
            icon: const Icon(Icons.handyman_outlined, color: Colors.cyanAccent),
            tooltip: 'حقيبة أدوات الفني 🧰',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ToolsScreen(
                    initialDistanceMeters: link.distanceMeters,
                    initialAzimuth: link.targetBearing,
                    initialTilt: link.targetElevationAngle,
                    localName: _localPoint.deviceName,
                    remoteName: _remotePoint?.deviceName ?? 'الطرف المقابل',
                    initialAntenna: _selectedAntenna,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              _soundAndHapticEnabled ? Icons.vibration : Icons.notifications_off_outlined,
              color: _soundAndHapticEnabled ? Colors.greenAccent : Colors.white54,
            ),
            tooltip: 'تفعيل/كتم الاهتزاز',
            onPressed: () {
              setState(() => _soundAndHapticEnabled = !_soundAndHapticEnabled);
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'وضع كاميرا الواقع المعزز (AR)',
            onPressed: () {
              if (_remotePoint == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('في انتظار اتصال جهاز آخر أولاً')),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArCameraScreen(link: link),
                ),
              );
            },
          ),
        ],
      ),
      body: _remotePoint == null
          ? _buildWaitingForPeersState()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // شريط اختيار الهدف الحالي عند وجود أكثر من هاتف
                  if (widget.roomCode != null && _connectedPeers.length > 1)
                    _buildMultiDeviceSwitcherBar(),

                  // شريط التوجيه اللفظي العريض
                  _buildGuidanceBanner(link, isLocked, isApproaching),
                  const SizedBox(height: 16),

                  // قرص البوصلة الهندسي الدوار
                  SizedBox(
                    height: 270,
                    child: CompassDial(
                      currentHeading: _currentHeading,
                      targetBearing: link.targetBearing,
                      horizontalBeamwidth: _selectedAntenna.horizontalBeamwidth,
                      isLocked: isLocked,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ميزان ضبط الميل الرأسي للأنتينا
                  SpiritLevel(
                    currentPitch: _currentPitch,
                    targetElevation: link.targetElevationAngle,
                    verticalBeamwidth: _selectedAntenna.verticalBeamwidth,
                  ),
                  const SizedBox(height: 16),

                  // بطاقة معلومات الرابط الجيوديسية
                  _buildLinkMetricsCard(link),
                  const SizedBox(height: 16),

                  // زر اختيار نوع الأنتينا
                  InkWell(
                    onTap: _showAntennaPicker,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.tune, color: Colors.cyanAccent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'الهوائي: ${_selectedAntenna.name}',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ],
                          ),
                          Text(
                            'فتحة: ${_selectedAntenna.horizontalBeamwidth}°',
                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMultiDeviceSwitcherBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes, color: Colors.cyanAccent, size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الهدف الموجه نحوه:', style: TextStyle(color: Colors.white54, fontSize: 10)),
                  Text(
                    _remotePoint?.deviceName ?? 'جهاز بعيد',
                    style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.swap_horiz, size: 16, color: Colors.cyanAccent),
            label: Text('تبديل (${_connectedPeers.length})', style: const TextStyle(fontSize: 11)),
            onPressed: _showPeersPicker,
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForPeersState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.cyanAccent),
            const SizedBox(height: 24),
            Text(
              'كود الغرفة: ${widget.roomCode ?? "---"}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'التطبيق يدعم هاتفين أو أكثر!\nقم بتثبيت التطبيق على الهواتف الأخرى وافتح نفس كود الغرفة لتظهر الأجهزة هنا تلقائياً وتختار التوجيه نحو أي هاتف منها.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: const Icon(Icons.share, size: 18),
              label: const Text('مشاركة كود الغرفة'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.roomCode ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ كود الغرفة إلى الحافظة')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceBanner(LinkModel link, bool isLocked, bool isApproaching) {
    final double err = link.horizontalErrorAngle;
    final Color bgColor = isLocked
        ? Colors.green.shade900.withOpacity(0.8)
        : isApproaching
            ? Colors.amber.shade900.withOpacity(0.8)
            : Colors.blueGrey.shade900.withOpacity(0.8);

    final Color borderColor = isLocked
        ? Colors.greenAccent
        : isApproaching
            ? Colors.amberAccent
            : Colors.white24;

    String instructionText;
    IconData icon;

    if (isLocked) {
      instructionText = 'أنت في مواجهة القطعة تماماً! ثبت الأنتينا ✅';
      icon = Icons.check_circle;
    } else if (err > 0) {
      instructionText = 'انعطف يميناً بمقدار ${err.abs().toStringAsFixed(1)}° ➡️';
      icon = Icons.arrow_forward;
    } else {
      instructionText = '⬅️ انعطف يساراً بمقدار ${err.abs().toStringAsFixed(1)}°';
      icon = Icons.arrow_back;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: borderColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instructionText,
                  style: TextStyle(
                    color: borderColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_remotePoint != null)
                  Text(
                    'الهدف: ${_remotePoint!.deviceName}',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkMetricsCard(LinkModel link) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricItem(
                label: 'المسافة المباشرة',
                value: GeoMath.formatDistance(link.distanceMeters),
                icon: Icons.straighten,
              ),
              _metricItem(
                label: 'زاوية السمت (Azimuth)',
                value: '${link.targetBearing.toStringAsFixed(1)}°',
                subValue: GeoMath.formatCardinalDirection(link.targetBearing),
                icon: Icons.explore,
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricItem(
                label: 'منطقة فرينل (Fresnel)',
                value: '${link.fresnelRadius.toStringAsFixed(1)} متر',
                subValue: 'نصف القطر المطلوب لخلو المسار',
                icon: Icons.radar,
              ),
              _metricItem(
                label: 'دقة الـ GPS لديك',
                value: '± ${_localPoint.accuracy.toStringAsFixed(1)} متر',
                subValue: 'ارتفاعك: ${_localPoint.altitude.toStringAsFixed(0)}م',
                icon: Icons.gps_fixed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricItem({
    required String label,
    required String value,
    String? subValue,
    required IconData icon,
  }) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.cyanAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subValue != null)
                  Text(
                    subValue,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
