import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';

/// Converts MAL forum BBCode (preserving plain-text brackets like `[1]` or `[edit]`)
/// into HTML and renders it with [HtmlWidget].
class BbcodeWidget extends StatelessWidget {
  /// Transformed bodies by source text: a post is transformed once, not on every rebuild.
  static final Map<String, String> _transformed = {};

  static String _transformCached(String body) {
    final hit = _transformed.remove(body);
    final value = hit ?? const BbcodeWidget(body: '').applyTransform(body);
    _transformed[body] = value;
    if (_transformed.length > 150) _transformed.remove(_transformed.keys.first);
    return value;
  }

  final String body;
  final Color? color;
  final bool minimize;
  final bool alignCenter;
  final bool shrinkWrap;

  const BbcodeWidget({
    super.key,
    required this.body,
    this.color,
    this.shrinkWrap = true,
    this.minimize = false,
    this.alignCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    final transformedHtml =
        '<div ${alignCenter ? 'style="text-align:center;"' : ''}>${_transformCached(body)}</div>';
    final theme = Theme.of(context);
    final maxImageWidth = (MediaQuery.sizeOf(context).width - 80).clamp(160.0, 720.0);

    return HtmlWidget(
      transformedHtml,
      textStyle: TextStyle(
        fontSize: minimize ? 12 : 14,
        color: color ?? theme.colorScheme.onSurface,
        fontFamily: theme.textTheme.bodyMedium?.fontFamily,
      ),
      onTapUrl: (url) async {
        // A MyAnimeList profile opens the quick profile sheet.
        final profileMatch =
            RegExp(r'myanimelist\.net/profile/([^/?#]+)').firstMatch(url);
        if (profileMatch != null) {
          openForumUser(
              context, Uri.decodeComponent(profileMatch.group(1)!));
          return true;
        }
        // Intercept MAL anime/manga/character/person URLs for in-app navigation
        final animeMatch =
            RegExp(r'myanimelist\.net/anime/(\d+)').firstMatch(url);
        if (animeMatch != null) {
          final id = int.tryParse(animeMatch.group(1)!);
          if (id != null) {
            gotoPage(
              context: context,
              newPage: ContentDetailedScreen(
                  node: null, category: 'anime', id: id),
            );
            return true;
          }
        }
        final mangaMatch =
            RegExp(r'myanimelist\.net/manga/(\d+)').firstMatch(url);
        if (mangaMatch != null) {
          final id = int.tryParse(mangaMatch.group(1)!);
          if (id != null) {
            gotoPage(
              context: context,
              newPage: ContentDetailedScreen(
                  node: null, category: 'manga', id: id),
            );
            return true;
          }
        }
        final charMatch =
            RegExp(r'myanimelist\.net/character/(\d+)').firstMatch(url);
        if (charMatch != null) {
          final id = int.tryParse(charMatch.group(1)!);
          if (id != null) {
            gotoPage(
              context: context,
              newPage: CharacterScreen(id: id, category: 'character'),
            );
            return true;
          }
        }
        final personMatch =
            RegExp(r'myanimelist\.net/people/(\d+)').firstMatch(url);
        if (personMatch != null) {
          final id = int.tryParse(personMatch.group(1)!);
          if (id != null) {
            gotoPage(
              context: context,
              newPage: CharacterScreen(id: id, category: 'person'),
            );
            return true;
          }
        }
        // Anything else: ask, then open in the in-app browser.
        if (context.mounted) await openLink(context, url);
        return true;
      },
      customWidgetBuilder: (element) {
        // Handle images: render at natural/original dimensions (clamped only by maxWidth),
        // keeping inline images/badges inline without stretching or forcing full width.
        if (element.localName == 'img') {
          if (minimize) return const SizedBox.shrink();
          final src = element.attributes['src']?.trim();
          if (src != null && src.isNotEmpty) {
            final img = GestureDetector(
              onTap: () => zoomInImage(context, src),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxImageWidth),
                child: Image(
                  image: CachedNetworkImageProvider(src),
                  fit: BoxFit.scaleDown,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            );
            return InlineCustomWidget(
              alignment: PlaceholderAlignment.middle,
              child: img,
            );
          }
        }
        // Handle iframes: hide in minimize mode
        if (element.localName == 'iframe' && minimize) {
          return const SizedBox.shrink();
        }
        // Handle spoiler tags
        if (element.localName == 'spoiler') {
          if (minimize) return const SizedBox.shrink();
          final name = element.attributes['name'] ?? S.current.Fc_Spoiler;
          final innerHtml = element.innerHtml;
          return _SpoilerWidget(
            name: name,
            content: innerHtml,
            color: color,
          );
        }
        return null;
      },
    );
  }

  static const Set<String> _knownTags = {
    'b',
    'i',
    'u',
    's',
    'center',
    'right',
    'color',
    'size',
    'url',
    'img',
    'spoiler',
    'quote',
    'code',
    'list',
    '*',
    'yt',
    'hr',
  };

  /// Matches only recognized BBCode tokens (`[tag]`, `[tag=val]`, `[tag attr=val]`, `[/tag]`).
  /// Plain-text brackets like `[1]`, `[edit]`, or `[Level]` are never matched and stay literal.
  static final RegExp _bbTokenRe = RegExp(
    r'\[(/?)(b|i|u|s|center|right|color|size|url|img|spoiler|quote|code|list|\*|yt|hr)(?:(=[^\]]*|\s+[^\]]*))?\]',
    caseSensitive: false,
  );

  static final RegExp _brStripRe = RegExp(r'<br\s*/?>', caseSensitive: false);

  /// Token/stack BBCode-to-HTML transformer with per-tag-name matching.
  String applyTransform(String text) {
    if (text.isEmpty) return '';
    // Normalize bare newlines when not already using HTML <br> tags.
    final source = text.replaceAll('\r\n', '\n');
    final tokens = _bbTokenRe.allMatches(source).toList();
    if (tokens.isEmpty) return source;

    final frames = <_BbFrame>[_BbFrame(tag: '', attr: '', rawOpen: '')];
    var cursor = 0;

    void writeText(String chunk) {
      if (chunk.isEmpty) return;
      frames.last.buf.write(chunk);
    }

    for (final match in tokens) {
      writeText(source.substring(cursor, match.start));
      cursor = match.end;

      final isClosing = match.group(1) == '/';
      final tag = match.group(2)!.toLowerCase();
      final rawAttr = match.group(3) ?? '';
      final rawToken = match.group(0)!;

      if (!_knownTags.contains(tag)) {
        writeText(rawToken);
        continue;
      }

      // Self-closing tags
      if (tag == 'hr' && !isClosing) {
        writeText('<hr />');
        continue;
      }
      if (tag == '*' && !isClosing) {
        // Only treat [*] as a list item marker inside an open [list].
        final inList = frames.any((f) => f.tag == 'list');
        if (inList) {
          writeText('<!--BB_LI-->');
        } else {
          writeText(rawToken);
        }
        continue;
      }

      if (!isClosing) {
        frames.add(_BbFrame(tag: tag, attr: rawAttr.trim(), rawOpen: rawToken));
      } else {
        // Find the nearest matching open tag of the same name.
        final idx = frames.lastIndexWhere((f) => f.tag == tag);
        if (idx <= 0) {
          // Unmatched closing tag — ignore stray [/tag] cleanly.
          continue;
        }
        // Flush any unclosed inner frames back as literal text.
        while (frames.length - 1 > idx) {
          final orphan = frames.removeLast();
          frames.last.buf
            ..write(orphan.rawOpen)
            ..write(orphan.buf);
        }
        final frame = frames.removeLast();
        frames.last.buf.write(_renderTag(frame.tag, frame.attr, frame.buf.toString()));
      }
    }

    writeText(source.substring(cursor));

    // Any remaining unclosed tags stay literal so no user text is ever lost.
    while (frames.length > 1) {
      final orphan = frames.removeLast();
      frames.last.buf
        ..write(orphan.rawOpen)
        ..write(orphan.buf);
    }

    return frames.first.buf.toString();
  }

  static String _attrValue(String attr) {
    final trimmed = attr.trim();
    if (!trimmed.startsWith('=')) return '';
    var val = trimmed.substring(1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) ||
        (val.startsWith("'") && val.endsWith("'"))) {
      if (val.length >= 2) val = val.substring(1, val.length - 1);
    }
    return val.trim();
  }

