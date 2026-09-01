import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_editor_screen.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final StorageService _storageService = StorageService();
  bool _isLoading = true;
  List<HistoryEntry> _historyEntries = [];
  Set<String> _inaccessibleEntryIds = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (_historyEntries.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') {
                  _showClearConfirmation(context);
                } else if (value == 'clean_stale') {
                  _cleanupStaleEntries();
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'clean_stale',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services_rounded,
                          color: Colors.orange),
                      SizedBox(width: 12),
                      Text('Clean Missing Files'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Clear History'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text('Error: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_historyEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No History Yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Generated PDFs will appear here',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historyEntries.length,
      itemBuilder: (context, index) {
        final entry = _historyEntries[index];
        return _buildHistoryCard(context, entry);
      },
    );
  }

  Widget _buildHistoryCard(BuildContext context, HistoryEntry entry) {
    final dateFormat = DateFormat('MMM dd, yyyy - HH:mm');
    final formattedDate = dateFormat.format(entry.date);
    final isMissing = _inaccessibleEntryIds.contains(entry.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () {
          _openEntry(entry);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMissing
                      ? const Color.fromRGBO(255, 152, 0, 0.15)
                      : Color.fromRGBO(
                          (Theme.of(context).colorScheme.primary.r * 255)
                              .round(),
                          (Theme.of(context).colorScheme.primary.g * 255)
                              .round(),
                          (Theme.of(context).colorScheme.primary.b * 255)
                              .round(),
                          0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isMissing
                      ? Icons.warning_amber_rounded
                      : Icons.picture_as_pdf,
                  color: isMissing
                      ? Colors.orange[800]
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          formattedDate,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(
                                (Theme.of(context).colorScheme.primary.r * 255)
                                    .round(),
                                (Theme.of(context).colorScheme.primary.g * 255)
                                    .round(),
                                (Theme.of(context).colorScheme.primary.b * 255)
                                    .round(),
                                0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getToolLabel(entry.toolType),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                        if (isMissing)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'File missing',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'open') {
                    _openEntry(entry);
                  } else if (value == 'save') {
                    _saveEntryToDevice(entry);
                  } else if (value == 'share') {
                    _shareEntry(entry);
                  } else if (value == 'info') {
                    _showEntryOptions(context, entry);
                  } else if (value == 'delete') {
                    _deleteEntry(entry);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new, size: 20),
                        SizedBox(width: 12),
                        Text('Open'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'save',
                    child: Row(
                      children: [
                        Icon(Icons.save_alt_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Save to Device'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, size: 20),
                        SizedBox(width: 12),
                        Text('Share'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'info',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20),
                        SizedBox(width: 12),
                        Text('Details'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEntry(HistoryEntry entry) async {
    final accessible = await _storageService.isEntryFileAccessible(entry);
    if (!accessible) {
      if (mounted) {
        setState(() {
          _inaccessibleEntryIds.add(entry.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File no longer exists on device: ${entry.filePath}'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Remove',
              textColor: Colors.white,
              onPressed: () => _deleteEntry(entry),
            ),
          ),
        );
      }
      return;
    }

    final ext = FileService().getExtension(entry.filePath).toLowerCase();
    if (ext == '.pdf') {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfEditorScreen(initialFilePath: entry.filePath),
        ),
      );
    } else if (ext == '.txt' || ext == '.md') {
      try {
        final content = await File(entry.filePath).readAsString();
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(entry.title),
            content: SingleChildScrollView(
              child: SelectableText(content),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read text file: $e')),
        );
      }
    } else if (['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp']
        .contains(ext)) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(entry.title),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              InteractiveViewer(
                child: Image.file(File(entry.filePath)),
              ),
            ],
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ShareService.showSaveShareDialog(context, entry.filePath);
    }
  }

  void _showEntryOptions(BuildContext context, HistoryEntry entry) {
    final isMissing = _inaccessibleEntryIds.contains(entry.id);

    showBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                isMissing ? Icons.warning_amber_rounded : Icons.folder,
                color: isMissing ? Colors.orange[800] : null,
              ),
              title: const Text('File Path'),
              subtitle: Text(
                isMissing
                    ? '${entry.filePath} (File missing or deleted)'
                    : entry.filePath,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Created'),
              subtitle: Text(
                DateFormat('EEEE, MMMM d, yyyy - HH:mm:ss').format(entry.date),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openEntry(entry);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _saveEntryToDevice(entry);
                    },
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _shareEntry(entry);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteEntry(entry);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content:
            const Text('Are you sure you want to delete all history entries?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearHistory();
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadHistory() async {
    try {
      final entries = await _storageService.getHistoryEntriesSortedByDate();
      final inaccessible = <String>{};
      if (entries.isNotEmpty) {
        final accessibilityResults = await Future.wait(
          entries.map((entry) => _storageService.isEntryFileAccessible(entry)),
        );
        for (int i = 0; i < entries.length; i++) {
          if (!accessibilityResults[i]) {
            inaccessible.add(entries[i].id);
          }
        }
      }
      if (mounted) {
        setState(() {
          _historyEntries = entries;
          _inaccessibleEntryIds = inaccessible;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cleanupStaleEntries() async {
    try {
      final count = await _storageService.cleanupMissingEntries();
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0
              ? 'Removed $count missing history entry(ies).'
              : 'No missing files found in history.'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteEntry(HistoryEntry entry) async {
    try {
      await _storageService.deleteHistoryEntry(entry.id);
      _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry deleted'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _clearHistory() async {
    try {
      await _storageService.clearAllHistory();
      _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('History cleared'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _saveEntryToDevice(HistoryEntry entry) async {
    final exists = await _storageService.isEntryFileAccessible(entry);
    if (!exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File no longer exists on device: ${entry.filePath}'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Remove',
            textColor: Colors.white,
            onPressed: () => _deleteEntry(entry),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    await ShareService.saveFileToUserDestination(
      context,
      sourcePath: entry.filePath,
      suggestedFileName: entry.title,
    );
  }

  Future<void> _shareEntry(HistoryEntry entry) async {
    final exists = await _storageService.isEntryFileAccessible(entry);
    if (!exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File no longer exists on device: ${entry.filePath}'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Remove',
            textColor: Colors.white,
            onPressed: () => _deleteEntry(entry),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    await ShareService.shareFile(
      context,
      filePath: entry.filePath,
      text: 'Check out this document: ${entry.title}',
    );
  }

  String _getToolLabel(String toolType) {
    switch (toolType) {
      case 'ai_to_pdf':
        return 'AI to PDF';
      case 'text_to_pdf':
        return 'Text to PDF';
      case 'merge_pdf':
        return 'Merge';
      case 'split_pdf':
        return 'Split';
      case 'compress_pdf':
        return 'Compress';
      case 'pdf_to_text':
        return 'PDF to Text';
      default:
        return toolType;
    }
  }
}
