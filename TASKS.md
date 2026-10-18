# SPRINT 2 ARCHITECTURE: CORE ENGINE & UI/UX REFINEMENT
**Sprint Window:** October 19, 2026 – October 25, 2026  
**Primary Objective:** Zero-crash, pixel-perfect stabilization, memory optimization, and Play Store hardening for AI PDF Maker.  
**Repository Target:** `VALIXIS/AI_PDF` (Remote: `https://github.com/VALIXIS/AI_PDF.git`)  
**Assigned Engineers:** Hasitha, Vaseem, Adithya  

---

## 📅 Daily Sprint Tickets (AI PDF Maker Track)

### 🔹 Hasitha (Conversion Engines & File I/O Track)
- **Day 1 (Oct 19) | [PDF-REF-01] Image-to-PDF Memory & Orientation Fix**
  - **Branch:** `feature/hasitha-pdf-img-orientation-fix` | **Priority:** Critical
  - **Scope:** Auto-detect EXIF rotation flags in input images and downscale 4K+ images in a background isolate before PDF packing to prevent memory spikes on 20+ image conversions.
  - **DOD:** Batch image conversion preserves correct camera orientation without memory overflow or jank.

- **Day 2 (Oct 20) | [PDF-REF-02] Markdown & HTML-to-PDF Styling Polish**
  - **Branch:** `feature/hasitha-pdf-md-html-styling` | **Priority:** High
  - **Scope:** Fix table border rendering, code-block syntax overflow, and font glyph clipping in generated Markdown and HTML PDFs.
  - **DOD:** Markdown and HTML conversions produce publication-grade PDFs with padded tables and wrapped code blocks.

- **Day 3 (Oct 21) | [PDF-REF-03] PDF Merge & Split State Integrity**
  - **Branch:** `feature/hasitha-pdf-merge-split-integrity` | **Priority:** High
  - **Scope:** Prevent file handle locks on Android 13+ scoped storage; preserve original document bookmarks and metadata during split/merge.
  - **DOD:** Merge and split operations release all file handles immediately and retain document metadata.

- **Day 4 (Oct 22) | [PDF-REF-04] Compression Presets Calibration**
  - **Branch:** `feature/hasitha-pdf-compression-presets` | **Priority:** High
  - **Scope:** Fine-tune JPEG compression levels and DPI subsampling (72 / 150 / 300 DPI) so text remains crisp while reducing file sizes by 40-70%.
  - **DOD:** Compression reduces PDF size by 40-70% while keeping text sharp and readable with before/after size estimations.

- **Day 5 (Oct 23) | [PDF-REF-05] Watermark & Redaction Coordinate Precision**
  - **Branch:** `feature/hasitha-pdf-watermark-redaction-fix` | **Priority:** High
  - **Scope:** Fix coordinate mapping misalignment when applying watermarks or redactions to rotated or landscape PDF pages.
  - **DOD:** Watermarks and redactions appear in the exact visual position intended regardless of page rotation.

- **Day 6 (Oct 24) | [PDF-REF-06] Corrupt & Encrypted File Defense**
  - **Branch:** `feature/hasitha-pdf-corrupt-file-defense` | **Priority:** Critical
  - **Scope:** Add graceful error dialogs and password prompt modals when loading encrypted, malformed, or 0-byte PDFs.
  - **DOD:** Zero unhandled app crashes on malformed or password-protected PDF files.

- **Day 7 (Oct 25) | [PDF-REF-07] Conversion Regression & Stress Test Suite**
  - **Branch:** `feature/hasitha-pdf-conversion-audit` | **Priority:** High
  - **Scope:** Execute full test suite across 50 sample files, verify memory stability, and eliminate all analyzer warnings.
  - **DOD:** All conversion tests pass; `flutter analyze` clean with zero critical errors.

---

### 🔹 Vaseem (Document Viewer Engine & UI Fluidity Track)
- **Day 1 (Oct 19) | [PDF-VIEW-01] High-Performance Document Viewer**
  - **Branch:** `feature/vaseem-pdf-viewer-perf` | **Priority:** Critical
  - **Scope:** Viewport-based virtualized page rendering in `pdf_document_viewer_screen.dart` so only visible pages (+1 ahead) are rendered in memory (<120MB on 100+ page files).
  - **DOD:** 100+ page PDFs scroll smoothly at 60fps with low RAM usage and zero stutter.

