import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/controllers/ai_action_dispatcher.dart';
import 'package:pdf_ai_toolkit/main.dart' show kPrimary, kPrimaryDark;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/share_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_cache_service.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final AiActionResult? actionResult;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.actionResult,
  });
}

class ChatWithPdfScreen extends StatefulWidget {
  final String? initialPdfPath;

  const ChatWithPdfScreen({Key? key, this.initialPdfPath}) : super(key: key);

  @override
  State<ChatWithPdfScreen> createState() => _ChatWithPdfScreenState();
}

class _ChatWithPdfScreenState extends State<ChatWithPdfScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiController _aiController = AiController();
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();

  File? _pdfFile;
  final List<File> _attachedFiles = [];
  String? _pdfText;
  int _pageCount = 1;
  bool _isLoadingPdf = false;
  bool _isAiThinking = false;
  String? _errorMessage;
  final List<ChatMessage> _messages = [];

  final List<String> _quickPrompts = [
    'Merge attached PDFs',
    'Split pages 1 to 3',
    'Compress this PDF',
    'Extract text from PDF',
    'Rotate 90 degrees',
    'Add watermark "CONFIDENTIAL"',
    'Summarize this document',
  ];

  @override
  void initState() {
    super.initState();
    FileService().cleanupTempResources();
    if (widget.initialPdfPath != null) {
      _loadPdfFromPath(widget.initialPdfPath!);
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      for (final f in result.files) {
        if (f.path != null &&
            !_attachedFiles.any((file) => file.path == f.path)) {
          _attachedFiles.add(File(f.path!));
        }
      }

      if (_attachedFiles.isNotEmpty) {
        await _loadPdfFromPath(_attachedFiles.last.path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to select PDF file: $e';
      });
    }
  }

  Future<void> _loadPdfFromPath(String path) async {
    if (!await FileService().isFileAccessible(path)) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Selected PDF file does not exist or is inaccessible.';
      });
      return;
    }

    setState(() {
      _isLoadingPdf = true;
      _errorMessage = null;
    });

    try {
      final cachedData = await PdfCacheService().getPdfData(path);
      if (!mounted) return;
      setState(() {
        _pdfFile = File(path);
        if (!_attachedFiles.any((file) => file.path == path)) {
          _attachedFiles.add(File(path));
        }
        _pdfText = cachedData.textContent;
        _pageCount = cachedData.pageCount;
        _isLoadingPdf = false;
        if (_messages.isEmpty) {
          _messages.add(ChatMessage(
            id: UniqueKey().toString(),
            text:
                'Hello! I am your Autonomous AI PDF Agent. I have loaded "${FileService().getFileName(path)}". Ask me questions or command me to merge, split, compress, extract text, rotate, watermark, or protect your PDF!',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not parse PDF content: $e';
        _isLoadingPdf = false;
      });
    }
  }

  String _buildConversationHistory() {
    // Collect last 6 messages excluding current pending query and tool result bubbles
    final historyMsgs = _messages.where((m) => m.actionResult == null).toList();
    if (historyMsgs.isEmpty) return '';
    final recent = historyMsgs.length > 6
        ? historyMsgs.sublist(historyMsgs.length - 6)
        : historyMsgs;
    final buffer = StringBuffer();
    for (final msg in recent) {
      final role = msg.isUser ? 'User' : 'AI Companion';
      buffer.writeln('$role: ${msg.text}');
    }
    return buffer.toString().trim();
  }

  Future<void> _sendMessage([String? customPrompt]) async {
    final text = (customPrompt ?? _inputController.text).trim();
    if (text.isEmpty) return;

    if (_attachedFiles.isEmpty && _pdfFile == null) {
      setState(() {
        _errorMessage =
            'Please select or attach at least one PDF document first.';
      });
      return;
    }

    final userMessage = ChatMessage(
      id: UniqueKey().toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    final historyContext = _buildConversationHistory();

    setState(() {
      _messages.add(userMessage);
      if (customPrompt == null) _inputController.clear();
      _isAiThinking = true;
      _errorMessage = null;
    });

    _scrollToBottom();

    try {
      final pdfPaths = _attachedFiles.map((f) => f.path).toList();
      if (pdfPaths.isEmpty && _pdfFile != null) pdfPaths.add(_pdfFile!.path);

      // 1. Check if user command triggers a PDF tool action (Merge, Split, Compress, Extract, Rotate, Watermark, Protect)
      final actionResult = await _aiController.processMultiDocumentAction(
        pdfPaths: pdfPaths,
        command: text,
      );

      if (!mounted) return;

      if (actionResult != null && actionResult.isSuccess) {
        setState(() {
          _messages.add(ChatMessage(
            id: UniqueKey().toString(),
            text: actionResult.message,
            isUser: false,
            timestamp: DateTime.now(),
            actionResult: actionResult,
          ));
          _isAiThinking = false;
        });
      } else {
        // 2. Multi-PDF Comparison vs Single Document Q&A
        String answer;
        if (_attachedFiles.length > 1) {
          final List<String> docTexts = [];
          for (final f in _attachedFiles) {
            final cache = await PdfCacheService().getPdfData(f.path);
            docTexts.add(
                'Document "${FileService().getFileName(f.path)}":\n${cache.textContent}');
          }
          answer = await _aiController.compareDocuments(
            docTexts: docTexts,
            question: text,
            conversationHistory: historyContext,
          );
        } else {
          answer = await _aiController.askDocumentQuestion(
            pdfText: _pdfText ?? 'Document contents ready.',
            question: text,
            conversationHistory: historyContext,
          );
        }

        if (!mounted) return;
        setState(() {
          _messages.add(ChatMessage(
            id: UniqueKey().toString(),
            text: answer,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isAiThinking = false;
        });
      }

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'AI Agent error: $e';
        _isAiThinking = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _exportChatToPdf() async {
    if (_messages.isEmpty) return;

    try {
      final buffer = StringBuffer();
      buffer.writeln('AI PDF CHAT & ACTION REPORT');
      buffer.writeln(
          'Document: ${_pdfFile != null ? FileService().getFileName(_pdfFile!.path) : "N/A"}');
      buffer.writeln('Date: ${DateTime.now().toLocal()}\n');
      buffer.writeln('=' * 40);
      buffer.writeln();

      for (final msg in _messages) {
        buffer.writeln(msg.isUser ? 'USER QUESTION:' : 'AI AGENT RESPONSE:');
        buffer.writeln(msg.text);
        if (msg.actionResult?.outputPath != null) {
          buffer.writeln('OUTPUT PDF: ${msg.actionResult!.outputPath}');
        }
        buffer.writeln('-' * 30);
      }

      final title =
          'AI Chat - ${_pdfFile != null ? FileService().getFileName(_pdfFile!.path) : "Document"}';
      final path = await _pdfService.generatePdfFromText(
        title: title,
        content: buffer.toString(),
      );

      await _storageService.addHistoryEntry(HistoryEntry(
        id: _aiController.generateId(),
        title: title,
        date: DateTime.now(),
        filePath: path,
        toolType: 'ai_chat',
      ));

      if (mounted) {
        ShareService.showSaveShareDialog(context, path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to export chat to PDF: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? kPrimaryDark : kPrimary;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final border = isDark ? const Color(0xFF2A2A3C) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI PDF Agent',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              _pdfFile != null
                  ? FileService().getFileName(_pdfFile!.path)
                  : 'Select a PDF document to begin',
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Export Chat to PDF',
              onPressed: _exportChatToPdf,
            ),
          IconButton(
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: 'Change PDF File',
            onPressed: _pickPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          // Loading PDF Banner
          if (_isLoadingPdf)
            const ToolLoadingBanner(
              message: 'Loading PDF document into AI Agent...',
            ),

          // Error Banner
          if (_errorMessage != null)
            ToolErrorBanner(
              message: _errorMessage!,
              onDismiss: () => setState(() => _errorMessage = null),
            ),

          // Top Document Card / Empty State
          if (_pdfFile == null && !_isLoadingPdf)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ToolEmptyState(
                icon: Icons.auto_awesome_rounded,
                title: 'No PDF Document Selected',
                subtitle:
                    'Select a PDF document to edit, rotate, watermark, split, or ask questions',
                actionLabel: 'Select PDF Document',
                onAction: _pickPdf,
              ),
            )
          else if (_pdfFile != null)
            _buildDocumentHeader(primary, cardBg, border, isDark),

          // Chat Messages List
          Expanded(
            child: _pdfFile == null
                ? const SizedBox.shrink()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(
                          msg, primary, cardBg, border, isDark);
                    },
                  ),
          ),

          // AI Thinking Banner
          if (_isAiThinking)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AI Agent is executing tool operation...',
                    style: TextStyle(
                        fontSize: 12,
                        color: primary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          // Quick Action Chips
          if (_pdfFile != null && !_isAiThinking)
            _buildQuickActionChips(primary, cardBg, border, isDark),

          // Bottom Input Bar
          if (_pdfFile != null)
            _buildBottomInputBar(primary, cardBg, border, isDark),
        ],
      ),
    );
  }

  Widget _buildDocumentHeader(
      Color primary, Color cardBg, Color border, bool isDark) {
    final count = _attachedFiles.length;
    final fileNames =
        _attachedFiles.map((f) => FileService().getFileName(f.path)).join(', ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
                count > 1 ? Icons.copy_rounded : Icons.picture_as_pdf_rounded,
                color: primary,
                size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count > 1
                      ? '$count PDFs Attached'
                      : FileService().getFileName(_pdfFile!.path),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  count > 1
                      ? fileNames
                      : '$_pageCount Pages • ${(_pdfFile!.lengthSync() / 1024).toStringAsFixed(1)} KB',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pickPdf,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(count > 1 ? 'Add PDF' : 'Attach',
                style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChips(
      Color primary, Color cardBg, Color border, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: _quickPrompts.map((prompt) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              avatar:
                  Icon(Icons.auto_awesome_rounded, size: 14, color: primary),
              label: Text(prompt, style: const TextStyle(fontSize: 12)),
              backgroundColor: cardBg,
              side: BorderSide(color: border),
              onPressed: () => _sendMessage(prompt),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageBubble(
      ChatMessage msg, Color primary, Color cardBg, Color border, bool isDark) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 48, top: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.text,
            style:
                const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 36, top: 6, bottom: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy_rounded, size: 16, color: primary),
                const SizedBox(width: 6),
                Text(
                  'AI Autonomous Agent',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: primary),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: 'Copy response',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: msg.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('AI response copied!'),
                          duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              msg.text,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? Colors.white : Colors.black87),
            ),

            // Render Tool Action Result Card if available
            if (msg.actionResult != null && msg.actionResult!.isSuccess)
              _buildActionResultCard(msg.actionResult!, primary, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildActionResultCard(
      AiActionResult result, Color primary, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  result.actionTitle ?? 'Action Completed Successfully',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (result.outputPath != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => ShareService.showSaveShareDialog(
                        context, result.outputPath!),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Save / Share Output',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _loadPdfFromPath(result.outputPath!),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Load in Chat',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomInputBar(
      Color primary, Color cardBg, Color border, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                enabled: !_isAiThinking,
                controller: _inputController,
                decoration: InputDecoration(
                  hintText:
                      'Command AI to rotate, watermark, split, or edit...',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: border),
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isAiThinking ? null : () => _sendMessage(),
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
