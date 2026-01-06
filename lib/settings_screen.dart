import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      backgroundColor: isDark
          ? const Color(0xFF036580)
          : const Color(0xFFF5F5F5),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.share),
            title: Text('Share App', style: GoogleFonts.poppins()),
            onTap: () {
              Share.share(
                'Check out NoSave Chat! Send messages to WhatsApp or Telegram without saving contacts. Super fast and free!\n\n'
                'Download here: https://play.google.com/store/apps/details?id=com.github.atechon.nosavechat', // Replace with your real package ID
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.star),
            title: Text(
              'Support the App (Watch Ad)',
              style: GoogleFonts.poppins(),
            ),
            onTap: () {
              Navigator.pop(context); // Back to main
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Tap the star icon on the main screen to support! ❤️',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