- **Day 2 (Oct 20) | [PDF-VIEW-02] Smooth Signature Pad & Vector Overlay**
  - **Branch:** `feature/vaseem-pdf-signature-smooth` | **Priority:** High
  - **Scope:** Cubic Bezier smoothing on signature stroke touch points with pinch/rotate/drag resizing of signature stamps on target pages.
  - **DOD:** Signatures look natural with smooth stroke edges and intuitive stamp positioning.

- **Day 3 (Oct 21) | [PDF-VIEW-03] Form Filler Touch Target & Alignment Fix**
  - **Branch:** `feature/vaseem-pdf-form-filler-alignment` | **Priority:** High
  - **Scope:** Calibrate font baseline calculation relative to standard PDF text fields with comfortable 48x48dp touch targets.
  - **DOD:** Form field text aligns perfectly within PDF boxes with comfortable tap responsiveness.

- **Day 4 (Oct 22) | [PDF-VIEW-04] In-App Cache & Temporary File Purge**
  - **Branch:** `feature/vaseem-pdf-cache-cleanup` | **Priority:** High
  - **Scope:** Implement an LRU cache eviction policy for cached page bitmaps and purge scratch export directories on viewer/tool exit.
  - **DOD:** Temporary cache files automatically deleted; app storage remains strictly under 50MB.

- **Day 5 (Oct 23) | [PDF-VIEW-05] Tool Navigation & Bottom Sheet Standardization**
  - **Branch:** `feature/vaseem-pdf-tool-shell-standardization` | **Priority:** High
  - **Scope:** Standardize all 15+ tool screens using `ToolScreenShell` with consistent back-navigation, loading skeletons, and error retry states.
  - **DOD:** Uniform look, feel, and navigation patterns across every tool screen in AI PDF.

- **Day 6 (Oct 24) | [PDF-VIEW-06] Dark Mode & Material 3 Contrast Sweep**
  - **Branch:** `feature/vaseem-pdf-m3-darkmode-contrast` | **Priority:** High
  - **Scope:** Fix unreadable text on dark backgrounds and polish icon button states using `Theme.of(context).colorScheme` tokens.
  - **DOD:** All screens display crisp, readable text and icons in both light and dark themes.

- **Day 7 (Oct 25) | [PDF-VIEW-07] UI Responsiveness & Layout Regression Test**
  - **Branch:** `feature/vaseem-pdf-ui-regression` | **Priority:** High
  - **Scope:** Verify responsive layouts on compact phones, foldables, and tablets without RenderFlex overflows.
  - **DOD:** Zero RenderFlex overflow warnings across all device dimensions; tests passing.

---

### 🔹 Adithya (Cross-App Security, Error Boundaries & Store Polish Track)
- **Day 2 (Oct 20) | [APP-HRD-02] Global Error Boundary & Crash Recovery**
  - **Branch:** `feature/adithya-crossapp-error-boundary` | **Priority:** High
  - **Scope:** Configure `FlutterError.onError` and `PlatformDispatcher.onError` with an elegant fallback screen with Restart and Copy Diagnostic buttons.
  - **DOD:** No unhandled gray screens; graceful error UI with diagnostic recovery.

- **Day 4 (Oct 22) | [APP-HRD-04] Native Share & File Intent Provider Fix**
  - **Branch:** `feature/adithya-pdf-fileprovider-fix` | **Priority:** Critical
  - **Scope:** Ensure `FileProvider` paths include cache-path and external-files-path with `FLAG_GRANT_READ_URI_PERMISSION` on share intents.
  - **DOD:** PDFs share instantly to WhatsApp, Gmail, Drive, and Bluetooth without file URI errors.

- **Day 6 (Oct 24) | [APP-HRD-06] Valixis Gatekeeper & Linter Sweep**
  - **Branch:** `feature/adithya-crossapp-gatekeeper-sweep` | **Priority:** Critical
  - **Scope:** Run `valixis_gatekeeper.py` check across AI PDF Maker. Resolve all deprecations (`withOpacity`, `activeColor`) and ensure clean pass.
  - **DOD:** Gatekeeper returns ALL VERIFICATIONS PASSED with zero warnings.

- **Day 7 (Oct 25) | [APP-HRD-07] Production Release Packaging & Smoke Test**
  - **Branch:** `feature/adithya-crossapp-release-packaging` | **Priority:** Critical
  - **Scope:** Increment version code/name, verify ProGuard rules don't strip pdf model classes, and compile clean release appbundle.
  - **DOD:** Clean production release AAB artifact ready for Google Play Store upload.
