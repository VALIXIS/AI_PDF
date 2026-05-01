# PDF AI Toolkit - Architecture Documentation

## Project Overview

PDF AI Toolkit is an AI-first Flutter application that combines PDF manipulation with advanced AI text transformation capabilities. The app uses a clean MVC architecture with service-based dependency injection pattern.

## Architecture Principles

### 1. Separation of Concerns
- **Models**: Data structures and Hive entities
- **Views**: UI screens and widgets
- **Controllers**: Business logic and state coordination
- **Services**: External integrations and data access

### 2. Modularity
Each feature is self-contained with minimal coupling:
- AI feature has dedicated controller and service
- PDF operations handled by PDF service
- File operations isolated in file service
- Storage operations managed by storage service

### 3. Dependency Direction
```
Views → Controllers → Services → Models
```
- Views depend on Controllers
- Controllers use Services
- Services return Models
- Models have no dependencies

## Detailed Component Architecture

### Models Layer (`lib/models/`)

#### HistoryEntry
```dart
class HistoryEntry {
  final String id;           // Unique identifier
  final String title;        // User-facing title
  final DateTime date;       // Creation timestamp
  final String filePath;     // Saved file location
  final String toolType;     // Tool that created it
}
```

**Hive Integration**:
- Adapted for local storage with `HistoryEntryAdapter`
- Type ID: 0
- Enables object persistence without JSON serialization

### Views Layer (`lib/views/`)

#### Screen Hierarchy
```
HomeScreen
├── MergePdfScreen
├── SplitPdfScreen
├── TextToPdfScreen
├── AiScreen
├── AiRefineScreen
├── PdfToTextScreen
├── CompressPdfScreen
└── HistoryScreen
```

#### Common Patterns
1. **Error Handling**: All screens display error messages in red containers
2. **Loading States**: Circular progress indicators during async operations
3. **User Feedback**: SnackBars for success/completion messages
4. **Navigation**: Push-based navigation using `MaterialPageRoute`

#### AI Screen Flow
```
Input Text → Mode Selection → Preview → Generate PDF → Save to History
```

### Controllers Layer (`lib/controllers/`)

#### AiController
Responsibilities:
- Mode management (notes, summary, clean)
- Text processing orchestration
- API integration coordination
- ID generation for history entries

```dart
// Usage Example
final controller = AiController();
final result = await controller.processText(
  input: userText,
  mode: AiMode.notes,
);
```

### Services Layer (`lib/services/`)

#### 1. AI Service (`ai_service.dart`)

**Purpose**: Handles all AI-related operations

**API Integration**:
- Provider: OpenRouter
- Endpoint: `https://openrouter.ai/api/v1/chat/completions`
- Model: `mistralai/mixtral-8x7b-instruct`

**Prompt Templates**:
```dart
buildNotesPrompt(input)      → Structured notes format
buildSummaryPrompt(input)    → Concise summary
buildCleanPrompt(input)      → Polished and refined text
```

**Error Handling**:
- Network failures → Mock response
- API errors → Mock response with fallback
- Empty input → Exception throw

#### 2. PDF Service (`pdf_service.dart`)

**Core Methods**:
```dart
generatePdfFromText(title, content)  // Main PDF generator
mergePdfs(paths)                     // Combine PDFs
splitPdf(path, start, end)           // Extract pages
compressPdf(path)                    // Placeholder compression
```

**PDF Structure**:
- Title (24pt, bold)
- Metadata (timestamp)
- Content parsing:
  - `# ` → Header 1
  - `## ` → Header 2
  - `• ` or `- ` → Bullet points
  - Regular text → Body

#### 3. File Service (`file_service.dart`)

**Operations**:
```dart
pickPdfFile()              // Single file selection
pickMultiplePdfFiles()     // Multiple file selection
pickTextFile()             // Text file selection
readTextFile(path)         // Read file contents
readPdfInfo(path)          // Extract file metadata
fileExists(path)           // Check file existence
deleteFile(path)           // Remove file
getFileName(path)          // Extract filename
```

**File Picker Integration**:
- Uses `file_picker` package
- Android + iOS support
- User-friendly file dialogs

#### 4. Storage Service (`storage_service.dart`)

**CRUD Operations**:
```dart
addHistoryEntry(entry)           // Create
getHistoryEntry(id)              // Read single
getAllHistoryEntries()           // Read all
updateHistoryEntry(entry)        // Update
deleteHistoryEntry(id)           // Delete
clearAllHistory()                // Delete all
```

**Query Methods**:
```dart
getHistoryEntriesSortedByDate()  // Chronological order
getHistoryEntriesByType(type)    // Filter by tool
getHistoryCount()                // Count entries
```

**Hive Integration**:
- Box name: `'historyBox'`
- Initialization: `Hive.openBox<HistoryEntry>('historyBox')`
- Adapter registration: `Hive.registerAdapter(HistoryEntryAdapter())`

## Data Flow Examples

