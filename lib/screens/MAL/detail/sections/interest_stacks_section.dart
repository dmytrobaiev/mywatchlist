import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show TabType, gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/screens/MAL/detail/pages/interest_stacks_page.dart';
import 'package:mywatchlist/widgets/MAL/content/intereststackwidget.dart';

/// Interest stacks containing this title; arrow and trailing card load all of them.
DetailSection? interestStacksSection(DetailData data) {
  if (data.interestStacks.isEmpty) return null;
  void openAll(BuildContext context) => gotoPage(
        context: context,
        newPage: Scaffold(
          appBar: AppBar(title: Text(S.current.Interest_Stacks)),
          body: InterestStacksAllBody(
            category: data.category,
            categoryId: data.id,
            initialStacks: data.interestStacks,
          ),
        ),
      );
  return DetailSection(
    TabType.Interest_Stacks,
    Builder(
      builder: (context) => InterestStackContentList(
        horizPadding: detailHorizPadding,
        interestStacks: data.interestStacks,
        onViewAll: () => openAll(context),
      ),
    ),
    onViewAll: openAll,
  );
}
