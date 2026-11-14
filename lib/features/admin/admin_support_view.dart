import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/toast.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/supa.dart';
import '../support/support_view.dart';
import 'admin_controller.dart';

/// Members' support messages. Reply to one member, or mark a problem fixed for everyone and announce it.
class AdminSupportView extends StatefulWidget {
  const AdminSupportView({super.key});

  @override
  State<AdminSupportView> createState() => _AdminSupportViewState();
}

class _AdminSupportViewState extends State<AdminSupportView> {
  String _status = 'open';
  List<SupportTicket>? _items;
  String? _error;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = _status;
    try {
      final list = await AdminRepository.support(status: status);
      if (mounted && status == _status) {
        setState(() {
          _items = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  void _switch(String? s) {
    if (s == null || s == _status) return;
    setState(() {
      _status = s;
      _items = null;
      _error = null;
    });
    _load();
  }

  void _changed() {
    if (Get.isRegistered<AdminController>()) AdminController.to.refreshDashboard();
  }

  Future<String?> _writeReply(SupportTicket t, {required bool fixed}) {
    final ctrl = TextEditingController(text: fixed ? 'support.fixedDefaultAdmin'.tr() : (t.reply ?? ''));
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(fixed ? 'support.fixedTitle'.tr() : 'support.replyTo'.tr(args: [t.userName ?? '']),
              textAlign: TextAlign.center, style: AppText.headline),
          const SizedBox(height: 6),
          Text(fixed ? 'support.fixedHint'.tr() : 'support.replyHint'.tr(),
              textAlign: TextAlign.center, style: AppText.footnote.c(ctx.colors.secondaryLabel)),
          const SizedBox(height: 14),
          AppTextField(
            controller: ctrl,
            placeholder: 'support.replyPlaceholder'.tr(),
            autofocus: true,
            maxLines: 6,
            minLines: 3,
            maxLength: 1000,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          AppButton(
            label: fixed ? 'support.markFixed'.tr() : 'support.sendReply'.tr(),
            icon: fixed ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.paperplane_fill,
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          ),
        ]),
      ),
    ).whenComplete(ctrl.dispose);
  }

  Future<void> _answer(SupportTicket t, {required bool fixed}) async {
    final reply = await _writeReply(t, fixed: fixed);
    if (reply == null) return;
    if (!fixed && reply.length < 2) {
      showToast('support.writeReply'.tr(), error: true);
      return;
    }
    setState(() => _busy.add(t.id));
    try {
      await AdminRepository.answerSupport(t.id, reply, fixed: fixed);
      HapticFeedback.mediumImpact();
      showToast(fixed ? 'support.markedFixed'.tr() : 'support.replySent'.tr());
      if (mounted) {
        if (_status == 'open') {
          setState(() => _items?.remove(t));
        } else {
          _load();
        }
      }
      _changed();
      if (fixed && mounted) await _offerAnnouncement(t);
    } catch (e) {
      showToast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(t.id));
    }
  }

  /// A problem that affected everyone: tell every member it's fixed.
  Future<void> _offerAnnouncement(SupportTicket t) async {
    final go = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('support.announceTitle'.tr()),
        content: Text('support.announceBody'.tr()),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: Text('support.notNow'.tr())),
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx, true), child: Text('support.announce'.tr())),
        ],
      ),
    );
    if (go != true || !Get.isRegistered<AdminController>()) return;
    final admin = AdminController.to;
    admin.announceDraft.value = (
      en: (title: 'support.draftTitleEn'.tr(), body: 'support.draftBodyEn'.tr(args: [t.message.length > 80 ? '${t.message.substring(0, 80)}…' : t.message])),
      rw: (title: 'support.draftTitleRw'.tr(), body: 'support.draftBodyRw'.tr()),
    );
    admin.tab.value = 3;
    Get.until((route) => route.settings.name == Routes.admin || route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = _items;
    return Scaffold(
      backgroundColor: c.background,
      appBar: appTopBar(context, title: 'support.adminTitle'.tr()),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<String>(
              groupValue: _status,
              backgroundColor: c.fill,
              thumbColor: c.surface,
              padding: const EdgeInsets.all(3),
              children: {
                'open': _segment('support.tabOpen'.tr()),
                'done': _segment('support.tabDone'.tr()),
              },
              onValueChanged: _switch,
            ),
          ),
        ),
        Expanded(
          child: items == null
              ? (_error != null ? MessageView.error(_error!, onRetry: _load) : const CenteredSpinner())
              : RefreshIndicator(
                  color: c.brand,
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(children: [
                          SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
                          MessageView(
                            icon: CupertinoIcons.tray,
                            title: _status == 'open' ? 'support.adminEmpty'.tr() : 'support.adminEmptyDone'.tr(),
                          ),
                        ])
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(16, 6, 16, MediaQuery.paddingOf(context).bottom + 24),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _AdminTicketCard(
                            ticket: items[i],
                            busy: _busy.contains(items[i].id),
                            onReply: () => _answer(items[i], fixed: false),
                            onFixed: () => _answer(items[i], fixed: true),
                          ),
                        ),
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

class _AdminTicketCard extends StatelessWidget {
  const _AdminTicketCard({required this.ticket, required this.busy, required this.onReply, required this.onFixed});
  final SupportTicket ticket;
  final bool busy;
  final VoidCallback onReply;
  final VoidCallback onFixed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = ticket;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Pressable(
          scale: 1,
          onTap: t.userId == null ? null : () => Get.toNamed(Routes.adminUser, arguments: t.userId),
          child: Row(children: [
            Avatar(name: t.userName ?? '', url: t.userAvatar, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.userName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.headline.c(c.label)),
                Text('${t.userEmail ?? ''} · ${Fmt.ago(t.createdAt)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.c(c.secondaryLabel)),
              ]),
            ),
            SupportStatus(t.status),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Icon(supportIcon(t.category), size: 15, color: c.secondaryLabel),
          const SizedBox(width: 6),
          Text('support.cat_${t.category}'.tr(), style: AppText.footnote.semibold.c(c.secondaryLabel)),
        ]),
        const SizedBox(height: 6),
        Text(t.message, style: AppText.callout.c(c.label)),
        if (t.reply != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.brandSoft, borderRadius: BorderRadius.circular(14)),
            child: Text(t.reply!, style: AppText.subhead.c(c.label)),
          ),
        ],
        const SizedBox(height: 12),
        if (busy)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: CupertinoActivityIndicator()))
        else
          Row(children: [
            Expanded(
              child: AppButton(
                label: t.isOpen ? 'support.reply'.tr() : 'support.editReply'.tr(),
                icon: CupertinoIcons.arrowshape_turn_up_left_fill,
                kind: ButtonStyleKind.tinted,
                height: 46,
                onPressed: onReply,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: 'support.fixedForAll'.tr(),
                icon: CupertinoIcons.checkmark_seal_fill,
                kind: ButtonStyleKind.plain,
                height: 46,
                onPressed: onFixed,
              ),
            ),
          ]),
      ]),
    );
  }
}
