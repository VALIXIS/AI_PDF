<!-- markdownlint-disable -->

# PDF AI Toolkit

A feature-rich Flutter mobile application for PDF manipulation and AI-powered text transformation.

## Features

### Core Tools
- **AI to PDF** - Transform text using AI into formatted PDFs (Notes, Summary, Clean modes)
- **AI Refine** - Polish and enhance text with AI capabilities
- **Text to PDF** - Convert plain text into beautifully formatted PDFs
- **Merge PDF** - Combine multiple PDF files into one
- **Split PDF** - Extract specific page ranges from PDFs
- **PDF to Text** - Extract text content from PDFs
- **Compress PDF** - Reduce PDF file sizes
- **History** - Access and manage all generated PDFs

## Architecture

The project follows a clean **MVC (Model-View-Controller)** architecture:

```
lib/
├── models/                 # Data models
│   └── history_entry.dart
├── views/                  # UI screens
│   ├── home/
│   │   └── home_screen.dart
│   ├── ai/
│   │   └── ai_screen.dart
│   ├── tools/
│   │   ├── merge_pdf_screen.dart
│   │   ├── split_pdf_screen.dart
│   │   ├── text_to_pdf_screen.dart
│   │   ├── pdf_to_text_screen.dart
│   │   ├── compress_pdf_screen.dart
│   │   └── ai_refine_screen.dart
│   └── history/
│       └── history_screen.dart
├── controllers/            # Business logic
│   └── ai_controller.dart
├── services/              # API and database layer
│   ├── ai_service.dart
│   ├── pdf_service.dart
│   ├── file_service.dart
│   └── storage_service.dart
└── main.dart             # App entry point
```

## Setup & Installation

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK (3.0+)
- Android Studio / Xcode (for emulator)

### Installation Steps

1. **Get Flutter dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run code generation (for Hive adapters):**
   ```bash
   flutter pub run build_runner build
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

## Dependencies

- **pdf** (3.10.0) - PDF generation
- **printing** (5.11.0) - PDF printing
- **file_picker** (6.1.0) - File selection
- **path_provider** (2.1.0) - Device path access
- **hive** (2.2.3) - Local storage
- **hive_flutter** (1.1.0) - Flutter Hive integration
- **http** (1.1.0) - HTTP networking
- **uuid** (4.0.0) - Unique ID generation
- **intl** (0.19.0) - Internationalization

## Key Components

### Models (`lib/models/`)
- **HistoryEntry** - Stores metadata for generated PDFs

### Services (`lib/services/`)

#### AI Service (`ai_service.dart`)
- Integrates with OpenRouter API for AI capabilities
- Three prompt builders:
  - `buildNotesPrompt()` - Structured notes format
  - `buildSummaryPrompt()` - Concise summaries
  - `buildCleanPrompt()` - Text refinement
- Mock response fallback for testing without API key

#### PDF Service (`pdf_service.dart`)
- `generatePdfFromText()` - Create PDFs from formatted text
- `mergePdfs()` - Combine multiple PDFs
- `splitPdf()` - Extract page ranges
- `compressPdf()` - Reduce file size

#### File Service (`file_service.dart`)
- File picker integration
- File reading and metadata extraction
- File deletion

#### Storage Service (`storage_service.dart`)
- Hive-based local storage
- History CRUD operations
- Query by date and tool type

### Controllers (`lib/controllers/`)

#### AI Controller (`ai_controller.dart`)
- `processText()` - Calls AI service with selected mode
- Mode management (Notes, Summary, Clean)
- ID generation

## Configuration

### API Key Setup
To use the AI features with real API responses:

1. Get an API key from [OpenRouter](https://openrouter.ai)
2. Open `lib/services/ai_service.dart`
3. Replace `'YOUR_API_KEY'` with your actual key:
   ```dart
   static const String _apiKey = 'sk-...'; // Your API key
   ```

Without an API key, the app uses mock responses for demonstration.

## Design System

The app uses **Material 3 design** with:
- Dynamic color theming based on system settings
- Consistent card-based layouts
- Accessible error messaging
- Loading indicators for async operations
- Clean typography hierarchy

## UI Features

### Home Screen
- 8-tool grid layout
- Featured highlight for "AI to PDF" tool
- Material 3 cards with descriptions

### AI Screens
- Large text input fields
- Mode selection (filter chips)
- Preview functionality
- Real-time error handling
- Loading states

### History Screen
- Chronological list of generated PDFs
- Tool type badges
- Quick actions (share, delete)
- Clear history option

## Error Handling

The app implements comprehensive error handling:
- Try-catch blocks for all async operations
- User-friendly error messages
- Graceful fallbacks
- Loading indicators
- Validation for empty inputs

## State Management

The app uses **StatefulWidget** for state management with:
- Local widget state for UI control
- Service-based data flow
- Reactive updates

For larger apps, consider migrating to Provider, Riverpod, or Bloc.

## Running Tests

To run tests (if added):
```bash
flutter test
```

## Building for Production

### iOS
```bash
flutter build ios
```

### Android
```bash
flutter build apk
```

### Web
```bash
flutter build web
```

## Known Limitations

1. **PDF Text Extraction** - Requires additional libraries for advanced text extraction
2. **PDF Merge/Split** - Basic implementation; advanced features require `pdf_service` enhancement
3. **API Rate Limiting** - OpenRouter API has rate limits; implement caching for production
4. **File Sharing** - Can be enhanced with `share_plus` package

## Future Enhancements

- [ ] Advanced PDF text extraction
- [ ] Batch processing
- [ ] File sharing via share_plus
- [ ] OCR capabilities
- [ ] Cloud storage integration
- [ ] Offline mode
- [ ] Multi-language support
- [ ] Advanced compression algorithms

## Troubleshooting

### Hive Initialization Errors
```
Unregistered TypeId
```
Solution: Run `flutter pub run build_runner build`

### File Picker Issues
- Ensure permissions in AndroidManifest.xml
- Check iOS Info.plist for document permissions

### API Connection Issues
- Verify API key is correct
- Check internet connectivity
- Review OpenRouter API documentation

## License

This project is open source and available under the MIT License.

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review Flutter documentation
3. Check OpenRouter API docs for AI-related issues

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Commit changes with clear messages
4. Submit a pull request

---

**Happy PDF crafting!** 📄✨

<!-- markdownlint-enable -->
