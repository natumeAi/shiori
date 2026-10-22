---
name: flutter-data-layer
description: freezed models, json_serializable config, Dio repositories, environment config
paths:
  - lib/features/*/data/**
  - lib/core/network/**
  - lib/core/config/**
  - build.yaml
  - config/**
---

# Data Layer

> Data comes from a remote HTTP API. `dio` does the transport, `freezed` +
> `json_serializable` define models, one repository per feature exposes typed methods.

---

## Models

One model per file in `features/<feature>/data/models/`. Always freezed,
always immutable.

```dart
// lib/features/bookmarks/data/models/bookmark.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bookmark.freezed.dart';
part 'bookmark.g.dart';

@freezed
abstract class Bookmark with _$Bookmark {
  const factory Bookmark({
    required String id,
    required String title,
    required Uri url,
    required DateTime createdAt,
    String? note,
  }) = _Bookmark;

  factory Bookmark.fromJson(Map<String, Object?> json) =>
      _$BookmarkFromJson(json);
}
```

- Data classes use `abstract class`; unions use `sealed class` with named
  factory constructors (freezed 3+ syntax).
- JSON maps are `Map<String, Object?>`, never `Map<String, dynamic>`.
- Use real types: `Uri`, `DateTime`, enums (with `@JsonValue` for wire names),
  not raw strings.
- `DateTime` values are kept in UTC; convert with `.toLocal()` only for display.
- The API model is the app model. Add a separate UI model only when the
  screen needs a shape the API does not provide.

`build.yaml` (project root) sets json_serializable options once for all models:

```yaml
targets:
  $default:
    builders:
      json_serializable:
        options:
          checked: true          # bad JSON -> CheckedFromJsonException
          explicit_to_json: true # nested models serialize correctly
```

API field casing is not confirmed yet. Once known, set `field_rename`
(e.g. `snake`) in the same block instead of per-field `@JsonKey(name: ...)`.

---

## Repository

One repository per feature: a plain class taking `Dio`, plus its keep-alive
provider in the same file.

```dart
// lib/features/bookmarks/data/bookmark_repository.dart
part 'bookmark_repository.g.dart';

class BookmarkRepository {
  BookmarkRepository(this._dio);

  final Dio _dio;

  Future<List<Bookmark>> fetchBookmarks({int page = 1}) => guardDio(() async {
    final response = await _dio.get<List<Object?>>(
      '/bookmarks',
      queryParameters: {'page': page},
    );
    return response.data!
        .map((json) => Bookmark.fromJson(json as Map<String, Object?>))
        .toList();
  });

  Future<void> deleteBookmark(String id) =>
      guardDio(() => _dio.delete<void>('/bookmarks/$id'));
}

@Riverpod(keepAlive: true)
BookmarkRepository bookmarkRepository(Ref ref) =>
    BookmarkRepository(ref.watch(dioProvider));
```

Rules:

- Every public method wraps its body in `guardDio` (`core/network/guard_dio.dart`),
  so callers only ever see `AppException` subtypes.
- Methods return models or `void`, never `Response`, `Map`, or `dynamic`.
- Paths are relative (`'/bookmarks'`); the base URL comes from `Dio`'s `BaseOptions`.
- Query parameters go through `queryParameters:`, never string interpolation.
- No caching layer: provider state is the in-memory cache. Add local
  persistence only with an explicit task and a spec update.

---

## Dio and Config

```dart
// lib/core/config/env.dart
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
}
```

```dart
// lib/core/network/dio_provider.dart
part 'dio_provider.g.dart';

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        responseHeader: false,
        logPrint: Logger('Http').fine,
      ),
    );
  }
  ref.onDispose(dio.close);
  return dio;
}
```

- Config values come from `--dart-define-from-file=config/<env>.json`
  (`flutter run --dart-define-from-file=config/dev.json`). Without that flag
  `Env.apiBaseUrl` is `''` and every request fails; tests never depend on it.
- `config/*.json` holds non-secret values only (base URLs, flags). Anything
  compiled into the app can be extracted from the binary.
- All interceptors (auth header, logging) are added in `dioProvider`.
  Repositories never create their own `Dio`.

---

## Not Decided Yet

- Authentication (token storage, refresh interceptor, router redirect):
  document here when the first auth task lands.
- API field casing (`field_rename`), pagination shape, error response body format.
- Cleartext HTTP: the dev API (`config/dev.json`) is plain `http://`. Before the
  first real request, allow it per platform (Android `usesCleartextTraffic` for
  debug, iOS ATS exception, macOS `com.apple.security.network.client`
  entitlement) and record the chosen setup here.
