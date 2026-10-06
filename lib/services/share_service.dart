import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/ad_service.dart';
import 'package:pdf_ai_toolkit/views/viewer/pdf_document_viewer_screen.dart';

class ShareService {
  /// Saves a file directly to a user-selected destination using the native system
  /// file-saving / file-picker destination dialog (Storage Access Framework on Android / save dialog on desktop/iOS).
  ///
  /// - Does NOT invoke the Android share sheet.
  /// - Allows the user to choose destination folder and filename.
  /// - Writes completed file directly to chosen location.
  /// - Returns the saved file path if successful, or null if canceled / failed.
  static Future<String?> saveFileToUserDestination(
    BuildContext context, {
    required String sourcePath,
    String? suggestedFileName,
    String? dialogTitle,
  }) async {
    final fileService = FileService();
    if (!await fileService.isFileAccessible(sourcePath)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Cannot save: Source file is missing or inaccessible.\nPath: $sourcePath'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    try {
      final sourceFile = File(sourcePath);
      final rawFileName = suggestedFileName ?? fileService.getFileName(sourcePath);
      final ext = fileService.getExtension(rawFileName).toLowerCase();
      final extWithoutDot = ext.startsWith('.') ? ext.substring(1) : ext;

      final sanitizedName = fileService.sanitizeFileName(rawFileName);
      final fileBytes = await sourceFile.readAsBytes();

      final String? selectedPath = await FilePicker.saveFile(
        dialogTitle: dialogTitle ?? 'Save File',
        fileName: sanitizedName.isNotEmpty ? sanitizedName : 'document$ext',
        type: extWithoutDot.isNotEmpty ? FileType.custom : FileType.any,
        allowedExtensions: extWithoutDot.isNotEmpty ? [extWithoutDot] : null,
        bytes: fileBytes,
      );

      // User canceled destination picker
      if (selectedPath == null || selectedPath.trim().isEmpty) {
        return null;
      }

      // If bytes were not written by plugin directly on certain platforms (e.g. desktop), write/copy safely
      final targetFile = File(selectedPath);
      if (!await targetFile.exists() || await targetFile.length() == 0) {
        try {
          await fileService.safeWriteBytes(selectedPath, fileBytes, overwrite: true);
        } catch (_) {
          await fileService.safeCopyFile(sourcePath, selectedPath, overwrite: true);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Saved successfully to ${fileService.getFileName(selectedPath)}'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      return selectedPath;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Saves multiple files to a user-selected folder destination.
  /// Used for batch image extraction / multi-page exports.
  static Future<List<String>?> saveMultipleFilesToUserDestination(
    BuildContext context, {
    required List<String> sourcePaths,
    String? dialogTitle,
  }) async {
    final fileService = FileService();
    final validSources = <String>[];
    for (final p in sourcePaths) {
      if (await fileService.isFileAccessible(p)) {
        validSources.add(p);
      }
    }

    if (validSources.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot save: No valid output files available.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    // If single file, use standard single-file save dialog
    if (validSources.length == 1) {
      if (!context.mounted) return null;
      final saved = await saveFileToUserDestination(
        context,
        sourcePath: validSources.first,
        dialogTitle: dialogTitle,
      );
      return saved != null ? [saved] : null;
    }

    try {
      final String? selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: dialogTitle ?? 'Select Folder to Save Files',
      );

      if (selectedDirectory == null || selectedDirectory.trim().isEmpty) {
        return null;
      }

      final savedPaths = <String>[];
      for (final src in validSources) {
        final fileName = fileService.getFileName(src);
        final targetPath = fileService.joinPaths(selectedDirectory, fileName);
        final uniqueTarget = await fileService.getUniqueFilePath(targetPath);
        final written = await fileService.safeCopyFile(src, uniqueTarget, overwrite: false);
        savedPaths.add(written);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Saved ${savedPaths.length} files successfully to ${fileService.getFileName(selectedDirectory)}'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      return savedPaths;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Saves a file directly to the public Downloads/AIPDFMaker directory.
  /// - Does NOT invoke the Android share sheet.
  /// - Saves directly with the given or timestamped filename.
  static Future<String?> saveFileDirectToPublicDownloads({
    required String sourcePath,
    String? customFileName,
    String? prefix = 'AIPDF',
  }) async {
    final fileService = FileService();
    if (!await fileService.isFileAccessible(sourcePath)) {
      return null;
    }

    try {
      final downloadDir = await fileService.getPublicDownloadsDirectory();
      final ext = fileService.getExtension(sourcePath).toLowerCase();
      final extClean = ext.startsWith('.') ? ext.substring(1) : ext;

      String fileName = customFileName?.trim() ?? '';
      if (fileName.isEmpty) {
        fileName = fileService.generateTimestampedFileName(
          prefix: prefix ?? 'AIPDF',
          extension: extClean.isNotEmpty ? extClean : 'pdf',
        );
      } else {
        if (!fileName.toLowerCase().endsWith('.$extClean') && extClean.isNotEmpty) {
          fileName = '$fileName.$extClean';
        }
        fileName = fileService.sanitizeFileName(fileName);
      }

      final targetPath = fileService.joinPaths(downloadDir.path, fileName);
      final uniquePath = await fileService.getUniqueFilePath(targetPath);
      final fileBytes = await File(sourcePath).readAsBytes();
      final savedPath = await fileService.safeWriteBytes(uniquePath, fileBytes, overwrite: true);
      return savedPath;
    } catch (e) {
      return null;
    }
  }

  /// Displays an interactive Chrome-style Download Banner at the top of the screen.
  static void showChromeDownloadBanner(
    BuildContext context, {
    required String fileName,
    required String savedPath,
    VoidCallback? onOpen,
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF22C55E), width: 1.2),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saved to Device',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: () {
                messenger.hideCurrentSnackBar();
                shareFile(context, filePath: savedPath);
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'SHARE',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: () {
                messenger.hideCurrentSnackBar();
                if (onOpen != null) {
                  onOpen();
                } else {
                  openDownloadedFile(context, savedPath);
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'VIEW',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the downloaded file appropriately based on its type (PDF in read-only viewer, Image preview, ZIP details, Text preview).
  static void openDownloadedFile(BuildContext context, String filePath) {
    if (!context.mounted) return;
    final ext = FileService().getExtension(filePath).toLowerCase();

    if (ext == '.pdf') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfDocumentViewerScreen(filePath: filePath),
        ),
      );
    } else if (['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'].contains(ext)) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(
                  FileService().getFileName(filePath),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_rounded),
                    tooltip: 'Share Image',
                    onPressed: () => shareFile(ctx, filePath: filePath),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.file(File(filePath), fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (ext == '.zip') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.folder_zip_rounded, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('ZIP Archive Saved'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File: ${FileService().getFileName(filePath)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Location: $filePath',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                shareFile(context, filePath: filePath, text: 'Here is my ZIP file.');
              },
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('Share ZIP'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('File Saved'),
          content: Text('File saved successfully at:\n$filePath'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  /// Saves directly to Downloads/AIPDFMaker and displays the Chrome-style notification with Share and View options.
  static Future<String?> promptAndSaveFileDirectToDownloads(
    BuildContext context, {
    required String sourcePath,
    String? defaultPrefix = 'AIPDF',
    String? dialogTitle,
    VoidCallback? onOpen,
  }) async {
    final fileService = FileService();
    if (!await fileService.isFileAccessible(sourcePath)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot save: File is missing.\nPath: $sourcePath'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    final ext = fileService.getExtension(sourcePath).toLowerCase();
    final cleanExt =
        ext.startsWith('.') ? ext.substring(1) : (ext.isNotEmpty ? ext : 'pdf');

    final defaultGeneratedName = fileService.generateTimestampedFileName(
      prefix: defaultPrefix ?? 'AIPDF',
      extension: cleanExt,
    );

    // Save directly to public Downloads directory immediately without blocking dialog
    String? savedPath = await saveFileDirectToPublicDownloads(
      sourcePath: sourcePath,
      customFileName: defaultGeneratedName,
    );

    // Fallback to native system destination saver if direct filesystem write fails
    if (savedPath == null && context.mounted) {
      savedPath = await saveFileToUserDestination(
        context,
        sourcePath: sourcePath,
        suggestedFileName: defaultGeneratedName,
      );
    } else if (savedPath != null && context.mounted) {
      showChromeDownloadBanner(
        context,
        fileName: fileService.getFileName(savedPath),
        savedPath: savedPath,
        onOpen: onOpen,
      );
    }

    return savedPath;
  }

  /// Saves multiple files directly into Downloads/AIPDFMaker and displays the Chrome-style notification.
  static Future<List<String>?> saveMultipleFilesDirectToDownloads(
    BuildContext context, {
    required List<String> sourcePaths,
  }) async {
    final fileService = FileService();
    final validSources = <String>[];
    for (final p in sourcePaths) {
      if (await fileService.isFileAccessible(p)) {
        validSources.add(p);
      }
    }

    if (validSources.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot save: No valid output files available.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    final downloadDir = await fileService.getPublicDownloadsDirectory();
    final savedPaths = <String>[];

    for (final src in validSources) {
      final fileName = fileService.getFileName(src);
      final targetPath = fileService.joinPaths(downloadDir.path, fileName);
      final uniqueTarget = await fileService.getUniqueFilePath(targetPath);
      final written = await fileService.safeCopyFile(src, uniqueTarget, overwrite: false);
      savedPaths.add(written);
    }

    if (savedPaths.isNotEmpty && context.mounted) {
      showChromeDownloadBanner(
        context,
        fileName: '${savedPaths.length} files saved to Downloads/AIPDFMaker',
        savedPath: savedPaths.first,
      );
    }

    return savedPaths;
  }

  /// Triggers the native Android share sheet with the specified file.
  static Future<bool> shareFile(
    BuildContext context, {
    required String filePath,
    String? text,
    String? subject,
  }) async {
    final fileService = FileService();
    if (!await fileService.isFileAccessible(filePath)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Cannot share: File no longer exists or is inaccessible.\nPath: $filePath'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    try {
      final ext = fileService.getExtension(filePath).toLowerCase();
      String defaultShareText = text ?? 'Here is my document file.';
      if (text == null) {
        if (ext == '.pdf') {
          defaultShareText = 'Here is my PDF file.';
        } else if (ext == '.txt' || ext == '.md') {
          defaultShareText = 'Here is my text document.';
        } else if (['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'].contains(ext)) {
          defaultShareText = 'Here is my image file.';
        }
      }

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(filePath)],
        text: defaultShareText,
        subject: subject,
      );
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Triggers the native Android share sheet with multiple files.
  static Future<bool> shareMultipleFiles(
    BuildContext context, {
    required List<String> filePaths,
    String? text,
    String? subject,
  }) async {
    final fileService = FileService();
    final validFiles = <String>[];
    for (final p in filePaths) {
      if (await fileService.isFileAccessible(p)) {
        validFiles.add(p);
      }
    }

    if (validFiles.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot share: No valid files available.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    try {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        validFiles.map((p) => XFile(p)).toList(),
        text: text ?? 'Here are my files.',
        subject: subject,
      );
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Modal helper providing distinct choices for Direct Share (native share sheet)
  /// and Direct Download to Downloads/AIPDFMaker (with Chrome-style notification).
  static Future<void> showSaveShareDialog(
      BuildContext context, String path) async {
    final isAccessible = await FileService().isFileAccessible(path);
    if (!isAccessible) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File no longer exists or is inaccessible.\nPath: $path'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF14141E) : Colors.white;
        final ext = FileService().getExtension(path).toLowerCase();
        String titleText = 'Document Ready!';
        String shareText = 'Here is my document file.';
        if (ext == '.pdf') {
          titleText = 'PDF Ready!';
          shareText = 'Here is my PDF file.';
        } else if (ext == '.txt' || ext == '.md') {
          titleText = 'Text File Ready!';
          shareText = 'Here is my text document.';
        } else if (['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'].contains(ext)) {
          titleText = 'Image Ready!';
          shareText = 'Here is my image file.';
        }

        return Container(
          decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text(titleText,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Choose an action:',
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  const SizedBox(height: 24),

                  // Share Button -> Native Android Share Sheet ONLY
                  InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await shareFile(context, filePath: path, text: shareText);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF2563EB).withValues(alpha: 0.05),
                      ),
                      child: const Row(children: [
                        Icon(Icons.share_rounded, color: Color(0xFF2563EB), size: 28),
                        SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Share Document',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2563EB))),
                              Text('Send via WhatsApp, Email, etc.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ])),
                        Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Save Button -> Direct Download to Downloads/AIPDFMaker
                  InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await promptAndSaveFileDirectToDownloads(context, sourcePath: path);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF10B981).withValues(alpha: 0.05),
                      ),
                      child: const Row(children: [
                        Icon(Icons.download_rounded, color: Color(0xFF10B981), size: 28),
                        SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Download to Device',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981))),
                              Text('Save directly to Downloads/AIPDFMaker',
                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ])),
                        Icon(Icons.chevron_right_rounded, color: Color(0xFF10B981)),
                      ]),
                    ),
                  ),

                  // Watch Ad to Unlock High-Resolution Vector Export Pass
                  if (ext == '.pdf') ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await AdService().showRewardedVideoAd(
                          context: context,
                          featureToUnlock: UnlockFeature.vectorExport,
                          onRewarded: () {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✨ High-Resolution Vector Export Pass Active for 1 Hour!'),
                                  backgroundColor: Color(0xFF16A34A),
                                ),
                              );
                            }
                          },
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.35)),
                          borderRadius: BorderRadius.circular(16),
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars_rounded, color: Color(0xFF8B5CF6), size: 26),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AdService().isFeatureUnlocked(UnlockFeature.vectorExport)
                                        ? '✨ High-Res Vector Pass Active'
                                        : 'Watch Ad for Free High-Res Pass',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                  Text(
                                    AdService().isFeatureUnlocked(UnlockFeature.vectorExport)
                                        ? '${AdService().getRemainingMinutes(UnlockFeature.vectorExport)}m remaining for 300 DPI exports'
                                        : 'Unlock 1 hour of unlimited 300 DPI vector exports',
                                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.play_circle_filled_rounded, color: Color(0xFF8B5CF6)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Modal helper for multiple files (e.g. multi-page images)
  static Future<void> showSaveShareMultipleDialog(
      BuildContext context, List<String> paths) async {
    if (paths.isEmpty) return;
    if (paths.length == 1) {
      return showSaveShareDialog(context, paths.first);
    }

    final accessiblePaths = <String>[];
    for (final p in paths) {
      if (await FileService().isFileAccessible(p)) {
        accessiblePaths.add(p);
      }
    }

    if (accessiblePaths.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot share: Selected files are inaccessible.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF14141E) : Colors.white;

        return Container(
          decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text('${accessiblePaths.length} Images Ready!',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Where would you like to save or share them?',
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  const SizedBox(height: 24),

                  // Share All Button -> Native Share Sheet ONLY
                  InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await shareMultipleFiles(
                        context,
                        filePaths: accessiblePaths,
                        text: 'Exported ${accessiblePaths.length} PNG images',
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF2563EB).withValues(alpha: 0.05),
                      ),
                      child: Row(children: [
                        const Icon(Icons.share_rounded, color: Color(0xFF2563EB), size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Share All (${accessiblePaths.length} Files)',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2563EB))),
                              const Text('Send all images via WhatsApp, Email, etc.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ])),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Save All Button -> Direct Downloads Saving ONLY
                  InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await saveMultipleFilesDirectToDownloads(
                        context,
                        sourcePaths: accessiblePaths,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF10B981).withValues(alpha: 0.05),
                      ),
                      child: Row(children: [
                        const Icon(Icons.download_rounded, color: Color(0xFF10B981), size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Download All (${accessiblePaths.length} Files)',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981))),
                              const Text('Save all images directly to Downloads/AIPDFMaker',
                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
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

