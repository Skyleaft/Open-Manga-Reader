# Open Manga Reader - AI Agent Architecture Index & Skills Guide

> **Target Audience**: AI Agents (Antigravity, Claude, Copilot, Cursor, Gemini) & Human Developers  
> **Last Indexed**: October 2026  
> **Repository Type**: Flutter Multi-Platform Application (Android, iOS, Windows, macOS, Linux, Web)  
> **Architectural Pattern**: Pure Vertical Slice Architecture (V-Slice) + Domain-Driven Design (DDD)

---

## 🧭 System Overview & Core Philosophy

**Open Manga Reader** is a high-performance, cross-platform manga reader application built with Flutter. It interfaces with an ASP.NET Core distributed backend (`MangaScrapper.Api`), leveraging RabbitMQ for asynchronous scraping, ASP.NET Core SignalR for real-time streaming, and Firebase for authentication and push notifications.

### 📐 Non-Negotiable Architectural Rules

1. **Pure Vertical Slices (`lib/features/`)**:
   - Each feature is an autonomous slice encapsulating its own `models/`, `services/`, `controllers/`, and `presentation/` (screens + widgets).
   - **Zero Cross-Slice Imports**: A feature slice must NEVER import private components from another feature slice. If data/functionality needs to be shared, promote it to `lib/core/` (e.g., shared models in `lib/core/models/`, global services in `lib/core/services/` or registered via `GetIt`).
2. **Lean Coordinators, Focused Sub-Widgets**:
   - Screen files (`*_screen.dart`) must remain thin coordinators (under 300 lines where practical).
   - Break complex screens down into single-responsibility sub-widgets in `features/<feature>/presentation/widgets/`.
3. **High-Performance UI & Granular Rebuilds**:
   - Avoid calling `notifyListeners()` on massive state objects during high-frequency events (e.g. scroll updates, slider dragging, auto-scroll ticks).
   - Use `ValueNotifier<T>` and `ValueListenableBuilder` to isolate rebuilds to only the specific widgets that need updating (e.g. mini progress bars, page indicators, auto-scroll HUD).
4. **Offline-First & Local Storage**:
   - Large or complex datasets (chapter lists, progression, library, offline downloads, sync queues) **MUST** use `HiveStorage` (Hive CE boxes).
   - Never dump multi-megabyte payloads into `SharedPreferences` (only small scalar settings / auth tokens go to `SharedPreferences`).
5. **Resource Disposal & Clean Teardown**:
   - Every `StreamSubscription`, `Timer`, `ScrollController`, `TextEditingController`, and Dio `CancelToken` **must be cancelled/disposed** in `dispose()`.

---

## 🗂️ Project Directory & Architecture Map

