# Quick Reference - Hugging Face Integration

## 🚀 Quick Start

1. Get API key: https://huggingface.co/settings/tokens
2. Open `lib/services/ai_service.dart`
3. Replace line 5: `static const String _apiKey = 'hf_YOUR_TOKEN';`
4. Run: `flutter run`

## 📝 API Service - Key Methods

### Main Method
```dart
Future<String> generateText(String input, String mode)
```
- **Modes**: `'notes'`, `'summary'`, `'clean'`
- **Returns**: Generated text or original input on error
- **Fallback**: Graceful failure (no crashes)

### Prompt Builders
```dart
buildNotesPrompt(String input)      // Study notes format
buildSummaryPrompt(String input)    // Concise summary
buildCleanPrompt(String input)      // Organized text
```

## 🎯 Controller - Usage

```dart
final result = await _aiController.processText(
  input: userText,
  mode: 'notes',  // or 'summary', 'clean'
);
```

## 🔧 Configuration

| Setting | Value |
|---------|-------|
| **Endpoint** | https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.2 |
| **Model** | Mistral-7B-Instruct-v0.2 |
| **Auth Header** | `Authorization: Bearer YOUR_HF_API_KEY` |
| **Request Field** | `inputs` (string) |
| **Response Field** | `generated_text` (in first array element) |
| **Timeout** | 30 seconds |

## 🛡️ Error Handling

| Scenario | Handling |
|----------|----------|
| No API key | Shows mock responses |
| Invalid key | Returns original input |
| Timeout | Returns original input |
| Network error | Returns original input |
| Parse error | Returns original input |

## 📊 Response Times

- First request: 30-60 seconds (model warming up)
- Cached requests: 5-15 seconds
- Very long inputs: May timeout

## 🧪 Testing Without API

Leave `_apiKey = 'YOUR_HF_API_KEY'` to see mock responses:

```dart
// Mock output for 'notes' mode
# Study Notes
## Main Concepts
• Core ideas from the material
• Key terminology explained
...
```

## 📁 Updated Files

| File | Status |
|------|--------|
| `lib/services/ai_service.dart` | ✅ Updated |
| `lib/controllers/ai_controller.dart` | ✅ Updated |
| `HF_SETUP_GUIDE.md` | ✨ New |
| `HF_MIGRATION_SUMMARY.md` | ✨ New |

## 🔗 Useful Links

- Get API key: https://huggingface.co/settings/tokens
- API Docs: https://huggingface.co/docs/api-inference
- Model: https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.2
- Status: https://huggingface.co/system-status

## ⚡ Features

✅ Hugging Face Inference API  
✅ Mistral-7B-Instruct model  
✅ 3 processing modes (notes, summary, clean)  
✅ Mock response fallback  
✅ Comprehensive error handling  
✅ 30-second timeout protection  
✅ Backward compatible  

## 🆘 Troubleshooting

**Q: App shows mock responses**
- A: Replace `YOUR_HF_API_KEY` with real token

**Q: "Unauthorized" error**
- A: Check API key is correct (copy from HF settings)

**Q: Timeout error**
- A: First request takes 30-60s, normal behavior

**Q: Model loading error**
- A: Wait a moment and try again

## 🎓 Mode Examples

### Notes Mode
```
Input: "Flutter is a mobile framework"
Output: 
# Study Notes
## Definitions
• Flutter: Mobile framework
...
```

### Summary Mode
```
Input: "Long paragraph about Flutter"
Output:
Flutter is a mobile framework for Android and iOS...
```

### Clean Mode
```
Input: "messy text with errors"
Output:
Messy text with errors → cleaned and organized
```

---

**Ready to use!** Configure your API key and start processing. 🎉
