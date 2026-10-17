# 📄 PDF AI Toolkit (AI PDF Maker)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![AI Engine](https://img.shields.io/badge/Hugging%20Face-Inference%20API-FFD21E?logo=huggingface&logoColor=black)](https://huggingface.co)
[![Storage](https://img.shields.io/badge/Hive-NoSQL%20Storage-F89820)](https://pub.dev/packages/hive)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**PDF AI Toolkit** is a modern, cross-platform Flutter mobile application designed for intelligent document transformation and PDF file manipulation. It integrates Hugging Face Inference models with local client-side processing to convert raw unformatted text into styled, professional PDF notes, executive summaries, and cleaned-up transcripts, while providing a suite of offline PDF utility tools.

---

## 🌟 Key Features

### 🤖 AI-Powered Document Creation
* **AI to PDF**: Intelligently restructures unformatted text into styled, publication-ready PDF documents.
  * **Structured Notes Mode**: Synthesizes notes with key takeaways, conceptual outlines, and highlighted bullet lists.
  * **Executive Summary Mode**: Distills verbose essays and articles into crisp, high-level summaries.
  * **Clean Text Mode**: Fixes grammar, corrects punctuation, removes OCR artifacts, and polishes formatting.
* **AI Text Refiner**: Real-time AI paraphrasing, tone shifting (Academic, Professional, Concise), and cleanup prior to export.
* **Graceful Mock Fallback**: Includes simulated AI generation for offline testing or environments without active API tokens.

### 🛠️ PDF Manipulation Suite
* **Merge PDFs**: Combine multiple disparate PDF files into a single consolidated document with drag-and-drop reordering.
* **Split PDFs**: Extract custom page ranges or individual leaves into distinct files.
* **Text to PDF**: Direct vector rendering of raw text into formatted PDFs with custom typography, margins, and headings.
* **PDF to Text Extraction**: Extract and preview textual content directly from imported PDF files.
* **Compress PDF**: Optimize embedded image assets and compress document structures to minimize file size for sharing.

### 💾 Local Document History & Management
* **Instant Storage**: Backed by **Hive NoSQL**, storing PDF titles, file sizes, creation timestamps, and file system paths.
* **In-App PDF Viewer & Printing**: Built-in visualizer with native Android/iOS print dialogs and system share sheets.
* **Zero Cloud Lock-In**: All document processing occurs either directly in memory or through private API tokens.

---

## 🏛️ Architecture & Clean MVC

The codebase adheres strictly to the **Model-View-Controller (MVC)** architectural design pattern:

```
lib/
├── controllers/            # Reactive state management and business logic
│   └── ai_controller.dart  # Manages prompt dispatch, loading states, and error handling
├── models/                 # Data entities & Hive type adapters
│   ├── history_entry.dart  # Model for generated PDF metadata
│   └── history_entry.g.dart# Generated Hive adapter
├── services/               # Core domain engines and device I/O
│   ├── ai_service.dart     # Hugging Face Inference API client & fallback handlers
│   ├── file_service.dart   # File picker, cross-platform paths, and storage permissions
│   ├── pdf_service.dart    # PDF document builder (pdf & printing packages)
│   └── storage_service.dart# Hive box lifecycle, CRUD operations, and caching
├── views/                  # User Interface screens and dialogs
│   ├── ai/                 # AI prompt input and generation preview screens
│   ├── history/            # Saved PDF history list with swipe-to-delete
│   ├── home/               # Central tool dashboard and navigation
│   └── tools/              # Merge, split, compress, and conversion screens
└── main.dart               # App initialization, service locators, and Hive bootstrap
```

---

## 🚀 Getting Started

### Prerequisites
* **Flutter SDK**: Version `3.0.0` or higher ([Install Flutter](https://flutter.dev/docs/get-started/install))
* **Dart SDK**: Version `3.0.0` or higher
* **Android Studio** or **VS Code** with Flutter & Dart extensions
* **Java Development Kit (JDK 17+)** & Android SDK (for Android builds)

### Installation Steps

1. **Clone the Repository**
   ```bash
   git clone https://github.com/VALIXIS/AI_PDF.git
   cd AI_PDF
   ```

2. **Install Flutter Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables**
   Create a `.env` file in the project root based on `.env.example`:
   ```bash
   cp .env.example .env
   ```
   Provide your Hugging Face API Token (optional for mock mode, required for live AI):
   ```env
   HF_API_KEY=your_hugging_face_token_here
   HF_MODEL_ID=mistralai/Mistral-7B-Instruct-v0.2
   ```

4. **Generate Hive Adapters**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

5. **Run the Application**
   ```bash
   # Run on connected Android device or emulator
   flutter run
   ```

---

## 📦 Key Dependencies

| Package | Version | Description |
| :--- | :--- | :--- |
| [`pdf`](https://pub.dev/packages/pdf) | `^3.10.0` | Vector PDF document creation and canvas layout |
| [`printing`](https://pub.dev/packages/printing) | `^5.11.0` | Native platform printing, preview, and rasterization |
| [`hive_flutter`](https://pub.dev/packages/hive_flutter) | `^1.1.0` | Lightweight, blazingly fast local key-value database |
| [`file_picker`](https://pub.dev/packages/file_picker) | `^11.0.2` | Native system file selector for PDFs and documents |
| [`path_provider`](https://pub.dev/packages/path_provider) | `^2.1.0` | Platform directory path resolution (Documents, Cache) |
| [`http`](https://pub.dev/packages/http) | `^1.1.0` | HTTP requests to Hugging Face Inference REST endpoints |
| [`intl`](https://pub.dev/packages/intl) | `^0.19.0` | Date formatting and locale-aware string helpers |

---

## 🧪 Testing & Quality

To run unit and widget tests:
```bash
flutter test
```

To run static analysis and lint checks:
```bash
flutter analyze
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