```text
lib/
├── app.dart                               # Root application widget (Theme, MultiProvider, Routing)
├── firebase_options.dart                  # Firebase configuration
├── main.dart                              # Application bootstrap (Hive, DI, FCM, Protocol)
├── routes/
│   └── app_pages.dart                     # Centralized named routes & custom page transitions
│
├── core/                                  # Cross-cutting infrastructure & shared kernel
│   ├── config/
│   │   └── app_config.dart                # Dynamic Base URL & environment configuration
│   ├── constants/
│   │   └── app_colors.dart                # Color palettes, accents, background constants
│   ├── di/
│   │   └── injection.dart                 # GetIt service locator setup
│   ├── models/                            # Shared Cross-Slice DTOs
│   │   ├── chapter_page.dart              # Single chapter page DTO (URL, index, headers)
│   │   ├── manga_summary.dart             # Lightweight manga card DTO
│   │   └── paged_response.dart            # Generic pagination wrapper (items, page, total)
│   ├── network/                           # Network & HTTP Infrastructure
│   │   ├── api_config.dart                # API endpoints and route constants
│   │   ├── manga_api_service.dart         # Central Dio HTTP client, JWT, token refresh, retry
│   │   └── sync_service.dart              # Offline mutation queue & background cloud sync
│   ├── services/                          # Cross-Cutting Infrastructure Services
│   │   ├── heartbeat_service.dart         # Periodic backend health check / connectivity probe
│   │   ├── network_status_service.dart    # Real-time internet connectivity listener
│   │   ├── notification_service.dart      # Firebase Cloud Messaging & local notifications
│   │   └── window_service.dart            # Desktop window sizing, fullscreen, and persistence
│   ├── storage/
│   │   └── hive_storage.dart              # Hive CE boxes initialization and migration
│   ├── theme/
│   │   ├── app_theme.dart                 # Material light/dark theme definitions
│   │   ├── app_theme_scheme.dart          # Theme scheme enumeration and color presets
│   │   └── theme_provider.dart            # Theme state notifier (Light, Dark, OLED, System)
│   ├── utils/
│   │   ├── formatters.dart                # Date, duration, numbers, and bytes formatters
│   │   └── url_utils.dart                 # URL cleaning, CDN referer header resolution
│   └── widgets/                           # Reusable Shared UI Components
│       ├── alert_banner.dart              # Floating banner alerts & rate limit warnings
│       ├── app_bottom_nav.dart            # Main navigation bottom bar
│       ├── discover_card.dart             # Standard card for discovery grids
│       ├── manga_card.dart                # Reusable manga poster card with title & score
│       └── shimmer_box.dart               # Skeleton loading placeholder
│
└── features/                              # Pure Vertical Slices
    ├── auth/                              # Authentication Slice
    │   ├── presentation/login_screen.dart # Login UI with Google Sign-In & guest mode
    │   └── services/
    │       ├── auth_service.dart          # Firebase Auth logic & token persistence
    │       └── google_desktop_auth.dart   # PKCE OAuth loopback server for Desktop
    ├── discover/                          # Search, Scraping & Recommendation Slice
    │   ├── controllers/discover_controller.dart
    │   ├── models/                        # Filter models, query requests, scraper queue
    │   └── presentation/                  # Discover screen, search scraping, advanced recs
    ├── download/                          # Offline Chapter Download Slice
    │   ├── models/downloaded_chapter.dart # Offline chapter & file manifest models
    │   ├── presentation/                  # Download list screen & download bottom sheet
    │   └── services/download_service.dart # Concurrent downloader, Dio byte streams, storage
    ├── history/                           # Reading Progression & History Slice
    │   ├── controllers/history_controller.dart
    │   ├── models/progression.dart        # Reading progression DTO
    │   ├── presentation/history_screen.dart
    │   └── services/progression_service.dart # Local Hive cache + remote progression sync
    ├── home/                              # Home Dashboard Slice
    │   ├── controllers/home_controller.dart
    │   ├── models/trending_tab.dart
    │   └── presentation/                  # Home screen, carousel, continue reading, top manga
    ├── library/                           # User Library & Bookmarking Slice
    │   ├── controllers/library_controller.dart
    │   ├── models/library_manga.dart      # Library status enum & manga status model
    │   ├── presentation/library_screen.dart
    │   └── services/                      # LibraryService & LibraryCacheService (Hive)
    ├── main/                              # Shell & Root Navigation Slice
    │   └── presentation/main_screen.dart  # Multi-tab indexed stack controller
    ├── manga_detail/                      # Manga Details & Chapters Slice
    │   ├── controllers/manga_detail_controller.dart
    │   ├── models/manga_detail.dart       # Detailed manga metadata, chapter lists
    │   ├── presentation/                  # Detail screen, chapter tiles, split hero, recs
    │   └── services/
    │       ├── manga_detail_service.dart  # Metadata & chapter fetcher
    │       └── manga_signalr_service.dart # Live scraping progress & update streaming
    ├── reader/                            # Immersive Manga & Webtoon Reader Slice
    │   ├── controllers/reader_controller.dart # Reader engine, mode switching, precaching
    │   ├── models/reader_content.dart     # Chapter pages, navigation args, CDN headers
    │   └── presentation/                  # Reader screen, content viewport, HUD, sheets
    └── settings/                          # App Settings Slice
        ├── presentation/                  # API switcher, theme switcher, storage, updates
        └── services/                      # StorageService, UpdateService
```

---

## ⚡ Dependency Injection & Global Singletons (`injection.dart`)

All long-lived services are managed through `GetIt.instance` (`getIt`).

