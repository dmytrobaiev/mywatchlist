import 'package:flutter/material.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart'
    show ImagePlaceholder;
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

class AnimePictures extends StatelessWidget {
  static const double stripHeight = 220;
  static const double _fallbackWidth = 155;

  final List<Picture> pictures;
  const AnimePictures({super.key, required this.pictures});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final radius = BorderRadius.circular(10);

    final urls = <String>[];
    final indexMap = <int, int>{};
    for (var i = 0; i < pictures.length; i++) {
      final url = pictures[i].large;
      if (url != null && url.isNotEmpty) {
        indexMap[i] = urls.length;
        urls.add(url);
      }
    }

    Widget pictureTile(int index) {
      final url = pictures[index].large;
      final urlIndex = indexMap[index];
      final placeholder = SizedBox(
        width: _fallbackWidth,
        height: stripHeight,
        child: ShimmerColor(
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: radius,
            ),
          ),
        ),
      );
      final errorBox = SizedBox(
        width: _fallbackWidth,
        height: stripHeight,
        child: ImagePlaceholder(radius: radius),
      );

      final Widget content = (url == null || url.isEmpty)
          ? errorBox
          : Image(
              image: AppImage.provider(
                url,
                logicalHeight: stripHeight,
                devicePixelRatio: dpr,
                fit: BoxFit.contain,
              ),
              height: stripHeight,
              fit: BoxFit.fitHeight,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) return child;
                return placeholder;
              },
              errorBuilder: (_, __, ___) => errorBox,
            );

      return ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: urlIndex == null
                ? null
                : () => zoomInImageList(context, urls, urlIndex),
            child: content,
          ),
        ),
      );
    }

    return SizedBox(
      height: stripHeight + 16,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pictures.length,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => pictureTile(index),
      ),
    );
  }
}
