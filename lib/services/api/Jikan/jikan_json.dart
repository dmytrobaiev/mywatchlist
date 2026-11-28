/// Shared JSON parsing helpers for `jikan-edge` (`/v1`, camelCase, `{small, medium, large}` images,
/// `meta.pagination`) with backwards-compatible fallbacks for Jikan v4 / Tenrai (`snake_case`,
/// `images.jpg`, top-level `pagination`).
library;

Map<String, dynamic>? jikanMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

int? jikanInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.replaceAll(',', '').trim());
  return null;
}

double? jikanDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String? jikanStr(Object? value) => value is String && value.isNotEmpty ? value : null;

/// Extracts the pagination map from `meta.pagination` (jikan-edge) or top-level `pagination`
/// (Jikan v4 / Tenrai). Returns `null` when the route is unpaginated.
Map<String, dynamic>? jikanPagination(Map<String, dynamic> json) {
  final meta = jikanMap(json['meta']);
  return jikanMap(meta?['pagination']) ?? jikanMap(json['pagination']);
}

bool? jikanHasNextPage(Map<String, dynamic>? pagination) {
  if (pagination == null) return null;
  final v = pagination['hasNextPage'] ?? pagination['has_next_page'];
  return v is bool ? v : null;
}

int? jikanLastVisiblePage(Map<String, dynamic>? pagination) {
  if (pagination == null) return null;
  return jikanInt(pagination['lastVisiblePage'] ?? pagination['last_visible_page']);
}

/// Extracts `(small, medium, large)` image URLs from an `images` object in either:
/// - jikan-edge shape: `{ small, medium, large }`
/// - Jikan v4 / Tenrai shape: `{ jpg: { small_image_url, image_url, large_image_url }, webp: ... }`
({String? small, String? medium, String? large}) jikanImageSizes(
  Object? images, {
  String? fallbackImageUrl,
}) {
  final map = jikanMap(images);
  if (map != null) {
    final jpg = jikanMap(map['jpg']);
    if (jpg != null) {
      return (
        small: jikanStr(jpg['small_image_url'] ?? jpg['smallImageUrl']),
        medium: jikanStr(jpg['image_url'] ?? jpg['imageUrl']) ?? jikanStr(fallbackImageUrl),
        large: jikanStr(jpg['large_image_url'] ?? jpg['largeImageUrl']),
      );
    }
    final small = jikanStr(map['small']);
    final medium = jikanStr(map['medium']) ?? jikanStr(fallbackImageUrl);
    final large = jikanStr(map['large']);
    if (small != null || medium != null || large != null) {
      return (small: small, medium: medium, large: large);
    }
    final direct = jikanStr(map['imageUrl'] ?? map['image_url']);
    final thumb = jikanStr(map['thumbnailUrl'] ?? map['thumbnail_url']);
    if (direct != null || thumb != null) {
      return (small: thumb, medium: direct ?? thumb, large: direct);
    }
  }
  final fallback = jikanStr(fallbackImageUrl);
  return (small: null, medium: fallback, large: null);
}

/// Best single image URL from an entity map (supports both jikan-edge and Jikan v4 / Tenrai).
String? jikanBestImage(Map<String, dynamic> json, {bool preferLarge = false}) {
  final fallback = jikanStr(json['imageUrl'] ?? json['image_url'] ?? json['avatarUrl']);
  final sizes = jikanImageSizes(json['images'], fallbackImageUrl: fallback);
  if (preferLarge) {
    return sizes.large ?? sizes.medium ?? sizes.small;
  }
  return sizes.medium ?? sizes.large ?? sizes.small;
}

final RegExp _ytEmbedRe = RegExp(
  r'(?:youtube(?:-nocookie)?\.com/(?:embed/|watch\?v=)|youtu\.be/)([A-Za-z0-9_-]{11})',
);

/// Extracts the 11-char YouTube video ID from a URL (e.g. jikan-edge's `videoUrl`).
String? jikanYoutubeId(String? url) {
  if (url == null || url.isEmpty) return null;
  return _ytEmbedRe.firstMatch(url)?.group(1);
}
