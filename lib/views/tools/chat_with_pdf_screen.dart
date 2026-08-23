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
  final String? initialPrompt;

  const ChatWithPdfScreen({Key? key, this.initialPdfPath, this.initialPrompt})
      : super(key: key);

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

    // Setup initial welcome message
    _messages.add(ChatMessage(
      id: UniqueKey().toString(),
      text:
          'Hello! I am your AI PDF Companion. Attach one or more PDF files below to start chatting, asking questions, comparing documents, or requesting PDF operations!',
      isUser: false,
      timestamp: DateTime.now(),
    ));

    if (widget.initialPrompt != null) {
      _inputController.text = widget.initialPrompt!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.initialPdfPath == null) {
          _pickPdf().then((_) {
            if (_attachedFiles.isNotEmpty) {
              _sendMessage(widget.initialPrompt);
            }
          });
        } else {
          _sendMessage(widget.initialPrompt);
        }
      });
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

        _messages.add(ChatMessage(
          id: UniqueKey().toString(),
          text:
              'Loaded "${FileService().getFileName(path)}". I am ready to summarize, answer questions, or process this document.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not parse PDF content: $e';
        _isLoadingPdf = false;
      });
    }
  }

  void _removeAttachment(int idx) {
    setState(() {
      final removed = _attachedFiles.removeAt(idx);
      if (_pdfFile?.path == removed.path) {
        _pdfFile = _attachedFiles.isNotEmpty ? _attachedFiles.last : null;
        _pdfText = null;
      }
    });
  }

  String _buildConversationHistory() {
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
        _errorMessage = 'Please attach at least one PDF document first.';
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

      // Check if user command triggers a PDF tool action
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
        // Multi-PDF Comparison vs Single Document Q&A
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
    final bg = isDark ? const Color(0xFF0A0A10) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF13131F) : Colors.white;
    final border = isDark ? const Color(0xFF1F1F35) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI PDF Companion',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              _pdfFile != null
                  ? '${_attachedFiles.length} file(s) loaded'
                  : 'No active document',
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          if (_messages.length > 1)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Export Chat Report',
              onPressed: _exportChatToPdf,
            ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Attach PDF',
            onPressed: _pickPdf,
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Loading PDFs loading indicator
          if (_isLoadingPdf)
            const LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
            ),

          // Error Banner
          if (_errorMessage != null)
            ToolErrorBanner(
              message: _errorMessage!,
              onDismiss: () => setState(() => _errorMessage = null),
            ),

          // Main Chat Message Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              physics: const BouncingScrollPhysics(),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(
                    msg, primary, cardBg, border, isDark);
              },
            ),
          ),

          // AI Thinking state bubble
          if (_isAiThinking)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AI Companion is thinking...',
                    style: TextStyle(
                      fontSize: 12,
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Dynamic Horizontal PDF File Attachments list
          if (_attachedFiles.isNotEmpty)
            _buildAttachmentsRow(cardBg, border, isDark),

          // Floating Quick Prompt Chips
          if (!_isAiThinking)
            _buildQuickActionChips(primary, cardBg, border, isDark),

          // Bottom Premium Input Bar
          _buildBottomInputBar(primary, cardBg, border, isDark),
        ],
      ),
    );
  }

  Widget _buildAttachmentsRow(Color cardBg, Color border, bool isDark) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF1F5F9),
        border: Border(top: BorderSide(color: border, width: 0.8)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _attachedFiles.length,
        itemBuilder: (context, index) {
          final file = _attachedFiles[index];
          final name = FileService().getFileName(file.path);
          final sizeKb = (file.lengthSync() / 1024).toStringAsFixed(1);

          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded,
                    color: Color(0xFFE03131), size: 18),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '$sizeKb KB',
                      style: const TextStyle(fontSize: 9.5, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _removeAttachment(index),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionChips(
      Color primary, Color cardBg, Color border, bool isDark) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: _quickPrompts.length,
        itemBuilder: (context, index) {
          final prompt = _quickPrompts[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.auto_awesome,
                  size: 12, color: Colors.deepPurple),
              label: Text(prompt, style: const TextStyle(fontSize: 11.5)),
              backgroundColor: cardBg,
              side: BorderSide(color: border, width: 1.2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              onPressed: () => _sendMessage(prompt),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(
      ChatMessage msg, Color primary, Color cardBg, Color border, bool isDark) {
    final userBubbleBg = const Color(0xFF7C3AED); // Modern purple bubble
    final aiBubbleBg = isDark ? const Color(0xFF13131F) : Colors.white;

    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 48, top: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: userBubbleBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
                color: Colors.white, fontSize: 13.5, height: 1.4),
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
          color: aiBubbleBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy_rounded,
                    size: 16, color: Color(0xFF7C3AED)),
                const SizedBox(width: 6),
                const Text(
                  'AI Companion',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      color: Color(0xFF7C3AED)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: 'Copy',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: msg.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Copied to clipboard'),
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
                fontSize: 13.5,
                height: 1.4,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
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
        color: const Color(0xFF10B981).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.actionTitle ?? 'Action Completed',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12.5),
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
                    icon: const Icon(Icons.ios_share_rounded, size: 14),
                    label: const Text('Save / Share',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _loadPdfFromPath(result.outputPath!),
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Load PDF', style: TextStyle(fontSize: 11)),
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
        border: Border(top: BorderSide(color: border, width: 1.2)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: Colors.grey),
              onPressed: _isLoadingPdf || _isAiThinking ? null : _pickPdf,
            ),
            Expanded(
              child: TextField(
                enabled: !_isAiThinking,
                controller: _inputController,
                style: const TextStyle(fontSize: 13.5),
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Ask or request operations (merge, compress)...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isAiThinking ? null : () => _sendMessage(),
              icon: const Icon(Icons.send_rounded, size: 18),
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
