import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      backgroundColor: isDark
          ? const Color(0xFF036580)
          : const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          'NoSave Chat\n\n'
          'Version 1.0.0\n\n'
          'A simple app to send messages directly to WhatsApp or Telegram without saving contacts.\n\n'
          'Features:\n'
          '- Quick messaging\n'
          '- No contact saving required\n'
          '- Free with optional ad support\n\n'
          'Developed with ❤️ using Flutter.\n\n'
          '© 2026 Your Name',
          style: GoogleFonts.poppins(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
