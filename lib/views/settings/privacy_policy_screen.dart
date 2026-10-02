import 'package:flutter/material.dart';

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
              'Last updated: September 11, 2026',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: '1. Introduction',
              content:
                  'Welcome to AI PDF Maker. We respect your privacy and are committed to protecting your personal data. This privacy policy will inform you as to how we look after your data when you use our application.',
              textCol: textCol,
            ),
            _buildSection(
              title: '2. Local Processing',
              content:
                  'AI PDF Maker is designed with privacy at its core. All document operations, including merging, splitting, compressing, and editing, are performed LOCALLY on your device. We do not upload your documents to any external server unless you explicitly use an AI feature that requires cloud processing.',
              textCol: textCol,
            ),
            _buildSection(
              title: '3. AI Features & Cloud Processing',
              content:
                  'When you use AI features (e.g., "Chat with PDF", "AI Refine", or "AI to PDF"), the relevant text from your document is sent to our trusted AI provider (e.g., Google Gemini). This data is transmitted securely and is strictly used to generate the requested response. We do not retain, train models on, or sell your document data.',
              textCol: textCol,
            ),
            _buildSection(
              title: '4. Permissions',
              content:
                  'We require storage permissions to read and write PDF files on your device. We require camera permissions only if you use the "Camera Scan" feature. These permissions are used strictly for the intended functionality.',
              textCol: textCol,
            ),
            _buildSection(
              title: '5. Changes to this Policy',
              content:
                  'We may update our Privacy Policy from time to time. Thus, you are advised to review this page periodically for any changes. We will notify you of any changes by posting the new Privacy Policy on this page.',
              textCol: textCol,
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
              color: textCol.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}
