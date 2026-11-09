import 'package:cloud_functions/cloud_functions.dart';
import 'package:eco_step/core/util/app_state_manager.dart';
import 'package:eco_step/core/util/style/colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final List<QuizQuestion> questions = const [
    QuizQuestion('What makes flooding worse in urban areas?', [
      'Parks and trees',
      'Paved surfaces and blocked drains',
      'Clean rivers',
      'More gardens',
    ], 1),
    QuizQuestion('What is the main human cause of climate change?', [
      'Natural disasters',
      'Greenhouse gas emissions',
      'Ocean currents',
      'The Moon',
    ], 1),
    QuizQuestion('Which item is usually compostable?', [
      'Fruit peels',
      'A glass jar',
      'A battery',
      'A plastic bag',
    ], 0),
    QuizQuestion('Which action helps reduce plastic pollution?', [
      'Use more single-use bags',
      'Burn plastic waste',
      'Carry a reusable bag',
      'Dump waste in rivers',
    ], 2),
    QuizQuestion('Which source produces renewable electricity?', [
      'Diesel generator',
      'Coal',
      'Petrol',
      'Solar panels',
    ], 3),
  ];
  int current = 0;
  int? selected;
  final answers = <int>[];
  bool submitting = false;

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors.of(context);
    final question = questions[current];
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Climate quiz'),
        backgroundColor: colors.background,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Question ${current + 1} of ${questions.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (current + 1) / questions.length,
              color: colors.primary,
            ),
            const SizedBox(height: 28),
            Text(
              question.question,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...question.options.asMap().entries.map((entry) {
              final isCorrect = entry.key == question.correctAnswer;
              final isChosen = entry.key == selected;
              final answered = selected != null;
              final color = !answered
                  ? colors.gray20
                  : isCorrect
                  ? Colors.green.withValues(alpha: .16)
                  : isChosen
                  ? Colors.red.withValues(alpha: .14)
                  : colors.gray20;
              return Card(
                color: color,
                child: ListTile(
                  title: Text(entry.value),
                  leading: Icon(
                    !answered
                        ? Icons.circle_outlined
                        : isCorrect
                        ? Icons.check_circle
                        : isChosen
                        ? Icons.cancel
                        : Icons.circle_outlined,
                    color: !answered
                        ? colors.gray700
                        : isCorrect
                        ? Colors.green
                        : isChosen
                        ? Colors.red
                        : colors.gray300,
                  ),
                  onTap: answered
                      ? null
                      : () => setState(() => selected = entry.key),
                ),
              );
            }),
            if (selected != null) ...[
              const SizedBox(height: 12),
              Text(
                selected == question.correctAnswer
                    ? 'Correct! +5 points'
                    : 'Not quite. The correct answer is “${question.options[question.correctAnswer]}”.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected == question.correctAnswer
                      ? Colors.green
                      : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: selected == null || submitting ? null : _next,
              child: submitting
                  ? const CircularProgressIndicator()
                  : Text(
                      current == questions.length - 1
                          ? 'Finish quiz'
                          : 'Next question',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _next() async {
    answers.add(selected!);
    if (current < questions.length - 1) {
      setState(() {
        current++;
        selected = null;
      });
      return;
    }
    setState(() => submitting = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('submitQuizAnswers')
          .call({'answers': answers});
      final data = Map<String, dynamic>.from(result.data as Map);
      AppStateManager.completeQuiz();
      if (!mounted) return;
      Get.back();
      Get.snackbar(
        'Quiz complete',
        data['alreadyCompleted'] == true
            ? 'You have already earned today’s quiz points.'
            : 'You scored ${data['score']}/${questions.length} and earned ${data['pointsAwarded']} points.',
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Could not save your score',
        e.message ?? 'Check your connection and try again.',
      );
      setState(() {
        answers.removeLast();
        submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      Get.snackbar(
        'Could not save your score',
        'Check your connection and try again.',
      );
      setState(() {
        answers.removeLast();
        submitting = false;
      });
    }
  }
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswer;
  const QuizQuestion(this.question, this.options, this.correctAnswer);
}
