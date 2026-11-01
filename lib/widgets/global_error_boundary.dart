import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Global interactive error boundary and crash recovery container.
/// Catches unhandled widget build/render exceptions and displays a clean, user-friendly
/// recovery screen with 1-tap "Copy Error" and "Restart Session" actions instead of a gray crash screen.
class GlobalErrorBoundary extends StatefulWidget {
  final Widget child;

  const GlobalErrorBoundary({Key? key, required this.child}) : super(key: key);

  @override
  State<GlobalErrorBoundary> createState() => GlobalErrorBoundaryState();
}

class GlobalErrorBoundaryState extends State<GlobalErrorBoundary> {
  FlutterErrorDetails? _errorDetails;

  void reportError(FlutterErrorDetails details) {
    if (mounted) {
      setState(() {
        _errorDetails = details;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      reportError(details);
      originalOnError?.call(details);
    };
  }

  void _restartSession() {
    setState(() {
      _errorDetails = null;
    });
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _copyError() {
    final text = 'VALIXIS AI PDF Maker Exception Report\n'
        'Timestamp: ${DateTime.now().toIso8601String()}\n'
        'Exception: ${_errorDetails?.exceptionAsString()}\n\n'
        'Stack Trace:\n${_errorDetails?.stack}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Error report copied to clipboard.'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
      final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
      final textColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
      final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

      return Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 34,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Something went wrong',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'An unexpected rendering issue occurred. Your application state has been safely isolated.',
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 140),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _errorDetails?.exceptionAsString() ?? 'Unknown error',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _copyError,
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Copy Error'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _restartSession,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Restart Session'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE03131),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}
