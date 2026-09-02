import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';

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

  /// Triggers the native Android share sheet with the specified file.
  ///
  /// - Does NOT open the system Save / file-picker destination dialog.
  /// - Does NOT treat share cancellation or failure as a Save operation.
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

  /// Legacy modal helper providing distinct choices for Direct Share (native share sheet)
  /// and Save to Files (system destination picker).
  static Future<void> showSaveShareDialog(
      BuildContext context, String path) async {
    final isAccessible = await FileService().isFileAccessible(path);
    if (!isAccessible) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'File no longer exists or is inaccessible.\nPath: $path'),
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
        } else if (['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp']
            .contains(ext)) {
          titleText = 'Image Ready!';
          shareText = 'Here is my image file.';
        }

        return Container(
          decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24))),
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
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Choose an action:',
                      style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600])),
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
                            color:
                                const Color(0xFF2563EB).withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF2563EB).withValues(alpha: 0.05),
                      ),
                      child: const Row(children: [
                        Icon(Icons.share_rounded,
                            color: Color(0xFF2563EB), size: 28),
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
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ])),
                        Icon(Icons.chevron_right_rounded,
                            color: Color(0xFF2563EB)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Save Button -> System File Save Picker ONLY
                  InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await saveFileToUserDestination(context, sourcePath: path);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF10B981).withValues(alpha: 0.05),
                      ),
                      child: const Row(children: [
                        Icon(Icons.save_alt_rounded,
                            color: Color(0xFF10B981), size: 28),
                        SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Save to Device',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981))),
                              Text('Choose destination folder and name',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ])),
                        Icon(Icons.chevron_right_rounded,
                            color: Color(0xFF10B981)),
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24))),
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
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Where would you like to save or share them?',
                      style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  const SizedBox(height: 24),

                  // Share All Button
                  InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await Share.shareXFiles(
                          accessiblePaths.map((p) => XFile(p)).toList(),
                          text: 'Exported ${accessiblePaths.length} PNG images',
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Could not share files: $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color:
                                const Color(0xFF2563EB).withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF2563EB).withValues(alpha: 0.05),
                      ),
                      child: Row(children: [
                        const Icon(Icons.share_rounded,
                            color: Color(0xFF2563EB), size: 28),
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
                              const Text(
                                  'Send all images via WhatsApp, Email, etc.',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ])),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFF2563EB)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Save All Button
                  InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await Share.shareXFiles(
                          accessiblePaths.map((p) => XFile(p)).toList(),
                          text: 'Save ${accessiblePaths.length} images',
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Could not save files: $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF10B981).withValues(alpha: 0.05),
                      ),
                      child: Row(children: [
                        const Icon(Icons.folder_open_rounded,
                            color: Color(0xFF10B981), size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Save All (${accessiblePaths.length} Files)',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981))),
                              const Text('Save all images to device folder',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ])),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFF10B981)),
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
