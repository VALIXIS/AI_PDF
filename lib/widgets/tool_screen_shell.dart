import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';

class ToolScreenShell extends StatelessWidget {
  final String title;
  final String explanation;
  final VoidCallback onPickFiles;
  final List<String> selectedFiles;
  final Function(int) onRemoveFile;
  final VoidCallback? onExecute;
  final String executeButtonLabel;
  final bool isLoading;
  final String loadingMessage;
  final String? errorMessage;
  final VoidCallback onDismissError;
  final String? successPath;
  final String? successSubtitle;
  final VoidCallback onReset;
  final Widget? extraConfig;

  const ToolScreenShell({
    Key? key,
    required this.title,
    required this.explanation,
    required this.onPickFiles,
    required this.selectedFiles,
    required this.onRemoveFile,
    required this.onExecute,
    required this.executeButtonLabel,
    required this.isLoading,
    required this.loadingMessage,
    required this.errorMessage,
    required this.onDismissError,
    required this.successPath,
    required this.successSubtitle,
    required this.onReset,
    this.extraConfig,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF13131F) : Colors.white;
    final borderCol =
        isDark ? const Color(0xFF1F1F35) : const Color(0xFFE2E8F0);

    return Scaffold(
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Explanation banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primary.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        explanation,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: textCol.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Processing state banner
              if (isLoading) ToolLoadingBanner(message: loadingMessage),

              // Error state banner
              if (errorMessage != null)
                ToolErrorBanner(
                  message: errorMessage!,
                  onDismiss: onDismissError,
                ),

              // Success state card
              if (successPath != null)
                ToolSuccessCard(
                  title: 'Success!',
                  subtitle: successSubtitle,
                  filePath: successPath,
                  onShare: () {
                    ShareService.showSaveShareDialog(context, successPath!);
                  },
                  onReset: onReset,
                ),

              // Extra controls (like password or watermark inputs)
              if (extraConfig != null && successPath == null) ...[
                extraConfig!,
                const SizedBox(height: 16),
              ],

              // Dropzone/File list container
              if (successPath == null)
                Expanded(
                  child: selectedFiles.isEmpty
                      ? ToolEmptyState(
                          icon: Icons.picture_as_pdf_rounded,
                          title: 'No PDF Selected',
                          subtitle: 'Select PDF files to begin operations',
                          actionLabel: 'Select PDF',
                          onAction: onPickFiles,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Files (${selectedFiles.length})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: selectedFiles.length,
                                itemBuilder: (context, idx) {
                                  final path = selectedFiles[idx];
                                  final name = FileService().getFileName(path);

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                          color: borderCol, width: 1.2),
                                    ),
                                    color: cardBg,
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.picture_as_pdf_rounded,
                                        color: Color(0xFFE03131),
                                      ),
                                      title: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.close_rounded,
                                            size: 18),
                                        onPressed: isLoading
                                            ? null
                                            : () => onRemoveFile(idx),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),

              // Bottom Execution Button actions
              if (successPath == null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : onPickFiles,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add File(s)',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (selectedFiles.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : onExecute,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(executeButtonLabel,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
