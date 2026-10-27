---
name: project-architecture
description: >-
  Use this skill to navigate, understand, and modify the Open Manga Reader Flutter codebase.
  Provides the architectural blueprint, vertical slice index, dependency injection map,
  data flow conventions, and runbooks for building features without breaking patterns.
---

# Open Manga Reader - Project Architecture Skill

When working on this codebase, always consult the complete architectural index:
[skills.md](../../skills.md)

## Core Architectural Rules

1. **Pure Vertical Slice Architecture (V-Slice)**:
   - Slices in `lib/features/` are self-contained (`models/`, `services/`, `controllers/`, `presentation/`).
   - Slices must NEVER import from other slices. Common logic or shared DTOs belong in `lib/core/`.
2. **Dependency Injection**:
   - Register services in `lib/core/di/injection.dart` using `GetIt.instance`.
3. **High-Performance UI**:
   - High frequency updates (scroll, slider, auto-scroll) must use `ValueNotifier<T>` to avoid full-screen rebuilds.
4. **Storage & Offline-First**:
   - Use `HiveStorage` (`hive_ce_flutter`) for complex data (library, history, downloads, sync queue).
   - Use `SyncService` to enqueue mutations when offline.
5. **Reader Engine**:
   - Webtoon (continuous vertical) and Paged (horizontal LTR/RTL) modes.
   - Always handle CDN Referer headers via `AppNetworkImage` and `ReaderContent.cdnHeaders`.

