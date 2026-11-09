import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/toast.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/supa.dart';
import 'admin_controller.dart';

/// Write an announcement in English and Kinyarwanda (with one-tap translation) and send it to
/// every member's notifications, and optionally by email.
class AdminAnnounceView extends StatefulWidget {
  const AdminAnnounceView({super.key});

  @override
  State<AdminAnnounceView> createState() => _AdminAnnounceViewState();
}

class _AdminAnnounceViewState extends State<AdminAnnounceView> {
  final ctrl = AdminController.to;
  final _titleEn = TextEditingController();
  final _bodyEn = TextEditingController();
  final _titleRw = TextEditingController();
  final _bodyRw = TextEditingController();
  bool _email = false;
  bool _sending = false;
  String? _translating; // 'rw' or 'en'

  @override
  void dispose() {
    for (final t in [_titleEn, _bodyEn, _titleRw, _bodyRw]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _translate(String to) async {
    final from = to == 'rw' ? 'en' : 'rw';
    final srcTitle = from == 'en' ? _titleEn : _titleRw;
    final srcBody = from == 'en' ? _bodyEn : _bodyRw;
    if (srcTitle.text.trim().isEmpty && srcBody.text.trim().isEmpty) {
      showToast('admin.writeFirst'.tr(), error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _translating = to);
    try {
      final results = await Future.wait([
        AdminRepository.translate(srcTitle.text.trim(), from, to),
        AdminRepository.translate(srcBody.text.trim(), from, to),
      ]);
      (to == 'rw' ? _titleRw : _titleEn).text = results[0];
      (to == 'rw' ? _bodyRw : _bodyEn).text = results[1];
    } catch (e) {
      showToast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _translating = null);
    }
  }

  Future<void> _send() async {
    final hasEn = _titleEn.text.trim().isNotEmpty && _bodyEn.text.trim().isNotEmpty;
    final hasRw = _titleRw.text.trim().isNotEmpty && _bodyRw.text.trim().isNotEmpty;
    if (!hasEn && !hasRw) {
      showToast('errors.announceEmpty'.tr(), error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      final n = await AdminRepository.announce(
        titleEn: _titleEn.text,
        bodyEn: _bodyEn.text,
        titleRw: _titleRw.text,
        bodyRw: _bodyRw.text,
        email: _email,
      );
      HapticFeedback.heavyImpact();
      showToast('admin.announceSent'.plural(n), icon: CupertinoIcons.speaker_2_fill);
      for (final t in [_titleEn, _bodyEn, _titleRw, _bodyRw]) {
        t.clear();
      }
      setState(() => _email = false);
      ctrl.refreshAnnouncements();
    } catch (e) {
      showToast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Announcement a) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('admin.deleteAnnouncement'.tr()),
        content: Text('admin.deleteAnnouncementMessage'.tr()),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(ctx, true), child: Text('profile.delete'.tr())),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminRepository.deleteAnnouncement(a.id);
      ctrl.announcements.remove(a);
    } catch (e) {
      showToast(friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = SessionController.to.language.value;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: LargeTitlePage(
        title: 'admin.announce'.tr(),
        onRefresh: ctrl.refreshAnnouncements,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.list(children: [
              Text('admin.announceIntro'.tr(), style: AppText.subhead.c(c.secondaryLabel)),
              const SizedBox(height: 14),
              _langBlock(c, '🇬🇧  English', _titleEn, _bodyEn, 'en'),
              const SizedBox(height: 14),
              _langBlock(c, '🇷🇼  Ikinyarwanda', _titleRw, _bodyRw, 'rw'),
              const SizedBox(height: 14),
              GroupedSection(
                footer: 'admin.emailFooter'.tr(),
                children: [
                  GroupedRow(
                    icon: CupertinoIcons.envelope_fill,
                    iconColor: const Color(0xFFFF375F),
                    title: 'admin.alsoEmail'.tr(),
                    showChevron: false,
                    trailing: CupertinoSwitch(value: _email, activeTrackColor: c.brand, onChanged: (v) => setState(() => _email = v)),
                    onTap: () => setState(() => _email = !_email),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppButton(label: 'admin.sendAnnouncement'.tr(), icon: CupertinoIcons.paperplane_fill, loading: _sending, onPressed: _send),
            ]),
          ),
          SliverToBoxAdapter(child: SectionHeader('admin.pastAnnouncements'.tr())),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Obx(() {
                final list = ctrl.announcements.toList();
                if (list.isEmpty) {
                  return ctrl.announcementsLoading.value
                      ? const Padding(padding: EdgeInsets.all(20), child: CupertinoActivityIndicator())
                      : Text('admin.noAnnouncements'.tr(), textAlign: TextAlign.center, style: AppText.subhead.c(c.secondaryLabel));
                }
                return Column(children: [
                  for (final a in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(a.title(lang), style: AppText.headline.c(c.label)),
                              const SizedBox(height: 3),
                              Text(a.body(lang), maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.subhead.c(c.secondaryLabel)),
                              const SizedBox(height: 6),
                              Text(
                                '${Fmt.ago(a.createdAt)} · ${'admin.recipients'.plural(a.recipients)}${a.emailed ? ' · ${'admin.emailed'.tr()}' : ''}',
                                style: AppText.caption.c(c.tertiaryLabel),
                              ),
                            ]),
                          ),
                          IconButton(onPressed: () => _delete(a), icon: Icon(CupertinoIcons.trash, color: c.danger, size: 20)),
                        ]),
                      ),
                    ),
                ]);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _langBlock(AppColors c, String label, TextEditingController title, TextEditingController body, String lang) {
    final busy = _translating == lang;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label, style: AppText.headline.c(c.label))),
          TextButton.icon(
            onPressed: _translating != null ? null : () => _translate(lang),
            icon: busy
                ? const SizedBox(width: 14, height: 14, child: CupertinoActivityIndicator(radius: 7))
                : Icon(CupertinoIcons.globe, size: 16, color: c.brand),
            label: Text(lang == 'rw' ? 'admin.translateToRw'.tr() : 'admin.translateToEn'.tr(), style: AppText.footnote.semibold.c(c.brand)),
          ),
        ]),
        const SizedBox(height: 6),
        AppTextField(
          key: ValueKey('title-$lang'),
          controller: title,
          placeholder: 'admin.announceTitle'.tr(),
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 8),
        AppTextField(
          key: ValueKey('body-$lang'),
          controller: body,
          placeholder: 'admin.announceBody'.tr(),
          maxLines: 6,
          minLines: 3,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
        ),
      ]),
    );
  }
}
