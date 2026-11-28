import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_videos.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoTile {
  final String? title;
  final String? url;
  final String? imageUrl;
  VideoTile(this.title, this.url, this.imageUrl);

  /// Extract YouTube video ID from an embed URL and build a proper VideoTile
  /// with thumbnail and watch URL when the API returns nulls.
  static VideoTile fromTrailer(String? title, Trailer? trailer) {
    String? url = trailer?.url;
    String? imageUrl = trailer?.images?.largeImageUrl ??
        trailer?.images?.maximumImageUrl ??
        trailer?.images?.mediumImageUrl ??
        trailer?.images?.imageUrl;

    // Fallback: extract video ID from embed_url
    if ((url == null || imageUrl == null) && trailer?.embedUrl != null) {
      final videoId = _extractYoutubeId(trailer!.embedUrl!);
      if (videoId != null) {
        url ??= 'https://www.youtube.com/watch?v=$videoId';
        imageUrl ??= 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      }
    }

    // Fallback: build thumbnail from youtube_id
    if ((url == null || imageUrl == null) && trailer?.youtubeId != null) {
      url ??= 'https://www.youtube.com/watch?v=${trailer!.youtubeId}';
      imageUrl ??= 'https://img.youtube.com/vi/${trailer!.youtubeId}/hqdefault.jpg';
    }

    return VideoTile(title, url, imageUrl);
  }

  static String? _extractYoutubeId(String embedUrl) {
    final regex = RegExp(r'/embed/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(embedUrl);
    return match?.group(1);
  }
}

class VideosWidget extends StatefulWidget {
  final AnimeVideos? videos;
  final double horizPadding;
  final List<ThemeSong>? openingSongs;
  final List<ThemeSong>? endingSongs;

  /// Picture (usually the cover) shown on a video that has no thumbnail.
  final String? fallbackImageUrl;

  const VideosWidget({
    required this.horizPadding,
    this.videos,
    Key? key,
    this.openingSongs,
    this.endingSongs,
    this.fallbackImageUrl,
  }) : super(key: key);

  @override
  State<VideosWidget> createState() => _VideosWidgetState();
}

class _VideosWidgetState extends State<VideosWidget> {
  int pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <(String, Widget Function())>[
      if (!nullOrEmpty(widget.videos?.promo))
        (S.current.Promotional, () => promoWidget),
      if (!nullOrEmpty(widget.videos?.musicVideos))
        (S.current.Music_Videos, () => musicVidoeWidget),
      if (!nullOrEmpty(widget.videos?.episodes))
        (S.current.Episodes, () => episodesWidget),
      if (!nullOrEmpty(widget.openingSongs))
        (S.current.Opening_Songs, () => themesWidget(widget.openingSongs!)),
      if (!nullOrEmpty(widget.endingSongs))
        (S.current.Ending_Songs, () => themesWidget(widget.endingSongs!)),
    ];
    if (pages.isEmpty) return const SizedBox.shrink();
    final index = pageIndex.clamp(0, pages.length - 1);
    return DefaultTabController(
      key: ValueKey(pages.length),
      length: pages.length,
      initialIndex: index,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            isScrollable: true,
            onTap: (i) => setState(() => pageIndex = i),
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.symmetric(horizontal: widget.horizPadding),
            tabs: [
              for (final page in pages)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                  child: Text(page.$1, style: const TextStyle(fontSize: 13.0)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          KeyedSubtree(key: ValueKey(index), child: pages[index].$2()),
        ],
      ),
    );
  }

  Widget get promoWidget {
    return videoTiles(widget.videos!.promo
            ?.map((e) => VideoTile.fromTrailer(e.title, e.trailer))
            .toList() ??
        []);
  }

  Widget get musicVidoeWidget {
    return videoTiles(widget.videos?.musicVideos
            ?.map((e) => VideoTile.fromTrailer(e.title, e.video))
            .toList() ??
        []);
  }

  Widget get episodesWidget {
    return videoTiles(
        widget.videos!.episodes
                ?.map((e) => VideoTile(
                    '${e.episode}: ${e.title}', e.url, e.images?.jpg?.imageUrl))
                .toList() ??
            [],
        false);
  }

  Widget videoTiles(List<VideoTile> tiles, [bool useYTIcon = true]) {
    final borderRadius = BorderRadius.circular(6);
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SizedBox(
      height: 170,
      child: ListView.builder(
        itemCount: tiles.length,
        padding: EdgeInsets.symmetric(horizontal: widget.horizPadding + 10),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final tile = tiles[i];
          final imageUrl = !nullOrEmpty(tile.imageUrl)
              ? tile.imageUrl
              : widget.fallbackImageUrl;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 140,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AppImage(
                            url: imageUrl,
                            width: 200,
                            height: 140,
                            borderRadius: borderRadius,
                            placeholderColor: surface,
                            errorWidget: (_) => DecoratedBox(
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: borderRadius,
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Material(
                            type: MaterialType.transparency,
                            child: _videoInkWell(tile, borderRadius, useYTIcon),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  title(tile.title, textOverflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _videoInkWell(VideoTile tile, BorderRadius borderRadius, bool useYTIcon) {
    final url = tile.url;
    return InkWell(
      borderRadius: borderRadius,
      onTap: url == null ? null : () => showYouTubeVideo(url: url, context: context),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomLeft,
            child: _videoIconWidget(borderRadius, useYTIcon),
          ),
          if (url != null) _copyButton(url),
        ],
      ),
    );
  }

  Positioned _copyButton(String url) {
    return Positioned(
      top: 5.0,
      left: 5.0,
      child: SizedBox(
        height: 30.0,
        width: 30.0,
        child: IconButton.filledTonal(
          tooltip: S.current.Copy,
          onPressed: () => Clipboard.setData(ClipboardData(text: url)),
          icon: const Icon(Icons.copy),
          iconSize: 14.0,
        ),
      ),
    );
  }

  Container _videoIconWidget([
    BorderRadius? borderRadius,
    bool useYTIcon = true,
  ]) {
    return Container(
      height: 50,
      width: 50,
      decoration: BoxDecoration(borderRadius: borderRadius),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(6),
        child: Image.asset(useYTIcon
            ? 'assets/images/youtube.png'
            : 'assets/images/mal-icon.png'),
      ),
    );
  }

  Widget themesWidget(List<ThemeSong> data) {
    return SizedBox(
      height: 170,
      child: GridView.builder(
        itemCount: data.length,
        scrollDirection: Axis.horizontal,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          childAspectRatio: .3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 0,
          crossAxisCount: 2,
        ),
        padding: EdgeInsets.symmetric(
            horizontal: widget.horizPadding + 10, vertical: 4),
        itemBuilder: (context, index) => _buildThemeSongTile(data[index]),
      ),
    );
  }

  Widget _buildThemeSongTile(ThemeSong song) {
    return Card(
      child: InkWell(
        onTap: () {
          var songname = getSongName(song.name);
          launchURLWithConfirmation(
              'https://www.youtube.com/results?search_query=' +
                  Uri.encodeQueryComponent(songname ?? song.name ?? ''),
              context: context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _videoIconWidget(),
              const SizedBox(width: 10),
              Expanded(
                child: title(
                  song.name ?? '',
                  textOverflow: TextOverflow.fade,
                  selectable: false,
                ),
              ),
              ToolTipButton(
                onTap: () => Clipboard.setData(ClipboardData(text: song.name!)),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                usePadding: true,
                child: const Icon(
                  Icons.copy,
                  size: 16,
                ),
                message: S.current.Copy,
              )
            ],
          ),
        ),
      ),
    );
  }

  String? getSongName(String? text) {
    try {
      text = text?.substring(text.indexOf('"') + 1) ?? '';
      return text.substring(0, text.indexOf('"'));
    } catch (e) {}
    return null;
  }
}

Future<void> _restorePortraitOrientation() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  unawaited(Future<void>.delayed(const Duration(milliseconds: 450), () {
    SystemChrome.setPreferredOrientations(const []);
  }));
}

