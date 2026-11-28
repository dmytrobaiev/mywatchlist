import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:mywatchlist/cache/cached_user_profile.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/common/smooth_collapse.dart';
import 'package:mywatchlist/widgets/user/profile/profile_header.dart' show timeZoneLabel;
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';
import 'package:mwl_commons/mwl_commons.dart' show UserAboutHtml;

final RegExp _bbSpoilerRe = RegExp(
  r'\[spoiler(?:=([^\]]*))?\](.*?)\[/spoiler\]',
  caseSensitive: false,
  dotAll: true,
);

/// Preserves newlines in plain-text profile About bios (which lack `<br>` /
/// block HTML tags) and converts plain `[spoiler]` BBCode into MAL's
/// `<div class="spoiler">` markup so [HtmlWidget] renders spoilers uniformly.
String formatAboutHtml(String raw) {
  var html = raw.replaceAllMapped(_bbSpoilerRe, (m) {
    final name = (m.group(1) ?? '').trim();
    final body = (m.group(2) ?? '').trim();
    final attr = name.isEmpty ? '' : ' data-showname="${_escapeAttr(name)}"';
    return '<div class="spoiler">'
        '<input type="button" class="button show_button"$attr>'
        '<span class="spoiler_content" style="display:none">$body</span>'
        '</div>';
  });
  final hasBlockHtml = RegExp(
    r'<\s*(?:br|p|div|li|ul|ol|table|tr|td|h[1-6]|blockquote|pre|hr)\b',
    caseSensitive: false,
  ).hasMatch(html);
  if (hasBlockHtml) return html;
  return html.replaceAll('\r\n', '\n').replaceAll('\n', '<br>');
}