| Service | Lifecycle | Responsibility |
| :--- | :--- | :--- |
| `ThemeProvider` | Singleton | Manages active theme mode, color palettes, and brightness |
| `NetworkStatusService` | Singleton | Listens to `connectivity_plus` and broadcasts network availability |
| `MangaApiService` | Singleton | Authenticated Dio HTTP client, JWT injection, base URL config |
| `WindowService` | Singleton | Desktop window manager controls (min/max size, title bar, persistence) |
| `HeartbeatService` | Singleton | Periodic backend ping to detect server uptime and availability |
| `NotificationService` | Singleton | FCM token registration, topic subscription, and notification handlers |
| `MangaSignalRService` | Singleton | Real-time WebSocket connection to `/hubs/manga` |
| `ProgressionService` | Singleton | Local reading time and chapter progress tracking & sync |
| `SyncService` | LazySingleton | Offline mutation queue (enqueues failed changes, auto-replays online) |
| `LibraryService` | LazySingleton | Library CRUD operations (reading, plan to read, completed, dropped) |
| `MangaDetailService` | LazySingleton | Fetches manga details, chapters, and manages cache |
| `LibraryCacheService` | LazySingleton | Fast local Hive cache for user's manga library |
| `StorageService` | LazySingleton | Disk usage calculation, image cache eviction, downloaded chapters size |
| `DownloadService` | LazySingleton | Manages offline chapter download queue with concurrent downloads |
| `UpdateService` | LazySingleton | Checks GitHub releases / backend endpoints for new app builds |

---

## 🔌 API & Real-Time Specifications

### 1. HTTP Rest Endpoints (`MangaApiService` & `ApiConfig`)
- Standard Base URL: Configured dynamically via `AppConfig.baseUrl` (persisted in SharedPreferences).
- OpenAPI specification: Tracked in `v1.yaml`.
- Authentication: Bearer token (JWT) injected via Dio interceptor. Automatically handles Google OAuth tokens.

Key API groups:
- **Manga**: `/api/v1/manga` (Query paged, search, filters, details, recommendations).
- **Chapters**: `/api/v1/chapters` (Chapter page list, image URLs, CDN headers).
- **Scraper**: `/api/v1/scraper` (Enqueue scraping tasks, scrape status).
- **Progression**: `/api/v1/users/progression` (Read chapters, reading time seconds, page index).
- **Library**: `/api/v1/users/library` (Manga reading status, rating).
- **Users**: `/api/v1/users` (Profile, FCM device token registration).

### 2. SignalR Real-Time Streaming (`MangaSignalRService`)
- Hub Endpoint: `{baseUrl}/hubs/manga`
- Events & Streams:
  - `scrapingProgressStream`: Emits `ChapterScrapingProgress` (chapterId, mangaId, percent, status).
  - `chaptersUpdatedStream`: Emits `ChaptersUpdatedEvent` (notifies client that new chapters were scraped so chapter list refreshes automatically).
  - `progressionUpdatedStream`: Emits real-time progression changes across devices.
- Hub Groups:
  - `JoinMangaGroup(mangaId)` / `LeaveMangaGroup(mangaId)`
  - `JoinUserGroup(userId)` / `LeaveUserGroup(userId)`

---

## 💾 Storage Architecture (`HiveStorage`)

Storage uses **Hive CE** (`hive_ce_flutter`). The five primary boxes:

| Box Name | Constant | Stored Content |
| :--- | :--- | :--- |
| `sync_queue` | `HiveStorage.syncQueueBoxName` | Offline mutations queued when device is disconnected |
| `manga_detail_cache` | `HiveStorage.mangaDetailBoxName` | Cached full `MangaDetail` JSON payloads |
| `manga_library` | `HiveStorage.libraryBoxName` | User's library manga list with statuses |
| `manga_progression` | `HiveStorage.progressionBoxName` | Reading history, current chapter, page offset, time spent |
| `downloaded_chapters`| `HiveStorage.downloadsBoxName` | Manifest of downloaded chapters stored on local disk |

> **Crucial Rule**: Never store binary image data directly inside Hive boxes. Store image files in the local filesystem via `path_provider` and only record relative/absolute file paths and metadata in Hive.

---

## 📖 Reader Engine Deep-Dive (`lib/features/reader/`)

