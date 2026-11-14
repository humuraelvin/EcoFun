import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/toast.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/supa.dart';

const supportCategories = ['bug', 'account', 'points', 'idea', 'other'];

IconData supportIcon(String category) => switch (category) {
      'bug' => CupertinoIcons.ant_fill,
      'account' => CupertinoIcons.person_crop_circle_fill,
      'points' => CupertinoIcons.star_fill,
      'idea' => CupertinoIcons.lightbulb_fill,
      _ => CupertinoIcons.chat_bubble_text_fill,
    };

/// Status chip shared by the member and admin views: waiting, answered, or fixed for everyone.
class SupportStatus extends StatelessWidget {
  const SupportStatus(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color) = switch (status) {
      'replied' => ('support.statusReplied'.tr(), const Color(0xFF0A84FF)),
      'fixed' => ('support.statusFixed'.tr(), c.brand),
      _ => ('support.statusOpen'.tr(), const Color(0xFFFF9500)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: AppText.caption.semibold.c(color)),
    );
  }
}

/// Contact support: describe a problem, send it, and read the admin's answer here.
class SupportView extends StatefulWidget {
  const SupportView({super.key});

  @override
  State<SupportView> createState() => _SupportViewState();
}

class _SupportViewState extends State<SupportView> {
  final _message = TextEditingController();
  String _category = 'bug';
  bool _sending = false;
  List<SupportTicket>? _tickets;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await SupportRepository.mine();
      if (mounted) {
        setState(() {
          _tickets = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.length < 10) {
      showToast('support.tooShort'.tr(), error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      final t = await SupportRepository.send(_category, text);
      HapticFeedback.mediumImpact();
      _message.clear();
      showToast('support.sent'.tr());
      if (mounted) setState(() => _tickets = [t, ...?_tickets]);
    } catch (e) {
      showToast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tickets = _tickets;
    return Scaffold(
      backgroundColor: c.background,
      appBar: appTopBar(context, title: 'support.title'.tr()),
      body: RefreshIndicator(
        color: c.brand,
        onRefresh: _load,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 6, 16, MediaQuery.paddingOf(context).bottom + 32),
          children: [
            Text('support.intro'.tr(), style: AppText.subhead.c(c.secondaryLabel)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('support.whatAbout'.tr(), style: AppText.footnote.semibold.c(c.secondaryLabel)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final cat in supportCategories) _chip(c, cat),
                ]),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _message,
                  placeholder: 'support.placeholder'.tr(),
                  maxLines: 6,
                  minLines: 4,
                  maxLength: 1000,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 10),
                AppButton(label: 'support.send'.tr(), icon: CupertinoIcons.paperplane_fill, loading: _sending, onPressed: _send),
              ]),
            ),
            const SizedBox(height: 26),
            Text('support.myMessages'.tr(), style: AppText.title3.c(c.label)),
            const SizedBox(height: 10),
            if (tickets == null)
              _error != null
                  ? MessageView.error(_error!, onRetry: _load)
                  : const SkeletonPulse(child: SkeletonBox(height: 110, radius: 18))
            else if (tickets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text('support.none'.tr(), textAlign: TextAlign.center, style: AppText.subhead.c(c.tertiaryLabel)),
              )
            else
              for (final t in tickets) Padding(padding: const EdgeInsets.only(bottom: 12), child: _TicketCard(ticket: t)),
          ],
        ),
      ),
    );
  }

  Widget _chip(AppColors c, String cat) {
    final on = _category == cat;
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _category = cat);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? c.brand : c.fill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(supportIcon(cat), size: 15, color: on ? c.onBrand : c.secondaryLabel),
          const SizedBox(width: 6),
          Text('support.cat_$cat'.tr(), style: AppText.subhead.semibold.c(on ? c.onBrand : c.label)),
        ]),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = ticket;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(supportIcon(t.category), size: 16, color: c.secondaryLabel),
          const SizedBox(width: 6),
          Expanded(
            child: Text('${'support.cat_${t.category}'.tr()} · ${Fmt.ago(t.createdAt)}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.footnote.c(c.secondaryLabel)),
          ),
          SupportStatus(t.status),
        ]),
        const SizedBox(height: 8),
        Text(t.message, style: AppText.callout.c(c.label)),
        if (t.status == 'fixed' || t.reply != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.brandSoft, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(t.status == 'fixed' ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.person_crop_circle_badge_checkmark,
                    size: 16, color: c.brand),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${'support.teamReply'.tr()}${t.repliedAt == null ? '' : ' · ${Fmt.ago(t.repliedAt!)}'}',
                    style: AppText.footnote.semibold.c(c.brand),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text(t.reply ?? 'support.fixedDefault'.tr(), style: AppText.callout.c(c.label)),
            ]),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text('support.waiting'.tr(), style: AppText.caption.c(c.tertiaryLabel)),
        ],
      ]),
    );
  }
}
