import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';

class ShareService {
  static Future<void> showSaveShareDialog(BuildContext context, String path) async {
    final isAccessible = await FileService().isFileAccessible(path);
    if (!isAccessible) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot share: File no longer exists or is inaccessible.\nPath: $path'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF14141E) : Colors.white;
        return Container(
          decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  const Text('PDF Ready!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Where would you like to save it?', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  const SizedBox(height: 24),
                  
                  // Share Button
                  InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (await FileService().isFileAccessible(path)) {
                        Share.shareXFiles([XFile(path)], text: 'Here is my PDF file.');
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('File no longer exists or is inaccessible.'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF2563EB).withValues(alpha: 0.05),
                      ),
                      child: Row(children: [
                        const Icon(Icons.share_rounded, color: Color(0xFF2563EB), size: 28),
                        const SizedBox(width: 16),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Direct Share', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                          Text('Send via WhatsApp, Email, etc.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ])),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Save Button
                  InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (await FileService().isFileAccessible(path)) {
                        Share.shareXFiles([XFile(path)], text: 'Save this PDF');
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('File no longer exists or is inaccessible.'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF10B981).withValues(alpha: 0.05),
                      ),
                      child: Row(children: [
                        const Icon(Icons.folder_open_rounded, color: Color(0xFF10B981), size: 28),
                        const SizedBox(width: 16),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Save to Files', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                          Text('Choose a specific folder', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ])),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF10B981)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
