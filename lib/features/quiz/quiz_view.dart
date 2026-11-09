import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/routes.dart';
import '../../app/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/toast.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/supa.dart';

/// Environment quiz: 10 questions from EcoFun's ever-growing question pool, open any time.
/// Every answer is graded on the server — the app never knows the key.
/// The first 3 quizzes each day earn 2 points per correct answer; after that it's practice.
class QuizView extends StatefulWidget {
  const QuizView({super.key});

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  Quiz? _quiz;
  String? _error;
  int _index = 0;
  int? _pending; // option being checked by the server
  bool _finishing = false;
  QuizResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _quiz = null;
      _result = null;
      _index = 0;
    });
    try {
      final load = await QuizRepository.load(SessionController.to.language.value);
      if (!mounted) return;
      if (load.quiz == null) {
        setState(() => _result = QuizResult(
              score: load.completedScore ?? 0,
              total: load.completedTotal ?? 5,
              pointsAwarded: 0,
              alreadyCompleted: true,
            ));
        return;
      }
      final firstOpen = load.quiz!.questions.indexWhere((q) => q.answer == null);
      setState(() {
        _quiz = load.quiz;
        _index = firstOpen == -1 ? load.quiz!.questions.length - 1 : firstOpen;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  QuizQuestion get _q => _quiz!.questions[_index];

  Future<void> _choose(int option) async {
    if (_q.answer != null || _pending != null) return;
    HapticFeedback.selectionClick();
    setState(() => _pending = option);
    try {
      final a = await QuizRepository.answer(_quiz!.id, _q.position, option);
      _q.answer = a;
      a.correct ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
    } catch (e) {
      showToast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  Future<void> _next() async {
    if (_index < _quiz!.questions.length - 1) {
      setState(() => _index++);
      return;
    }
    setState(() => _finishing = true);
    try {
      final r = await QuizRepository.finish(_quiz!.id);
      HapticFeedback.heavyImpact();
      await SessionController.to.refreshHome();
      if (mounted) setState(() => _result = r);
    } catch (e) {
      showToast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final quiz = _quiz;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        leading: IconButton(icon: Icon(CupertinoIcons.xmark, color: c.label, size: 22), onPressed: Get.back),
        title: Text('quiz.title'.tr()),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: _result != null
              ? _Results(key: const ValueKey('r'), result: _result!, onPlayAgain: _load)
              : _error != null
                  ? MessageView.error(_error!, onRetry: _load)
                  : quiz == null
                      ? const _Preparing(key: ValueKey('p'))
                      : _questionView(c, quiz),
        ),
      ),
    );
  }

  Widget _questionView(AppColors c, Quiz quiz) {
    final q = _q;
    final answered = q.answer != null;
    return Column(
      key: const ValueKey('q'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(
            children: [
              for (var i = 0; i < quiz.questions.length; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: quiz.questions[i].answer == null
                          ? (i == _index ? c.brand.withValues(alpha: 0.45) : c.fill)
                          : (quiz.questions[i].answer!.correct ? c.brand : c.danger),
                    ),
                  ),
                ),
                if (i < quiz.questions.length - 1) const SizedBox(width: 5),
              ],
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: ListView(
              key: ValueKey(_index),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              children: [
                Row(children: [
                  Text('quiz.questionOf'.tr(args: ['${_index + 1}', '${quiz.questions.length}']),
                      style: AppText.footnote.semibold.c(c.secondaryLabel)),
                  const Spacer(),
                  Pill(
                    icon: quiz.countsForPoints ? CupertinoIcons.star_fill : CupertinoIcons.book_fill,
                    label: quiz.countsForPoints
                        ? 'quiz.pointsPill'.tr(args: ['${quiz.pointsPerCorrect}'])
                        : 'quiz.practice'.tr(),
                    color: quiz.countsForPoints ? c.gold : c.secondaryLabel,
                  ),
                ]),
                const SizedBox(height: 10),
                Text(q.question, style: AppText.title2.c(c.label)),
                const SizedBox(height: 22),
                for (var i = 0; i < q.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _Option(
                      letter: String.fromCharCode(65 + i),
                      text: q.options[i],
                      state: _optionState(q, i),
                      onTap: answered ? null : () => _choose(i),
                    ),
                  ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: answered
                    ? _Feedback(answer: q.answer!, options: q.options, points: quiz.countsForPoints ? quiz.pointsPerCorrect : 0)
                    : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: AppButton(
            label: _index == quiz.questions.length - 1 ? 'quiz.seeResults'.tr() : 'quiz.next'.tr(),
            loading: _finishing,
            onPressed: answered ? _next : null,
          ),
        ),
      ],
    );
  }

  _OptState _optionState(QuizQuestion q, int i) {
    if (_pending == i) return _OptState.checking;
    final a = q.answer;
    if (a == null) return _OptState.idle;
    if (i == a.correctIndex) return _OptState.correct;
    if (i == a.choice) return _OptState.wrong;
    return _OptState.dimmed;
  }
}

enum _OptState { idle, checking, correct, wrong, dimmed }

class _Option extends StatelessWidget {
  const _Option({required this.letter, required this.text, required this.state, this.onTap});
  final String letter;
  final String text;
  final _OptState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, border, badge, fg) = switch (state) {
      _OptState.correct => (c.bioSoft, c.bio, c.bio, c.label),
      _OptState.wrong => (c.danger.withValues(alpha: 0.10), c.danger, c.danger, c.label),
      _OptState.checking => (c.brandSoft, c.brand, c.brand, c.label),
      _OptState.dimmed => (c.surface, Colors.transparent, c.fill, c.tertiaryLabel),
      _OptState.idle => (c.surface, Colors.transparent, c.fill, c.label),
    };
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      haptic: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.6),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: badge, shape: BoxShape.circle),
              child: switch (state) {
                _OptState.checking => const CupertinoActivityIndicator(radius: 8, color: Colors.white),
                _OptState.correct => const Icon(CupertinoIcons.checkmark_alt, size: 18, color: Colors.white),
                _OptState.wrong => const Icon(CupertinoIcons.xmark, size: 15, color: Colors.white),
                _ => Text(letter, style: AppText.subhead.bold.c(c.secondaryLabel)),
              },
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: AppText.body.c(fg))),
          ],
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.answer, required this.options, required this.points});
  final QuizAnswer answer;
  final List<String> options;
  final int points;

  /// Splits "Why it is right. Practical tip: do this." into the reason and the tip.
  static (String, String?) _split(String text) {
    final m = RegExp(r'\s*(Practical tip|Tip|Impanuro|Inama)\s*:\s*', caseSensitive: false).firstMatch(text);
    if (m == null) return (text.trim(), null);
    final tip = text.substring(m.end).trim();
    return (text.substring(0, m.start).trim(), tip.isEmpty ? null : tip);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = answer.correct ? c.bio : c.danger;
    final (why, tip) = _split(answer.explanation);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(answer.correct ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.xmark_circle_fill, color: color, size: 22),
            const SizedBox(width: 8),
            Text(answer.correct ? 'quiz.correct'.tr() : 'quiz.notQuite'.tr(), style: AppText.headline.c(color)),
            const Spacer(),
            if (answer.correct && points > 0) Text('+$points ${'common.pts'.tr()}', style: AppText.subhead.semibold.c(c.bio)),
          ]),
          if (!answer.correct) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: c.bioSoft, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('quiz.rightAnswer'.tr(), style: AppText.caption.semibold.c(c.bio)),
                const SizedBox(height: 2),
                Text(options[answer.correctIndex], style: AppText.headline.c(c.label)),
              ]),
            ),
          ],
          if (why.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(CupertinoIcons.lightbulb_fill, size: 18, color: c.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('quiz.why'.tr(), style: AppText.caption.semibold.c(c.secondaryLabel)),
                  const SizedBox(height: 2),
                  Text(why, style: AppText.callout.c(c.label)),
                ]),
              ),
            ]),
          ],
          if (tip != null) ...[
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(CupertinoIcons.leaf_arrow_circlepath, size: 18, color: c.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('quiz.tip'.tr(), style: AppText.caption.semibold.c(c.secondaryLabel)),
                  const SizedBox(height: 2),
                  Text(tip, style: AppText.callout.c(c.label)),
                ]),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Preparing extends StatelessWidget {
  const _Preparing({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SkeletonPulse(
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
                child: Icon(CupertinoIcons.sparkles, size: 36, color: c.brand),
              ),
            ),
            const SizedBox(height: 20),
            Text('quiz.preparing'.tr(), textAlign: TextAlign.center, style: AppText.title3.c(c.label)),
            const SizedBox(height: 6),
            Text('quiz.preparingBody'.tr(), textAlign: TextAlign.center, style: AppText.callout.c(c.secondaryLabel)),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({super.key, required this.result, required this.onPlayAgain});
  final QuizResult result;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ratio = result.total == 0 ? 0.0 : result.score / result.total;
    final headline = ratio >= 0.8
        ? 'quiz.great'.tr()
        : ratio >= 0.4
            ? 'quiz.good'.tr()
            : 'quiz.keepLearning'.tr();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        children: [
          const Spacer(),
          ProgressRing(
            value: ratio,
            color: c.brand,
            track: c.fill,
            size: 150,
            stroke: 14,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${result.score}/${result.total}', style: AppText.largeTitle.c(c.label)),
              Text('quiz.correctLabel'.tr(), style: AppText.footnote.c(c.secondaryLabel)),
            ]),
          ),
          const SizedBox(height: 26),
          Text(headline, textAlign: TextAlign.center, style: AppText.title1.c(c.label)),
          const SizedBox(height: 8),
          Text(
            result.pointsAwarded > 0
                ? 'quiz.earned'.tr(args: ['${result.pointsAwarded}'])
                : result.alreadyCompleted
                    ? 'quiz.alreadyDone'.tr()
                    : 'quiz.practiceDone'.tr(),
            textAlign: TextAlign.center,
            style: AppText.callout.c(c.secondaryLabel),
          ),
          if (!result.alreadyCompleted) ...[
            const SizedBox(height: 6),
            Text(
              result.scoredLeft > 0 ? 'quiz.scoredLeft'.plural(result.scoredLeft) : 'quiz.noScoredLeft'.tr(),
              textAlign: TextAlign.center,
              style: AppText.footnote.c(c.tertiaryLabel),
            ),
          ],
          const Spacer(),
          Obx(() {
            final p = SessionController.to.progress;
            return Column(children: [
              AppButton(label: 'quiz.playAgain'.tr(), icon: CupertinoIcons.arrow_2_circlepath, onPressed: onPlayAgain),
              const SizedBox(height: 10),
              if (!p.missionDone) ...[
                AppButton(
                  label: 'quiz.startMission'.tr(),
                  icon: CupertinoIcons.leaf_arrow_circlepath,
                  kind: ButtonStyleKind.tinted,
                  onPressed: () => Get.offNamed(Routes.mission),
                ),
                const SizedBox(height: 10),
              ],
              AppButton(label: 'quiz.backHome'.tr(), kind: ButtonStyleKind.plain, onPressed: Get.back),
            ]);
          }),
        ],
      ),
    );
  }
}
