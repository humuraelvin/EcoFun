import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tab-root page with an iOS large title that collapses on scroll,
/// pull-to-refresh, and room for the tab bar at the bottom.
class LargeTitlePage extends StatelessWidget {
  const LargeTitlePage({
    super.key,
    required this.title,
    required this.slivers,
    this.controller,
    this.onRefresh,
    this.trailing,
    this.leading,
    this.bottomInset = true,
  });

  final String title;
  final List<Widget> slivers;
  final ScrollController? controller;
  final Future<void> Function()? onRefresh;
  final Widget? trailing;
  final Widget? leading;
  final bool bottomInset;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(
        controller: controller,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            trailing: trailing,
            leading: leading,
            backgroundColor: c.background,
            border: Border(bottom: BorderSide(color: c.separator.withValues(alpha: 0.0), width: 0)),
            transitionBetweenRoutes: false,
            stretch: false,
          ),
          if (onRefresh != null) CupertinoSliverRefreshControl(onRefresh: onRefresh),
          ...slivers,
          if (bottomInset) SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 90)),
        ],
      ),
    );
  }
}

/// Standard top bar for pushed pages.
PreferredSizeWidget appTopBar(BuildContext context, {String? title, List<Widget>? actions, Widget? leading}) {
  final c = context.colors;
  return AppBar(
    backgroundColor: c.background,
    leading: leading ??
        (Navigator.of(context).canPop()
            ? CupertinoNavigationBarBackButton(color: c.brand, onPressed: () => Navigator.of(context).maybePop())
            : null),
    title: title == null ? null : Text(title),
    actions: actions,
  );
}
