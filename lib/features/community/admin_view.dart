import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/toast.dart';
import '../../data/repositories.dart';
import '../../data/supa.dart';

/// Admins (profiles.is_admin = true) can reward members for offline actions.
class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  final _email = TextEditingController();
  final _points = TextEditingController();
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _points.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _grant() async {
    final pts = int.tryParse(_points.text.trim()) ?? 0;
    if (!_email.text.contains('@') || pts < 1 || pts > 500 || _reason.text.trim().length < 3) {
      showToast('admin.invalid'.tr(), error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final name = await CommunityRepository.grantPoints(_email.text.trim(), pts, _reason.text.trim());
      HapticFeedback.heavyImpact();
      showToast('admin.granted'.tr(args: ['$pts', name]));
      _points.clear();
      _reason.clear();
      SessionController.to.refreshHome();
    } catch (e) {
      showToast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: appTopBar(context, title: 'admin.portal'.tr()),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('admin.intro'.tr(), style: AppText.callout.c(c.secondaryLabel)),
          const SizedBox(height: 16),
          AppTextField(
            controller: _email,
            placeholder: 'admin.email'.tr(),
            icon: CupertinoIcons.mail,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: _points,
            placeholder: 'admin.points'.tr(),
            icon: CupertinoIcons.star,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: _reason,
            placeholder: 'admin.reason'.tr(),
            icon: CupertinoIcons.text_bubble,
            maxLength: 200,
          ),
          const SizedBox(height: 16),
          AppButton(label: 'admin.grant'.tr(), icon: CupertinoIcons.gift_fill, loading: _busy, onPressed: _grant),
        ],
      ),
    );
  }
}
