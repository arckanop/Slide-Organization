# Slide

Slide captures and organizes photos of lecture/lesson
slides by class and capture time. It's fully on-device — no account, no network.

## Features

- **Capture** — Document Scanner (auto edge-detection, deskew, crop, multi-page) or
  a rapid multi-shot Camera mode. iOS/iPadOS only.
- **Import from Photos** — multi-select import from the photo library on every
  platform, with an optional prompt to delete the originals afterward
  (iOS/iPadOS only, since deleting Photos assets needs write access there).
- **Classes** — create/edit classes with a name, teacher, color, and note; each
  class's slides are shown in a grid grouped by capture date.
- **Timetable** — a weekly grid (weekday × period) that assigns a class to each
  period, plus an editable bell schedule. A default Thai school schedule
  (คาบ 1–8 with a lunch break) is seeded on first launch and is fully editable.
  Visible weekdays are configurable in Settings.
- **Home** — resolves the "current class" from the timetable and the time of
  day, surfaces one-tap capture/import shortcuts for it, and shows a strip of
  recently captured slides.
- **OCR** — Apple's on-device Vision text recognizer runs automatically on
  every captured/imported slide (English + numbers only — Vision has no Thai
  support) and feeds the search index.
- **Search** — filter slides by free text (recognized text, session title, or
  note), by class, and by a date preset (today / last 7 days / this month).
- **Viewer** — full-screen pager with pinch-to-zoom and pan, plus edit details,
  share, re-run OCR, and delete.
- **PDF export** — renders a class's slides into a single date-ordered PDF for
  exam review, ready to share.
- **Settings** — choose HEIC (full resolution) vs. JPEG (compressed, with a
  quality slider) for stored images, toggle the delete-originals-after-import
  prompt, edit visible weekdays/timetable, and see on-device storage used.

## Architecture

Single SwiftUI target (`SDKROOT = auto`) shared across iPhone, iPad, Mac, and
visionOS. Platform-only features (Document Scanner, Camera, deleting Photos
assets) are gated with `#if os(iOS)` rather than split into separate targets.

- **Models** (SwiftData) — `ClassSubject`, `Slide`, `Period`, `TimetableCell`.
- **`FileStore`** — image bytes live on disk under `Documents/slides` and
  `Documents/thumbs`; SwiftData only ever stores filenames.
- **`ImageProcessing`** — decode/resize/encode built on Core Graphics +
  ImageIO instead of `UIImage`/`NSImage`, so the same code runs unmodified on
  every platform.
- **`OCRPipeline`** — runs Vision text recognition per slide in the
  background and debounces the resulting SwiftData saves so a multi-page
  capture batch collapses into one save instead of one per slide.
- **`AsyncDiskImage`** — shared `NSCache` plus ImageIO downsampled decoding;
  thumbnails and unzoomed viewer pages decode at display size, and only the
  page the user has actually pinch-zoomed decodes at full resolution.
- **`CaptureFlow`** — the shared commit path for both capture modes and
  Photos import: turns raw page bytes into saved files + `Slide` records.

### Concurrency

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types are implicitly
  `@MainActor` unless explicitly annotated otherwise; background work uses
  `Task.detached` or `nonisolated` contexts.
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` — Swift 6 approachable concurrency
  mode is active.
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` — imported module
  members must be explicitly visible at the use site.

## Requirements

- Xcode with the iOS 26.2 / macOS 15.7 / visionOS 26.2 SDKs
- iOS/iPadOS 26.2+, macOS 15.7+, or visionOS 26.2+ to run

## Privacy

Slide is fully on-device — no account, no network calls. It requests:

- **Camera** — "Take photos of class slides."
- **Photo Library (read)** — "Import slide photos and optionally remove the
  originals."
- **Photo Library (add)** — "Save slide captures to your photo library."

## Project Structure

```
Slide/
├── Capture/        Document Scanner, Camera, capture sheet, shared commit flow
├── Importing/      Photos library import
├── Features/
│   ├── Home/       Current-class resolution, quick actions, recents
│   ├── Classes/     Class list, editor, per-class slide grid + PDF export
│   ├── Search/      Text/class/date filtering across all slides
│   ├── Settings/    Image format, import prompt, timetable, storage
│   ├── Timetable/   Weekly grid + bell schedule editor
│   └── Viewer/      Full-screen pager with zoom/pan
├── Models/          SwiftData models
├── Services/        FileStore, OCRPipeline/OCRService, CurrentClassResolver, PhotoLibrary
└── Support/         ImageProcessing, AsyncDiskImage, AppSettings, PDFExporter, etc.
```