### AI to PDF Flow
```
1. User enters text in AiScreen
2. AiScreen calls AiController.processText()
3. Controller calls AiService with selected prompt
4. AiService sends HTTP request to OpenRouter API
5. API response returned (or mock response on error)
6. Preview displayed to user
7. User clicks "Generate PDF"
8. PdfService.generatePdfFromText() creates PDF
9. PDF saved to device storage
10. HistoryEntry created with metadata
11. StorageService.addHistoryEntry() saves to Hive
12. SnackBar confirms success
```

### File Merge Flow
```
1. User navigates to MergePdfScreen
2. Clicks "Add PDFs" → FileService.pickMultiplePdfFiles()
3. User selects multiple files
4. Files displayed in list
5. User clicks "Merge"
6. PdfService.mergePdfs(filePaths) combines files
7. Output PDF saved to device
8. HistoryEntry created and stored
9. User notified of completion
```

## State Management Strategy

### Current Approach
- **StatefulWidget** with `setState()`
- Single responsibility per screen
- Service calls trigger rebuilds

### Pattern Example
```dart
class AiScreen extends StatefulWidget {
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  // State variables
  String _selectedMode = AiMode.notes;
  String? _previewText;
  bool _isLoading = false;
  String? _errorMessage;

  // State updates
  Future<void> _handlePreview() async {
    setState(() => _isLoading = true);
    // ... async work ...
    setState(() => _previewText = result);
  }
}
```

### Scaling Recommendations
For larger applications, migrate to:
- **Provider**: Simple and clean
- **Riverpod**: Type-safe Provider alternative
- **Bloc**: Complex state management
- **Getx**: All-in-one state management

## Error Handling Strategy

### Three-Tier Approach
1. **UI Level**: Display error messages to user
2. **Service Level**: Log errors and return fallbacks
3. **Controller Level**: Coordinate error resolution

### Error Message Locations
- UI: Container with red background
- User Feedback: SnackBar notifications
- Debugging: Console logs (during development)

## Testing Strategy

### Unit Tests (Services)
```dart
test('AI service returns formatted response', () async {
  final service = AiService();
  final result = await service.callAi('test prompt');
  expect(result, isNotEmpty);
});
```

### Widget Tests (Screens)
```dart
testWidgets('AI screen displays input field', (WidgetTester tester) async {
  await tester.pumpWidget(const PdfAiToolkitApp());
  expect(find.byType(TextField), findsWidgets);
});
```

### Integration Tests
- Test full flow from home → AI → PDF generation
- Verify history storage
- Check file operations

## Performance Considerations

### Optimization Techniques
1. **Lazy Loading**: History items loaded on demand
2. **Pagination**: Consider for large histories
3. **Caching**: Cache API responses
4. **Memory**: Dispose controllers and controllers properly
5. **Image Assets**: Optimize vector icons

### Potential Bottlenecks
- Large PDF generation: 100+ pages
- API latency: Network-dependent
- Hive queries: Large history (1000+ entries)

## Security Best Practices

1. **API Key Management**:
   - Never hardcode in public repos
   - Use environment variables
   - Implement key rotation

2. **File Handling**:
   - Validate file paths
   - Check file permissions
   - Sanitize filenames

3. **User Data**:
   - History stored locally only
   - No personal data transmission
   - Secure storage for sensitive files

4. **API Communication**:
   - Use HTTPS only
   - Validate SSL certificates
   - Implement request signing

## Deployment Considerations

### Release Checklist
- [ ] API key properly configured
- [ ] Error messages reviewed
- [ ] Performance tested
- [ ] Memory leaks checked
- [ ] Permissions verified
- [ ] Versioning updated

### App Store Requirements
- [ ] Privacy policy
- [ ] Terms of service
- [ ] Data collection disclosure
- [ ] Testing on multiple devices
- [ ] Accessibility compliance

## Extensibility

### Adding a New Tool

1. **Create Screen** (`lib/views/tools/new_tool_screen.dart`):
```dart
class NewToolScreen extends StatefulWidget {
  @override
  State<NewToolScreen> createState() => _NewToolScreenState();
}
```

2. **Add Service Method** (`lib/services/`):
```dart
Future<String> newTool(parameters) async {
  // Implementation
}
```

3. **Update Home Screen**:
```dart
ToolTile(
  title: 'New Tool',
  icon: Icons.new_icon,
  screen: const NewToolScreen(),
)
```

4. **Add History Type**:
```dart
toolType: 'new_tool',
```

## Monitoring & Debugging

### Debug Features
- Console logging in services
- Error stack traces
- Loading indicators
- Network request inspection

### Production Monitoring
- Crash reporting (Firebase)
- Analytics (Firebase)
- Error tracking (Sentry)
- Performance monitoring

---

## Summary

The PDF AI Toolkit architecture provides:
- ✅ Clear separation of concerns
- ✅ Testable components
- ✅ Scalable structure
- ✅ Easy feature additions
- ✅ Comprehensive error handling
- ✅ Modern Flutter patterns

This foundation enables smooth development and maintenance of the application.
