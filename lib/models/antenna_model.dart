/// نموذج هوائي الشبكة (أنتينا) مع زاوية فتحة الإشارة (Beamwidth)
class AntennaModel {
  final String id;
  final String name;
  final String brand;
  final double horizontalBeamwidth; // زاوية الشعاع الأفقية بالدرجات
  final double verticalBeamwidth;   // زاوية الشعاع الرأسية بالدرجات
  final double gainDbi;             // كسب الهوائي بالـ dBi

  const AntennaModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.horizontalBeamwidth,
    required this.verticalBeamwidth,
    required this.gainDbi,
  });

  /// أشهر أجهزة وهوائيات الربط في السوق العربي والعالمي
  static const List<AntennaModel> presets = [
    AntennaModel(
      id: 'loco5ac',
      name: 'NanoStation Loco 5AC / M5',
      brand: 'Ubiquiti',
      horizontalBeamwidth: 45.0,
      verticalBeamwidth: 45.0,
      gainDbi: 13.0,
    ),
    AntennaModel(
      id: 'ns5ac',
      name: 'NanoStation 5AC / M5',
      brand: 'Ubiquiti',
      horizontalBeamwidth: 45.0,
      verticalBeamwidth: 45.0,
      gainDbi: 16.0,
    ),
    AntennaModel(
      id: 'lbe5ac',
      name: 'LiteBeam 5AC Gen2',
      brand: 'Ubiquiti',
      horizontalBeamwidth: 10.0,
      verticalBeamwidth: 10.0,
      gainDbi: 23.0,
    ),
    AntennaModel(
      id: 'pbe5ac',
      name: 'PowerBeam 5AC 400/500/620',
      brand: 'Ubiquiti',
      horizontalBeamwidth: 8.0,
      verticalBeamwidth: 8.0,
      gainDbi: 25.0,
    ),
    AntennaModel(
      id: 'lhg5',
      name: 'MikroTik LHG 5 / LHG XL',
      brand: 'MikroTik',
      horizontalBeamwidth: 7.0,
      verticalBeamwidth: 7.0,
      gainDbi: 24.5,
    ),
    AntennaModel(
      id: 'sxtsq5',
      name: 'MikroTik SXTsq 5 ac',
      brand: 'MikroTik',
      horizontalBeamwidth: 23.0,
      verticalBeamwidth: 23.0,
      gainDbi: 16.0,
    ),
    AntennaModel(
      id: 'custom',
      name: 'تخصيص يدوي لزاوية الشعاع',
      brand: 'Generic',
      horizontalBeamwidth: 30.0,
      verticalBeamwidth: 30.0,
      gainDbi: 18.0,
    ),
  ];
}
