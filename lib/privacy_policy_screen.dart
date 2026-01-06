import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _launchPrivacyUrl() async {
    const url =
        'https://your-privacy-policy-link.com'; // REPLACE with your hosted policy URL
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      backgroundColor: isDark
          ? const Color(0xFF036580)
          : const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Privacy Policy\n\n'
              'This app does not collect any personal data.\n\n'
              'We use Google AdMob for ads. Their privacy policy applies:\n'
              'https://policies.google.com/privacy\n\n'
              'No phone numbers or messages are stored or shared.\n\n'
              'For full policy, tap below:',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _launchPrivacyUrl,
              child: const Text('View Full Privacy Policy Online'),
            ),
          ],
        ),
      ),
    );
  }
}
