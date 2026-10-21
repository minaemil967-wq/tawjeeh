import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ضبط اتجاه الشاشة رأسي فقط لمنع انقلاب البوصلة بالخطأ
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // جعل شريط الحالة داكن ومتناسق
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const TawjeehAntennaApp());
}

class TawjeehAntennaApp extends StatelessWidget {
  const TawjeehAntennaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'توجيه برو | محاذاة هوائيات الشبكات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
          background: Color(0xFF0F172A),
        ),
        fontFamily: 'Cairo',
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'EG'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ar', 'EG'),
      home: const HomeScreen(),
    );
  }
}
