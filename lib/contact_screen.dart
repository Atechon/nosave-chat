import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _launchEmail() async {
    final uri = Uri.parse(
      'mailto:your-email@example.com?subject=NoSave Chat Feedback',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Contact')),
      backgroundColor: isDark
          ? const Color(0xFF036580)
          : const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Contact Us\n\n'
              'For feedback, suggestions, or issues:\n\n'
              'Email: your-email@example.com\n\n'
              'We appreciate your input!',
              style: GoogleFonts.poppins(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _launchEmail,
              child: const Text('Send Email'),
            ),
          ],
        ),
      ),
    );
  }
}