String _escapeAttr(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// The "about me" text of a profile. MAL serves it as HTML; links open through [openLink]
/// and pictures through [AppImage]. When the profile came from MAL's page, [fromPage] holds
/// the text already read there and no request is made; otherwise the mwl-api route answers.
class AboutSection extends StatelessWidget {
  final String username;
  final bool isSelf;
  final UserAboutHtml? fromPage;

  /// The account's IANA time zone (`America/Los_Angeles`); only the official API gives it,
  /// so only for the signed-in user. When null on your own profile, the cached profile is
  /// asked.
  final String? timezone;

  const AboutSection({
    super.key,
    required this.username,
    required this.isSelf,
    this.fromPage,
    this.timezone,
  });

  static const String _editUrl = 'https://myanimelist.net/editprofile.php';
  static const String _modernEditUrl =
      'https://mxj.myanimelist.net/about-me/?utm_source=MAL&utm_medium=profile_link_about-me';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AsyncProfileTab<UserAboutHtml?>(
      storageKey: 'about_$username',
      loader: () async {
        final known = fromPage;
        if (known != null && (known.about ?? '').trim().isNotEmpty) {
          final hasHtml = RegExp(r'<[a-zA-Z][^>]*>').hasMatch(known.about!);
          if (hasHtml) return known;
          try {
            final rich = await MwlApi.i.getUserAboutHtml(username);
            if (rich != null && (rich.about ?? '').trim().isNotEmpty) {
              return rich;
            }
          } catch (_) {}
          return known;
        }
        final about = await MwlApi.i.getUserAboutHtml(username);
        if (about == null) throw StateError('No about for $username');
        return about;
      },
      isEmpty: (about) => (about?.about ?? '').trim().isEmpty,
      emptyBuilder: (context) => ProfileMessage(
        icon: Icons.notes_outlined,
        title: isSelf ? s.Prof_About_Empty_Self : s.Prof_About_Empty,
        actionLabel: isSelf ? s.Prof_About_Edit : null,
        onAction: isSelf ? () => openLink(context, _editUrl) : null,
      ),
      slivers: (context, about) => [
        if (isSelf)
          SliverToBoxAdapter(
            child: AboutTimeZone(username: username, timezone: timezone),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AboutHtmlContent(html: formatAboutHtml(about!.about!)),
          ),
        ),
        if (isSelf)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => openLink(context, about.modern ? _modernEditUrl : _editUrl),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(s.Prof_About_Edit),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.Prof_About_Edit_Hint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Renders MAL profile About HTML with interactive `<div class="spoiler">`
/// toggles (2026.11.4 TextButton.icon style + smooth animation) and zoomable
/// images.
class AboutHtmlContent extends StatelessWidget {
  final String html;

  const AboutHtmlContent({super.key, required this.html});

  static String _spoilerName(dom.Element spoiler) {
    final btn = spoiler.querySelector('input.show_button') ??
        spoiler.querySelector('input[type="button"]');
    var raw = (btn?.attributes['data-showname'] ??
            btn?.attributes['value'] ??
            '')
        .trim();
    raw = raw
        .replaceFirst(RegExp(r'^show\b', caseSensitive: false), '')
        .trim();
    return raw.isEmpty ? S.current.Fc_Spoiler : raw;
  }

  static String _spoilerBodyHtml(dom.Element spoiler) {
    final content = spoiler.querySelector('.spoiler_content');
    if (content == null) return '';
    final clone = content.clone(true);
    for (final hide in clone.querySelectorAll('input.hide_button, input.show_button')) {
      hide.remove();
    }
    return clone.innerHtml.trim();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      html,
      textStyle: Theme.of(context).textTheme.bodyMedium,
      onTapUrl: (url) {
        openLink(context, url);
        return true;
      },
      customWidgetBuilder: (element) {
        if (element.localName == 'div' && element.classes.contains('spoiler')) {
          final bodyHtml = _spoilerBodyHtml(element);
          if (bodyHtml.isEmpty) return const SizedBox.shrink();
          return _AboutSpoilerBlock(
            name: _spoilerName(element),
            bodyHtml: bodyHtml,
          );
        }
        if (element.localName != 'img') return null;
        final src = element.attributes['src'] ?? element.attributes['data-src'];
        if (src == null || src.isEmpty) return const SizedBox.shrink();
        final width = MediaQuery.sizeOf(context).width - 32;
        return GestureDetector(
          onTap: () => zoomInImage(context, src),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: AppImage(
              url: src,
              width: width,
              fit: BoxFit.contain,
              errorWidget: (_) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

class _AboutSpoilerBlock extends StatefulWidget {
  final String name;
  final String bodyHtml;

  const _AboutSpoilerBlock({
    required this.name,
    required this.bodyHtml,
  });

  @override
  State<_AboutSpoilerBlock> createState() => _AboutSpoilerBlockState();
}

class _AboutSpoilerBlockState extends State<_AboutSpoilerBlock> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(
              _open ? Icons.visibility_off : Icons.visibility,
              size: 16,
            ),
            label: Text(
              _open
                  ? S.current.Fc_Spoiler_Hide(widget.name)
                  : S.current.Fc_Spoiler_Show(widget.name),
            ),
          ),
          SmoothCollapse(
            expanded: _open,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AboutHtmlContent(html: widget.bodyHtml),
            ),
          ),
        ],
      ),
    );
  }
}

/// The labelled "Time zone" line at the top of your About block. Hidden while unknown.
class AboutTimeZone extends StatefulWidget {
  final String username;
  final String? timezone;

  const AboutTimeZone({super.key, required this.username, this.timezone});

  @override
  State<AboutTimeZone> createState() => _AboutTimeZoneState();
}

class _AboutTimeZoneState extends State<AboutTimeZone> {
  String? _zone;

  @override
  void initState() {
    super.initState();
    _zone = widget.timezone;
    if (timeZoneLabel(_zone) == null) _fromCache();
  }

  Future<void> _fromCache() async {
    final entry = await CachedUserProfile.instance.read(widget.username);
    final zone = entry?.json['timezone'];
    if (!mounted || zone is! String) return;
    setState(() => _zone = zone);
  }

  @override
  Widget build(BuildContext context) {
    final label = timeZoneLabel(_zone);
    if (label == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            S.of(context).Mpl_Time_Zone,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Flexible(
            child: Text(label, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