Future<void> showYouTubeVideo({
  required String url,
  required BuildContext context,
}) async {
  final videoId = YoutubePlayerController.convertUrlToId(url);

  // The embedded player is opt-in (allowYoutubePlayer); otherwise open externally.
  if (videoId != null && Preferences.general.allowYoutubePlayer) {
    var failed = false;
    var openExternally = false;
    var wasFullScreen = false;
    BuildContext? dialogContext;

    void handleFailure() {
      if (failed) return;
      failed = true;
      final open = dialogContext;
      if (open != null && open.mounted) {
        Navigator.of(open).pop();
      }
    }

    final controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        mute: false,
        enableCaption: true,
        showControls: false,
        strictRelatedVideos: true,
      ),
      onLoadError: (_) => handleFailure(),
    );

    final sub = controller.stream.listen((value) {
      if (value.hasError || value.loadError != null) {
        handleFailure();
      }
    });

    try {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (ctx) {
          dialogContext = ctx;
          final scheme = Theme.of(ctx).colorScheme;
          return Dialog(
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: S.current.Open_In_Browser,
                        color: Colors.white70,
                        icon: const Icon(Icons.open_in_new_rounded, size: 20),
                        onPressed: () {
                          openExternally = true;
                          Navigator.of(ctx).pop();
                        },
                      ),
                      IconButton(
                        tooltip: S.current.Close,
                        color: Colors.white,
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Theme(
                  data: Theme.of(ctx).copyWith(
                    extensions: [
                      YoutubePlayerTheme(
                        progressBarActiveColor: scheme.primary,
                        progressBarBufferedColor:
                            scheme.primary.withValues(alpha: 0.4),
                        controlsColor: Colors.white,
                      ),
                    ],
                  ),
                  child: YoutubePlayer(
                    controller: controller,
                    aspectRatio: 16 / 9,
                    autoPlayWhenVisible: false,
                    backgroundColor: Colors.black,
                    onFullScreenChanged: (isFullScreen) {
                      if (isFullScreen) {
                        wasFullScreen = true;
                      } else if (wasFullScreen) {
                        wasFullScreen = false;
                        unawaited(_restorePortraitOrientation());
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      await sub.cancel();
      controller.close();
      if (wasFullScreen) {
        await _restorePortraitOrientation();
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }

    if ((failed || openExternally) && context.mounted) {
      launchURLWithConfirmation(url, context: context);
    }
  } else {
    launchURLWithConfirmation(url, context: context);
  }
}
