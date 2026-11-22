import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, TabType, gotoPage, nullOrEmpty;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/screens/MAL/detail/pages/recommendations_list_page.dart';
import 'package:mywatchlist/services/api/MAL/web/recommendation_write_api.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/MAL/content/recommanimewidget.dart';

/// Recommendations; arrow and trailing card open the Search-style recommendations list.
DetailSection? recommendationsSection(DetailData data) {
  final recommendations = data.content?.recommendations;
  if (nullOrEmpty(recommendations)) return null;
  void openAll(BuildContext context) => gotoPage(
        context: context,
        newPage: RecommendationsListPage(
          id: data.id,
          category: data.category,
          recommendations: recommendations!,
        ),
      );
  return DetailSection(
    TabType.Recommendations,
    Builder(
      builder: (context) => RecommendedAnimeWidget(
        category: data.category,
        horizPadding: detailHorizPadding,
        recommAnime: recommendations!,
        onViewAll: () => openAll(context),
      ),
    ),
    trailing: _RecommendButton(category: data.category, id: data.id),
    onViewAll: openAll,
  );
}

class _RecommendButton extends StatelessWidget {
  const _RecommendButton({required this.category, required this.id});

  final String category;
  final int id;

  @override
  Widget build(BuildContext context) {
    final AccountBloc bloc;
    try {
      bloc = context.read<AccountBloc>();
    } on Object {
      return const SizedBox.shrink();
    }
    return BlocBuilder<AccountBloc, AccountState>(
      bloc: bloc,
      buildWhen: (a, b) => _isMal(a) != _isMal(b),
      builder: (context, state) {
        if (!_isMal(state)) return const SizedBox.shrink();
        return IconButton(
          tooltip: S.current.Mww_Recommend_Make,
          icon: const Icon(Icons.add_comment_outlined),
          onPressed: () => launchWebView(
            RecommendationWriteApi.pageUrl(category: category, id: id),
            context: context,
          ),
        );
      },
    );
  }

  static bool _isMal(AccountState state) =>
      state is AccountLoaded && state.selectedAccountType == AccountType.myanimelist;
}
