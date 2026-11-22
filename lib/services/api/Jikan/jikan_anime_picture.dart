import 'package:mywatchlist/services/api/Jikan/jikan_json.dart';

class Images {
  final ImageFormat? jpg;
  final ImageFormat? webp;

  Images({this.jpg, this.webp});

  factory Images.fromJson(Map<String, dynamic> json) {
    if (json['jpg'] != null || json['webp'] != null) {
      return Images(
        jpg: jikanMap(json['jpg']) != null
            ? ImageFormat.fromJson(jikanMap(json['jpg'])!)
            : null,
        webp: jikanMap(json['webp']) != null
            ? ImageFormat.fromJson(jikanMap(json['webp'])!)
            : null,
      );
    }
    final sizes = jikanImageSizes(
      json,
      fallbackImageUrl: jikanStr(json['imageUrl'] ?? json['image_url']),
    );
    return Images(
      jpg: ImageFormat(
        imageUrl: sizes.medium ?? sizes.large ?? sizes.small,
        smallImageUrl: sizes.small,
        largeImageUrl: sizes.large ?? sizes.medium,
      ),
    );
  }
}

class ImageFormat {
  final String? imageUrl;
  final String? smallImageUrl;
  final String? largeImageUrl;

  ImageFormat({this.imageUrl, this.smallImageUrl, this.largeImageUrl});

  factory ImageFormat.fromJson(Map<String, dynamic> json) {
    return ImageFormat(
      imageUrl: jikanStr(json['image_url'] ?? json['imageUrl'] ?? json['medium']),
      smallImageUrl: jikanStr(
          json['small_image_url'] ?? json['thumbnailUrl'] ?? json['small']),
      largeImageUrl: jikanStr(
          json['large_image_url'] ?? json['imageUrl'] ?? json['large']),
    );
  }
}

class AnimePicturesResponse {
  final List<Images> data;

  AnimePicturesResponse({required this.data});

  factory AnimePicturesResponse.fromJson(Map<String, dynamic> json) {
    return AnimePicturesResponse(
      data: ((json['data'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Images.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
