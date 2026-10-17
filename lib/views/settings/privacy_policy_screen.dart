import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy for AI PDF Maker',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textCol,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Last updated: October 18, 2026 (v1.1.0+21)',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: '1. Introduction',
              content:
                  'Welcome to AI PDF Maker. We respect your privacy and are committed to protecting your personal data. This privacy policy informs you of how your data is handled when you use our application.',
              textCol: textCol,
            ),
            _buildSection(
              title: '2. Local Processing & Document Security',
              content:
                  'AI PDF Maker is built with a strict local-first architecture. All document operations—including merging, splitting, compressing, editing, visual PDF redaction, password protection & permissions, form filling, and digital signatures—are performed LOCALLY on your device. We do not upload your documents to any external server.',
              textCol: textCol,
            ),
            _buildSection(
              title: '3. AI Features & Cloud Processing',
              content:
                  'When you explicitly invoke AI features (e.g., "Chat with PDF", "AI Summarizer", "AI Refine", or "AI to PDF"), only the extracted plain text from your chosen document and your prompt are transmitted securely over HTTPS to trusted AI providers (Google Gemini / Hugging Face). Binary PDF files are never uploaded, and conversation memory is ephemeral in RAM only.',
              textCol: textCol,
            ),
            _buildSection(
              title: '4. Permissions',
              content:
                  'We use standard system media pickers to read and save user-selected files. Camera permission is requested strictly when using the Document Scanner to photograph pages in real-time. Zero background camera or storage tracking.',
              textCol: textCol,
            ),
            _buildSection(
              title: '5. Play Store Compliance & Data Retention',
              content:
                  'AI PDF Maker fully complies with Google Play Developer Policies and Scoped Storage mandates. Zero third-party advertising SDKs or tracking cookies are present. Temporary working files are automatically cleaned up.',
              textCol: textCol,
            ),
            _buildSection(
              title: '6. Official Web Policy & Changes',
              content:
                  'Our full authoritative privacy policy is hosted publicly at https://valixis.github.io/AI_PDF/. We may update our terms periodically to reflect new features.',
              textCol: textCol,
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('https://valixis.github.io/AI_PDF/');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text('Open Web Privacy Policy'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required Color textCol,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textCol,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: textCol.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
