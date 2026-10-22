# VALIXIS AI PDF Maker (PDF AI Toolkit)

[![CI/CD Pipeline](https://github.com/VALIXIS/AI_PDF/actions/workflows/ci.yml/badge.svg)](https://github.com/VALIXIS/AI_PDF/actions)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![AI Engine](https://img.shields.io/badge/AI-Gemini%20Flash%20%2B%20Hugging%20Face-FFD21E)](https://ai.google.dev)
[![Storage](https://img.shields.io/badge/Storage-Hive%20NoSQL-F89820)](https://pub.dev/packages/hive)
[![Tests](https://img.shields.io/badge/Tests-356%2F356%20Passing-brightgreen)](https://github.com/VALIXIS/AI_PDF)
[![License: Proprietary](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)

**VALIXIS AI PDF Maker** is an enterprise-grade document intelligence and PDF transformation suite in the **VALIXIS Enterprise Suite**. Engineered for high-throughput mobile, desktop, and web environments, it combines Gemini Flash and Hugging Face language models with local client-side PDF vector rendering, interactive signature overlays, and NoSQL document persistence.

---

## Key Capabilities

### AI Document Synthesis & Refinement
* **AI to PDF Generation**: Restructures unformatted raw transcripts, notes, and outlines into publication-ready, beautifully styled PDF documents.
  * **Structured Notes**: Key takeaways, conceptual hierarchies, and bulleted checklists.
  * **Executive Summaries**: Distills high-volume reports into concise executive briefings.
  * **Clean Text Mode**: Fixes grammar, corrects punctuation, removes OCR artifacts, and polishes styling.
* **AI Text Refiner**: Paraphrasing, tone shifting (Academic, Professional, Concise), and cleanup prior to export.
* **Hermetic Fallback**: Automated fallback to deterministic mock generators in offline or test environments.

### Complete PDF Manipulation Engine
* **Interactive Signature & Stamp Overlay**: Multi-touch vector signature pad with drag, resize, rotate, and placement verification.
* **Merge & Split Operations**: Reorder and combine disparate documents or extract arbitrary page ranges with memory optimization.
* **Vector Text-to-PDF**: Direct vector layout rendering with custom font weights, line spacing, margins, and headers.
* **PDF to Text Extraction**: High-fidelity text and metadata extraction from native and scanned PDFs.
* **Intelligent Compression**: Optimizes embedded image streams and flattens redundant XObjects.

### Local Privacy-First Document Vault
* **Hive NoSQL Storage**: Fast local indexing of document titles, page counts, checksums, and storage paths.
* **Built-in Viewer & Share Sheet**: Document visualizer with gesture zooming, printing, and platform share sheets.
* **Zero Cloud Lock-In**: Complete local offline capability; external AI calls are strictly optional and configurable.

---

## System Architecture

```
+-----------------------------------------------------------------------------+
|                            VALIXIS AI PDF MAKER                             |
|                                                                             |
|  +--------------------+   +-----------------------+   +-------------------+ |
|  | Input Ingestion    |   | Clean MVC UI Layer    |   | AI Synthesis      | |
|  | - File Picker      |-->| - Document Viewer     |<--| - Gemini Flash    | |
|  | - Camera Scanner   |   | - Signature Pad       |   | - Hugging Face    | |
|  | - Text / Clipboard |   | - Form Filler Tools   |   | - Offline Mock    | |
|  +--------------------+   +-----------------------+   +-------------------+ |
|            |                          |                         |           |
|            v                          v                         v           |
|  +------------------------------------------------------------------------+ |
|  |               Document Manipulation & Vector PDF Engine                | |
|  |      (dart_pdf vector layout, compression, merge/split, stamps)        | |
|  +------------------------------------------------------------------------+ |
|                                       ^                                     |
|                                       | Local Persistence                   |
|                                       v                                     |
|  +------------------------------------------------------------------------+ |
|  |                   Hive NoSQL Document Vault & Cache                    | |
|  +------------------------------------------------------------------------+ |
+-----------------------------------------------------------------------------+
```

---

## Directory Structure

```
AI_PDF_MAKER/
├── .devcontainer/                  # VS Code & Codespaces hermetic container
├── .github/
│   └── workflows/
│       ├── ci.yml                 # Enterprise CI/CD pipeline (gitleaks, lint, test, build)
│       └── valixis_gatekeeper.yml # PR gatekeeper automation
├── lib/
│   ├── models/                    # HistoryEntry and metadata contracts
│   ├── services/                  # AI, PDF processing, compression & analytics
│   ├── views/
│   │   ├── history/               # Document vault and history viewer
│   │   ├── settings/              # API keys and app preference screens
│   │   ├── tools/                 # Merge, Split, Signature, Form Filler screens
│   │   └── viewer/                # Embedded PDF document visualizer
│   └── main.dart                  # Top-level entry point with PlatformDispatcher telemetry
├── test/
│   ├── services/                  # Unit and performance benchmark tests
│   └── tool_screens_demo_test.dart# End-to-end PDF manipulation tests
├── Dockerfile                     # Multi-stage hermetic web build
├── docker-compose.yml             # Local evaluation stack
├── nginx.conf                     # Production SPA routing & security headers
├── pubspec.yaml                   # Dependency specification
└── analysis_options.yaml          # Strict linting & static analysis rules
```

---

## Environment Variables

| Variable | Description | Required | Default |
| :--- | :--- | :---: | :--- |
| `GEMINI_API_KEY` | Google Gemini API key for AI generation | No | Offline mock fallback |
| `HF_API_KEY` | Hugging Face inference token for fallback LLMs | No | Offline mock fallback |
| `ENVIRONMENT` | Runtime environment mode | No | `production` |
| `PORT` | Container binding port for Nginx web server | No | `80` (mapped to `8085`) |

---

## Quickstart

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.24.0`)
- [Dart SDK](https://dart.dev/get-dart) (`>= 3.5.0`)
- [Docker & Docker Compose](https://www.docker.com/) (optional)

### Clean-Clone Setup & Local Run

```bash
# Clone the repository
git clone https://github.com/VALIXIS/AI_PDF.git
cd AI_PDF_MAKER

# Install dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome

# Run on Android / iOS
flutter run
```

### Running with Docker

```bash
# Build and launch the container
docker compose up -d --build

# Access the application at http://localhost:8085
```

---

## Testing & Coverage

Run the complete hermetic test suite:

```bash
# Run all 356 automated tests
flutter test

# Generate lcov coverage report
flutter test --coverage

# Run static analysis
dart analyze lib
```

All 356 tests execute offline with zero external network or cloud dependencies.

---

## License

Proprietary © VALIXIS. All rights reserved.
