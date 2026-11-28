import 'package:flutter/material.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';

class AnimePictures extends StatelessWidget {
  final List<Picture> pictures;
  const AnimePictures({super.key, required this.pictures});

  @override
  Widget build(BuildContext context) {
    final urls = <String>[];
    final indexMap = <int, int>{};
    for (var i = 0; i < pictures.length; i++) {
      final url = pictures[i].large;
      if (url != null && url.isNotEmpty) {
        indexMap[i] = urls.length;
        urls.add(url);
      }
    }

    Widget avatarWidget(int index) {
      final urlIndex = indexMap[index];
      return AvatarWidget(
        width: 200,
        height: 304,
        fit: BoxFit.contain,
        onTap: urlIndex == null
            ? null
            : () => zoomInImageList(context, urls, urlIndex),
        url: pictures[index].large,
        useUserImageOnError: false,
        radius: BorderRadius.circular(6),
        userRoundBorderforLoading: false,
      );
    }

    return SizedBox(
      height: 320,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: pictures.length,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: avatarWidget(index),
        ),
      ),
    );
  }
}
