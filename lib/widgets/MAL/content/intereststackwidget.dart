import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplayType, gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/interest_stack_detail_screen.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/widgets/MAL/review/user_link.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';

/// Interest stacks as a horizontal strip (detail page) or a vertical list (stack screen,
/// "view all"): a fan of pictures, the title, the author (tap = quick user sheet), the
/// counts and, in the vertical layout, the date and the description.
class InterestStackContentList extends StatelessWidget {
  final DisplayType type;
  final double horizPadding;
  final List<InterestStack> interestStacks;
  static BorderRadius radius = BorderRadius.circular(12.0);
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final VoidCallback? onViewAll;

  const InterestStackContentList({
    super.key,
    required this.horizPadding,
    required this.interestStacks,
    this.shrinkWrap = false,
    this.padding,
    this.type = DisplayType.list_horiz,
    this.onViewAll,
  });

  bool get isHoriz => type == DisplayType.list_horiz;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isHoriz ? 240 : null,
      child: ListView.builder(
        scrollDirection: isHoriz ? Axis.horizontal : Axis.vertical,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        padding: padding ??
            (isHoriz
                ? EdgeInsets.symmetric(horizontal: horizPadding + 15.0)
                : const EdgeInsets.symmetric(vertical: 20, horizontal: 5)),
        itemCount: interestStacks.length,
        itemBuilder: (context, index) => _StackCard(stack: interestStacks[index], isHoriz: isHoriz),
      ),
    );
  }
}

class _StackCard extends StatelessWidget {
  final InterestStack stack;
  final bool isHoriz;

  const _StackCard({required this.stack, required this.isHoriz});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = InterestStackContentList.radius;
    final images = List<String>.from((stack.imageUrls ?? const <String>[]).reversed);
    final updatedAt = stack.updatedAt;
    final description = stack.description;
    final secondary = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: isHoriz ? 0 : 10),
      child: SizedBox(
        width: isHoriz ? 310 : null,
        child: Material(
          borderRadius: radius,
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => gotoPage(context: context, newPage: InterestStackDetailScreen(stack: stack)),
            borderRadius: radius,
            child: Row(
              crossAxisAlignment: isHoriz ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: isHoriz ? 170 : 130,
                  height: isHoriz ? null : 230,
                  child: InterestStackPictures(images: images),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isHoriz) const SizedBox(height: 10),
                      Text(
                        stack.title?.trim() ?? '',
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
                      ),
                      InterestStackAuthor(username: stack.username),
                      const SizedBox(height: 8),
                      Text(S.current.Social_Stack_Entries(stack.entries ?? 0), style: secondary),
                      const SizedBox(height: 4),
                      Text(S.current.Social_Stack_Restacks(stack.reStacks ?? 0), style: secondary),
                      if (!isHoriz && updatedAt != null && updatedAt.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(updatedAt, style: secondary),
                      ],
                      if (!isHoriz && description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240.0),
                          child: Text(
                            description,
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "by {username}" under a stack title. A real user opens the quick user sheet; the
/// placeholder names MAL uses for deleted accounts are shown as plain text.
class InterestStackAuthor extends StatelessWidget {
  final String? username;
  final TextAlign align;

  const InterestStackAuthor({super.key, required this.username, this.align = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    final name = username;
    if (name == null || name.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final linkable = isLinkableUser(name);
    final text = Text(
      S.current.Social_Stack_By(name),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: linkable ? theme.colorScheme.primary : null,
      ),
    );
    if (!linkable) return Padding(padding: const EdgeInsets.only(top: 10), child: text);
    return Semantics(
      button: true,
      label: S.current.Social_Open_Profile(name),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => openMalUser(context, name),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: text),
      ),
    );
  }
}

/// Decorative layered stack of posters: a rounded front cover with up to two
/// stepped receding layers peeking above the top edge showing slightly tinted
/// cover artwork. Purely visual (non-interactive).
class InterestStackPictures extends StatelessWidget {
  final List<String> images;

  const InterestStackPictures({super.key, required this.images});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clean = [
      for (final url in images)
        if (url.trim().isNotEmpty) url.trim(),
    ];
    if (clean.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Icon(
            Icons.collections_bookmark_outlined,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    // Reversed input from `_StackCard` puts the primary cover last; pick the
    // front cover cleanly and up to 2 receding tinted cover layers behind it.
    final ordered = clean.reversed.toList();
    final front = ordered.first;
    final backCount = ordered.length >= 3 ? 2 : (ordered.length == 2 ? 1 : 2);
    const stepY = 5.0;
    const stepX = 7.0;
    final frontTop = backCount * stepY;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var depth = backCount; depth >= 1; depth--)
            Positioned(
              left: depth * stepX,
              right: depth * stepX,
              top: (backCount - depth) * stepY,
              bottom: depth * stepY,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(
                      url: ordered.length > depth ? ordered[depth] : front,
                      fit: BoxFit.cover,
                      placeholderColor: scheme.surfaceContainerHighest,
                    ),
                    ColoredBox(
                      color: Colors.black.withValues(
                        alpha: depth == 1 ? 0.30 : 0.48,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: frontTop,
            bottom: 0,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: scheme.surface.withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
              child: AppImage(
                url: front,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(10),
                placeholderColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Address of a stack page on MyAnimeList: the scraper may give a path (`/stacks/12`) or a
/// full address. Null without a usable address.
String? stackWebUrl(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final value = url.trim();
  if (value.startsWith('http')) return value;
  return 'https://myanimelist.net${value.startsWith('/') ? '' : '/'}$value';
}

/// Fields offered by the share builder for a stack: link, title, author, the first
/// [maxEntries] entry titles and the description. Empty values are left out.
List<ShareField> stackShareFields({
  String? url,
  String? title,
  String? author,
  List<String> entries = const [],
  String? description,
  int maxEntries = 30,
}) {
  final shown = entries.where((e) => e.trim().isNotEmpty).take(maxEntries).toList();
  return [
    if (url != null && url.isNotEmpty) ShareField(label: S.current.Url, value: url, labelled: false),
    if (title != null && title.trim().isNotEmpty) ShareField(label: S.current.Title, value: title.trim()),
    if (author != null && author.isNotEmpty) ShareField(label: S.current.Social_Stack_Share_Author, value: author),
    if (shown.isNotEmpty)
      ShareField(
        label: S.current.Social_Stack_Share_Entries,
        value: shown.map((e) => '- $e').join('\n'),
        selected: false,
      ),
    if (description != null && description.trim().isNotEmpty)
      ShareField(label: S.current.Social_Stack_Share_Description, value: description.trim(), selected: false),
  ];
}
