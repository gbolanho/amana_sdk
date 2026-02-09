import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'views/hub_screen.dart';

void main() {
  runApp(const AmanaSDKApp());
}

class AmanaSDKApp extends StatelessWidget {
  const AmanaSDKApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amana Authoring Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        textTheme: GoogleFonts.jetBrainsMonoTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const HubScreen(),
    );
  }
}