The Reader is the most performance-sensitive component in the application:

1. **Viewing Modes**:
   - **Webtoon Mode**: Continuous vertical `ListView.builder` with physics optimized for touch and mouse wheel.
   - **Paged Mode**: Horizontal `PageView` supporting **Left-to-Right (LTR)** and **Right-to-Left (RTL Manga)**.
2. **Ahead-of-Time (AOT) Image Precaching**:
   - `ReaderController` proactively precaches adjacent pages (current page ± 3 pages) into Flutter's `PaintingBinding.instance.imageCache` to eliminate scroll stutter.
3. **CDN Referer & Header Handling**:
   - Many manga CDNs block requests without proper `Referer` or `User-Agent` headers.
   - `AppNetworkImage` passes CDN headers extracted from `ReaderContent.cdnHeaders` to both `cached_network_image_ce` and `flutter_cache_manager`.
4. **Desktop Hotkeys & Navigation**:
   - `W` / `S` or `↑` / `↓`: Vertical scrolling in Webtoon mode.
   - `A` / `D` or `←` / `→`: Page flip in Paged mode (reverses direction automatically in RTL mode).
   - `[` / `]`: Navigate to previous / next chapter.
   - `F`: Toggle window fullscreen (`WindowService`).
   - `Space`: Toggle hands-free auto-scroll.
   - `Esc`: Exit fullscreen or dismiss reader overlay.
5. **Auto-Scroll Engine**:
   - Managed via a continuous `Timer.periodic` driving smooth pixel offsets via `ScrollController.animateTo` with an adjustable multiplier (`_autoScrollSpeed`).

---

## 🛠️ Developer & Agent Workflows (Runbooks)

### Runbook 1: Adding a New Field to a Model
1. If the model is cross-slice (e.g. `MangaSummary`, `ChapterPage`), update `lib/core/models/`.
2. If the model belongs to a single slice (e.g. `LibraryManga`, `DownloadedChapter`), update `lib/features/<feature>/models/`.
3. Provide `fromJson`, `toJson`, and `copyWith` methods.
4. Update corresponding unit tests in `test/` (e.g. `test/core/models/` or `test/features/<feature>/models/`).

### Runbook 2: Adding a New REST API Endpoint
1. Verify endpoint definition in `v1.yaml`.
2. Add the endpoint URL path constant in `lib/core/network/api_config.dart`.
3. Implement the network call in `lib/core/network/manga_api_service.dart` (or the feature service) utilizing `_dio`.
4. Handle error boundaries and wrap responses in `ApiResponse<T>` or model deserializers.

### Runbook 3: Creating a New Feature Slice
To create a new feature slice `xyz`:
```text
lib/features/xyz/
├── models/                     # Data classes and DTOs
├── services/                   # APIs, database access, background workers
├── controllers/                # ChangeNotifier / State controllers
└── presentation/
    ├── xyz_screen.dart         # Main screen coordinator
    └── widgets/                # Sub-widgets
```
1. Register any long-lived service in `lib/core/di/injection.dart`.
2. Register the screen in `lib/routes/app_pages.dart` (`AppRoutes`).
3. Add navigation hooks or deep links.

### Runbook 4: Debugging & Running Tests
Execute unit and widget tests:
```powershell
flutter test
```
Run a specific feature test:
```powershell
flutter test test/features/reader/controllers/reader_controller_test.dart
```

---

## ⚠️ Common Pitfalls & Antipatterns to Avoid

- **Do NOT inject `BuildContext` into controllers or services**: Keep controllers decoupled from UI elements.
- **Do NOT block the main UI thread with heavy JSON decoding**: Use `compute` or Dio's `BackgroundTransformer` (already configured in `MangaApiService`).
- **Do NOT create memory leaks in the Reader**: Always cancel `_chapterCancelToken`, dispose `_debounceTimer`, and remove listeners in `ReaderController.dispose()`.
- **Do NOT assume network connectivity**: Always wrap API updates with fallback to `SyncService.enqueueAction` when mutations need to persist offline.
- **Do NOT hardcode colors**: Use `Theme.of(context)` or `AppColors` to ensure seamless Dark, Light, and OLED theme transitions.

