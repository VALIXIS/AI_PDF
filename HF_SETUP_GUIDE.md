# Hugging Face API Integration Guide

## Overview

The PDF AI Toolkit has been updated to use **Hugging Face Inference API** instead of OpenRouter. This guide explains how to set up and use the new AI service.

## API Configuration

### Step 1: Get Your Hugging Face API Key

1. Visit [Hugging Face Settings → Tokens](https://huggingface.co/settings/tokens)
2. Sign in or create an account
3. Click "New token" button
4. Give your token a name (e.g., "PDF AI Toolkit")
5. Select "Read" access
6. Copy the generated token

### Step 2: Add API Key to the App

Open `lib/services/ai_service.dart` and replace `YOUR_HF_API_KEY`:

```dart
static const String _apiKey = 'hf_YOUR_ACTUAL_TOKEN_HERE';
```

**Example:**
```dart
static const String _apiKey = 'hf_aBcDeFgHiJkLmNoPqRsTuVwXyZ123456';
```

## How It Works

### API Endpoint
```
https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.2
```

### Request Format
```json
{
  "inputs": "Your prompt text here"
}
```

### Headers
```
Authorization: Bearer YOUR_HF_API_KEY
Content-Type: application/json
```

### Response Format
```json
[
  {
    "generated_text": "Generated response here"
  }
]
```

## AI Service Methods

### Main Method: `generateText()`

```dart
Future<String> generateText(String input, String mode) async
```

**Parameters:**
- `input` (String) - The text to process
- `mode` (String) - One of: `'notes'`, `'summary'`, `'clean'`

**Returns:**
- String: The AI-generated text, or original input on error

**Usage:**
```dart
final aiService = AiService();
final result = await aiService.generateText(
  'Your text here',
  'notes'
);
```

### Prompt Builders

#### 1. Notes Prompt
```dart
buildNotesPrompt(String input)
```
Converts text into structured study notes with headings and bullet points.

#### 2. Summary Prompt
```dart
buildSummaryPrompt(String input)
```
Summarizes content into clear, concise exam notes.

#### 3. Clean Prompt
```dart
buildCleanPrompt(String input)
```
Cleans and organizes text without changing the meaning.

## Error Handling

The service implements three-level error handling:

### Level 1: Input Validation
```dart
if (input.isEmpty) {
  return input;  // Return empty string unchanged
}
```

### Level 2: API Error Handling
```dart
if (response.statusCode == 401) {
  throw Exception('Unauthorized: Invalid API key');
}
if (response.statusCode == 503) {
  throw Exception('Model is loading, please try again');
}
```

### Level 3: Graceful Fallback
```dart
} catch (e) {
  return input;  // Return original input on any error
}
```

## Mock Response Mode

When the API key is not configured or API calls fail:

1. The service falls back to mock responses
2. Mock responses demonstrate the expected output format
3. App continues to work without API connectivity
4. Useful for testing and development

### Triggering Mock Mode

- Leave `_apiKey` as `'YOUR_HF_API_KEY'`
- Or use invalid API key
- App will display demo responses

## AI Controller Integration

The `AiController` class handles the business logic:

```dart
Future<String> processText({
  required String input,
  required String mode,
}) async {
  // Validates input and mode
  // Calls AiService.generateText()
  // Returns AI-processed text
}
```

## Usage in Views

### Example: AI Screen

```dart
class _AiScreenState extends State<AiScreen> {
  final AiController _aiController = AiController();

  Future<void> _handlePreview() async {
    try {
      final result = await _aiController.processText(
        input: _inputController.text,
        mode: _selectedMode,
      );
      setState(() => _previewText = result);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }
}
```

## Response Timeout

The API has a **30-second timeout**:

```dart
.timeout(
  const Duration(seconds: 30),
  onTimeout: () => throw Exception('API request timeout'),
)
```

This prevents the app from hanging on slow connections.

## Common Issues & Solutions

### Issue: "Unauthorized: Invalid API key"
**Solution:**
- Verify your API key is correct
- Check for extra spaces or typos
- Re-copy from Hugging Face settings

### Issue: "Model is loading, please try again"
**Solution:**
- The Mistral model is loading on Hugging Face servers
- Wait a few seconds and try again
- First request after inactivity can take 30-60 seconds

### Issue: App shows mock responses
**Solution:**
- Verify `YOUR_HF_API_KEY` was replaced with actual token
- Check that API key is correctly formatted
- Ensure Bearer token is included in Authorization header

### Issue: Timeout errors
**Solution:**
- Check internet connection
- Try again after waiting
- Consider using VPN if Hugging Face is blocked
- Check Hugging Face status page

## Response Parsing

The service extracts text from Hugging Face's response format:

```dart
// Expected response structure
[
  {
    "generated_text": "Your processed text here"
  }
]
```

**Parsing logic:**
1. Decode JSON response
2. Check if it's a list (standard format)
3. Extract first item
4. Get `generated_text` field
5. Return as string

## Performance Considerations

### First Request
- Takes 30-60 seconds (model loading)
- This is normal for Hugging Face
- Subsequent requests are faster (5-15 seconds)

### Response Length
- Adjust input length for better performance
- Very long inputs may time out
- Recommended: 100-2000 characters

### Rate Limiting
- Hugging Face allows reasonable usage
- No hard rate limits for free tier
- Very frequent requests may be throttled

## Testing the Integration

### Step 1: Configure API Key
```dart
static const String _apiKey = 'hf_YOUR_TOKEN';
```

### Step 2: Run the App
```bash
flutter run
```

### Step 3: Test Each Mode

1. Open "AI to PDF" screen
2. Enter test text:
   ```
   The quick brown fox jumps over the lazy dog.
   This is a test sentence for note-taking functionality.
   ```

3. Select mode: **Notes**
4. Click "Preview"
5. Observe AI-generated notes

### Step 4: Try Other Modes
- **Summary**: Condenses text
- **Clean**: Polishes and organizes

## Advanced Configuration

### Custom Timeouts
Edit timeout duration in `_callHuggingFaceAPI()`:
```dart
.timeout(
  const Duration(seconds: 45),  // Increase to 45 seconds
  onTimeout: () => throw Exception('Request timeout'),
)
```

### Different Models
To use a different Hugging Face model, change `_baseUrl`:

```dart
// Option 1: Llama 2
static const String _baseUrl =
  'https://api-inference.huggingface.co/models/meta-llama/Llama-2-7b-chat';

// Option 2: GPT-2
static const String _baseUrl =
  'https://api-inference.huggingface.co/models/gpt2';

// Option 3: Zephyr
static const String _baseUrl =
  'https://api-inference.huggingface.co/models/HuggingFaceH4/zephyr-7b-beta';
```

## API Documentation

- [Hugging Face Inference API Docs](https://huggingface.co/docs/api-inference)
- [Mistral-7B-Instruct Model](https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.2)
- [Hugging Face Pricing](https://huggingface.co/pricing)

## Important Notes

1. **Free Tier**: Free Hugging Face accounts have reasonable limits
2. **Keep API Key Safe**: Don't commit API key to public repositories
3. **Environment Variables**: For production, use `.env` file with `flutter_dotenv`
4. **Rate Limits**: Monitor usage if processing many requests
5. **Model Availability**: Ensure selected model is available on Hugging Face

## Next Steps

1. ✅ Get Hugging Face API key
2. ✅ Add key to `lib/services/ai_service.dart`
3. ✅ Run `flutter run`
4. ✅ Test AI features
5. ✅ Deploy with confidence

---

**For more help:** Check Hugging Face community or Flutter documentation.