  static String _escapeAttr(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _renderTag(String tag, String attr, String inner) {
    final val = _attrValue(attr);
    switch (tag) {
      case 'b':
        return '<b>$inner</b>';
      case 'i':
        return '<i>$inner</i>';
      case 'u':
        return '<u>$inner</u>';
      case 's':
        return '<s>$inner</s>';
      case 'center':
        return '<div style="text-align: center;">$inner</div>';
      case 'right':
        return '<div style="text-align: right;">$inner</div>';
      case 'color':
        if (val.isEmpty) return inner;
        return '<span style="color: ${_escapeAttr(val)};">$inner</span>';
      case 'size':
        final size = int.tryParse(val);
        if (size == null || size <= 0) return inner;
        final clamped = size >= 130 ? 130 : size;
        return '<span style="font-size: $clamped%;">$inner</span>';
      case 'url':
        final href = (val.isNotEmpty ? val : inner)
            .replaceAll(_brStripRe, '')
            .trim();
        final label = inner.trim().isEmpty ? href : inner;
        if (href.isEmpty) return label;
        return '<a href="${_escapeAttr(href)}">$label</a>';
      case 'img':
        final src = inner.replaceAll(_brStripRe, '').replaceAll(RegExp(r'\s+'), '').trim();
        if (src.isEmpty) return '';
        return '<img src="${_escapeAttr(src)}" />';
      case 'spoiler':
        final nameAttr = val.isEmpty ? '' : ' name="${_escapeAttr(val)}"';
        return '<spoiler$nameAttr>$inner</spoiler>';
      case 'quote':
        return '<blockquote>$inner</blockquote>';
      case 'code':
        return '<pre><code>$inner</code></pre>';
      case 'list':
        final parts = inner.split('<!--BB_LI-->');
        final items = StringBuffer();
        for (var i = 0; i < parts.length; i++) {
          final item = parts[i]
              .replaceAll(RegExp(r'^(?:\s*<br\s*/?>\s*)+|(?:\s*<br\s*/?>\s*)+$', caseSensitive: false), '')
              .trim();
          if (i == 0 && item.isEmpty) continue;
          if (item.isNotEmpty) items.write('<li>$item</li>');
        }
        final listTag = val.isNotEmpty ? 'ol type="${_escapeAttr(val)}"' : 'ul';
        final closeTag = val.isNotEmpty ? 'ol' : 'ul';
        return '<$listTag>$items</$closeTag>';
      case 'yt':
        final vid = inner.replaceAll(_brStripRe, '').trim();
        if (vid.isEmpty) return '';
        return '<div style="text-align: center;"><iframe height="315" src="https://www.youtube.com/embed/${_escapeAttr(vid)}"></iframe></div>';
      default:
        return inner;
    }
  }
}

class _BbFrame {
  final String tag;
  final String attr;
  final String rawOpen;
  final StringBuffer buf = StringBuffer();

  _BbFrame({
    required this.tag,
    required this.attr,
    required this.rawOpen,
  });
}

/// Spoiler widget with reveal toggle.
class _SpoilerWidget extends StatefulWidget {
  final String name;
  final String content;
  final Color? color;

  const _SpoilerWidget({
    required this.name,
    required this.content,
    this.color,
  });

  @override
  State<_SpoilerWidget> createState() => _SpoilerWidgetState();
}

class _SpoilerWidgetState extends State<_SpoilerWidget> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
          icon: Icon(
            _revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 16,
          ),
          label: Text(
            _revealed ? '${S.current.Hide} ${widget.name}' : widget.name,
            style: const TextStyle(fontSize: 12),
          ),
          onPressed: () => setState(() => _revealed = !_revealed),
        ),
        if (_revealed)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: BbcodeWidget(
              body: widget.content,
              color: widget.color,
            ),
          ),
      ],
    );
  }
}
