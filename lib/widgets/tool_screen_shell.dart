import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';

class ToolScreenShell extends StatelessWidget {
  final String title;
  final String explanation;
  final VoidCallback? onPickFiles;
  final List<String> selectedFiles;
  final Function(int)? onRemoveFile;
  final VoidCallback? onExecute;
  final String executeButtonLabel;
  final bool isLoading;
  final String loadingMessage;
  final String? errorMessage;
  final VoidCallback onDismissError;
  final VoidCallback? onRetry;
  final String? successPath;
  final String? successTitle;
  final String? successSubtitle;
  final VoidCallback onReset;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final Widget? extraConfig;
  final List<Widget>? actions;
  final double? progress;
  final String? loadingSubMessage;
  final String? pickButtonLabel;
  final IconData? pickButtonIcon;
  final IconData? executeButtonIcon;
  final bool showPickButton;
  final bool alwaysShowExecuteButton;
  final Widget? customBottomBar;
  final String? emptyStateTitle;
  final String? emptyStateSubtitle;
  final IconData? emptyStateIcon;
  final String? emptyStateActionLabel;
  final Widget? emptyState;
  final Widget? customContent;
  final Widget? successContent;
  final String? defaultSavePrefix;
  final bool scrollable;
  final IconData? explanationIcon;
  final PreferredSizeWidget? customAppBar;

  const ToolScreenShell({
    Key? key,
    required this.title,
    required this.explanation,
    this.onPickFiles,
    this.selectedFiles = const [],
    this.onRemoveFile,
    this.onExecute,
    required this.executeButtonLabel,
    required this.isLoading,
    required this.loadingMessage,
    required this.errorMessage,
    required this.onDismissError,
    this.onRetry,
    required this.successPath,
    this.successTitle,
    required this.successSubtitle,
    required this.onReset,
    this.onSave,
    this.onShare,
    this.extraConfig,
    this.actions,
    this.progress,
    this.loadingSubMessage,
    this.pickButtonLabel,
    this.pickButtonIcon,
    this.executeButtonIcon,
    this.showPickButton = true,
    this.alwaysShowExecuteButton = false,
    this.customBottomBar,
    this.emptyStateTitle,
    this.emptyStateSubtitle,
    this.emptyStateIcon,
    this.emptyStateActionLabel,
    this.emptyState,
    this.customContent,
    this.successContent,
    this.defaultSavePrefix,
    this.scrollable = false,
    this.explanationIcon,
    this.customAppBar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF13131F) : Colors.white;
    final borderCol =
        isDark ? const Color(0xFF1F1F35) : const Color(0xFFE2E8F0);

    return _ToolExitLifecycleWrapper(
      child: Scaffold(
      appBar: customAppBar ??
          AppBar(
            title: Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            centerTitle: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
            actions: actions,
          ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Explanation banner
              if (explanation.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primary.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      Icon(explanationIcon ?? Icons.info_outline_rounded,
                          color: primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          explanation,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: textCol.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Processing state banner
              if (isLoading)
                ToolLoadingBanner(
                  message: loadingMessage,
                  progress: progress,
                  subMessage: loadingSubMessage,
                ),

              // Error state banner
              if (errorMessage != null)
                ToolErrorBanner(
                  message: errorMessage!,
                  onRetry: onRetry,
                  onDismiss: onDismissError,
                ),

              // Success state card & optional success content
              if (successPath != null) ...[
                ToolSuccessCard(
                  title: successTitle ?? 'Success!',
                  subtitle: successSubtitle,
                  filePath: successPath,
                  onSave: onSave ??
                      () {
                        ShareService.promptAndSaveFileDirectToDownloads(
                          context,
                          sourcePath: successPath!,
                          defaultPrefix: defaultSavePrefix,
                        );
                      },
                  onShare: onShare ??
                      () {
                        ShareService.shareFile(
                          context,
                          filePath: successPath!,
                        );
                      },
                  onReset: onReset,
                ),
                if (successContent != null) ...[
                  const SizedBox(height: 12),
                  Expanded(child: successContent!),
                ],
              ],

              // Main body area (when not in success state or customContent handles state)
              if (successPath == null)
                Expanded(
                  child: customContent != null
                      ? (scrollable
                          ? SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: customContent!,
                            )
                          : customContent!)
                      : (selectedFiles.isEmpty
                          ? (emptyState ??
                              ToolEmptyState(
                                icon: emptyStateIcon ??
                                    Icons.picture_as_pdf_rounded,
                                title: emptyStateTitle ?? 'No PDF Selected',
                                subtitle: emptyStateSubtitle ??
                                    'Select PDF files to begin operations',
                                actionLabel:
                                    emptyStateActionLabel ?? 'Select PDF',
                                onAction: isLoading ? null : onPickFiles,
                              ))
                          : ListView(
                              physics: const BouncingScrollPhysics(),
                              children: [
                                if (extraConfig != null) ...[
                                  extraConfig!,
                                  const SizedBox(height: 16),
                                ],
                                Text(
                                  'Selected Files (${selectedFiles.length})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5),
                                ),
                                const SizedBox(height: 8),
                                ...selectedFiles.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final path = entry.value;
                                  final name =
                                      FileService().getFileName(path);

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
                                      trailing: onRemoveFile != null
                                          ? IconButton(
                                              icon: const Icon(
                                                  Icons.close_rounded,
                                                  size: 18),
                                              onPressed: isLoading
                                                  ? null
                                                  : () => onRemoveFile!(idx),
                                            )
                                          : null,
                                    ),
                                  );
                                }),
                              ],
                            )),
                ),

              // Bottom Execution Button actions
              if (successPath == null) ...[
                if (customBottomBar != null)
                  customBottomBar!
                else ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (showPickButton && onPickFiles != null) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isLoading ? null : onPickFiles,
                            icon: Icon(pickButtonIcon ?? Icons.add_rounded),
                            label: Text(pickButtonLabel ?? 'Add File(s)',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        if (selectedFiles.isNotEmpty ||
                            alwaysShowExecuteButton)
                          const SizedBox(width: 12),
                      ],
                      if (selectedFiles.isNotEmpty ||
                          alwaysShowExecuteButton) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : onExecute,
                            icon: isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(executeButtonIcon ??
                                    Icons.play_arrow_rounded),
                            label: Text(
                                isLoading
                                    ? 'Processing...'
                                    : executeButtonLabel,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// Lifecycle widget that purges scratch export directories when the tool screen unmounts/exits
class _ToolExitLifecycleWrapper extends StatefulWidget {
  final Widget child;
  const _ToolExitLifecycleWrapper({required this.child});

  @override
  State<_ToolExitLifecycleWrapper> createState() =>
      _ToolExitLifecycleWrapperState();
}

class _ToolExitLifecycleWrapperState extends State<_ToolExitLifecycleWrapper> {
  @override
  void dispose() {
    FileService().cleanupTempResources();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
