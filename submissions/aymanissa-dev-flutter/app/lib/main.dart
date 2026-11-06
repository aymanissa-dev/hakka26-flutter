import 'package:flutter/material.dart';
import 'package:hakka/otp/otp_colors.dart';
import 'package:hakka/otp/otp_screen.dart';

const appName = 'hakkahakka26';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HakkaApp());
}

class HakkaApp extends StatefulWidget {
  const HakkaApp({super.key});

  @override
  State<HakkaApp> createState() => _HakkaAppState();
}

class _HakkaAppState extends State<HakkaApp> {
  late final Future<OtpPalettes> _palettes = OtpPalettes.load();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      themeMode: ThemeMode.system,
      home: FutureBuilder<OtpPalettes>(
        future: _palettes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text('Could not load colours.json')),
            );
          }
          final palettes = snapshot.data;
          if (palettes == null) {
            return const Scaffold(body: SizedBox.expand());
          }
          return OtpScreen(palettes: palettes);
        },
      ),
    );
  }
}
