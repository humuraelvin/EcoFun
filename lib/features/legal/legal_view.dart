import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/large_title_page.dart';
import 'legal_content.dart';

/// Privacy Policy and Terms of Use. Open with `arguments: 'terms'` to start on the terms.
class LegalView extends StatefulWidget {
  const LegalView({super.key});

  @override
  State<LegalView> createState() => _LegalViewState();
}

class _LegalViewState extends State<LegalView> {
  late String _doc = Get.arguments == 'terms' ? 'terms' : 'privacy';
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(String? doc) {
    if (doc == null || doc == _doc) return;
    setState(() => _doc = doc);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rw = context.locale.languageCode == 'rw';
    final sections = _doc == 'terms' ? (rw ? termsRw : termsEn) : (rw ? privacyRw : privacyEn);
    return Scaffold(
      backgroundColor: c.background,
      appBar: appTopBar(context, title: 'legal.title'.tr()),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<String>(
              groupValue: _doc,
              backgroundColor: c.fill,
              thumbColor: c.surface,
              padding: const EdgeInsets.all(3),
              children: {
                'privacy': _segment('legal.privacy'.tr()),
                'terms': _segment('legal.terms'.tr()),
              },
              onValueChanged: _select,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.paddingOf(context).bottom + 32),
            children: [
              Text(_doc == 'terms' ? 'legal.terms'.tr() : 'legal.privacy'.tr(), style: AppText.title1.c(c.label)),
              const SizedBox(height: 4),
              Text('legal.updated'.tr(args: [rw ? legalUpdated.rw : legalUpdated.en]), style: AppText.footnote.c(c.secondaryLabel)),
              for (final (i, (heading, paragraphs)) in sections.indexed) ...[
                const SizedBox(height: 22),
                Text('${i + 1}. $heading', style: AppText.headline.c(c.label)),
                const SizedBox(height: 6),
                for (final p in paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: paragraphs.length > 1
                        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8, right: 10),
                              child: Container(width: 5, height: 5, decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle)),
                            ),
                            Expanded(child: Text(p, style: AppText.callout.c(c.secondaryLabel).copyWith(height: 1.5))),
                          ])
                        : Text(p, style: AppText.callout.c(c.secondaryLabel).copyWith(height: 1.5)),
                  ),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _segment(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.subhead.semibold),
      );
}
