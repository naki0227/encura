import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/models/art_knowledge.dart';
import '../../../core/utils/quiz.dart';
import '../../theme/tokens.dart';
import '../../widgets/motion.dart';
import 'learn_widgets.dart';

/// Ten paintings, four artists each: a quick way to train the eye.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.knowledge});

  final ArtKnowledge knowledge;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late List<QuizQuestion> _questions;
  int _index = 0;
  int _correct = 0;
  String? _picked;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _questions = makeQuiz(widget.knowledge, Random());
    _index = 0;
    _correct = 0;
    _picked = null;
  }

  void _pick(String choice) {
    if (_picked != null) return;
    setState(() {
      _picked = choice;
      if (choice == _questions[_index].answer) _correct++;
    });
  }

  void _next() => setState(() {
        _index++;
        _picked = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('この絵は誰の作品？')),
      body: _questions.isEmpty
          ? const Center(child: Text('作品が足りないため、まだ遊べません。', style: TextStyle(color: Palette.textSub)))
          : _index >= _questions.length
              ? _result()
              : _question(_questions[_index]),
    );
  }

  Widget _question(QuizQuestion q) {
    final answered = _picked != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      children: [
        Text('${_index + 1} / ${_questions.length}',
            style: const TextStyle(color: Palette.gold, fontSize: 12, letterSpacing: 2)),
        const SizedBox(height: 12),
        Container(
          height: 320,
          color: Palette.frame,
          padding: const EdgeInsets.all(12),
          child: KnowledgeImage(q.artwork.imageUrl, fit: BoxFit.contain),
        ),
        const SizedBox(height: 20),
        for (final choice in q.choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Pressable(
              onTap: () => _pick(choice),
              child: AnimatedContainer(
                duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
                curve: Motion.curve,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: answered && choice == q.answer ? Palette.gold : Palette.frame,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: answered && choice == _picked && choice != q.answer ? Palette.textSub : Palette.line,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        choice,
                        style: TextStyle(
                          color: answered && choice == q.answer
                              ? Palette.room
                              : (answered && choice != _picked ? Palette.textSub : Palette.text),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (answered && choice == _picked)
                      Icon(choice == q.answer ? Icons.check : Icons.close,
                          size: 18, color: choice == q.answer ? Palette.room : Palette.textSub),
                  ],
                ),
              ),
            ),
          ),
        if (answered) ...[
          const SizedBox(height: 8),
          Text(
            _picked == q.answer ? '正解！' : '正解は${q.answer}でした。',
            style: const TextStyle(color: Palette.text, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '「${q.artwork.title}」${q.artwork.year != null ? '（${q.artwork.yearLabel}）' : ''}',
            style: const TextStyle(color: Palette.textSub, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => openArtist(context, q.answer, widget.knowledge),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.gold,
                    side: const BorderSide(color: Palette.gold),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text('画家を見る'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.text,
                    foregroundColor: Palette.room,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: Text(_index + 1 == _questions.length ? '結果を見る' : '次へ'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _result() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('RESULT', style: TextStyle(fontFamily: 'Helvetica', color: Palette.gold, fontSize: 11, letterSpacing: 2.4)),
            const SizedBox(height: 12),
            Text('${_questions.length}問中 $_correct問 正解',
                style: const TextStyle(color: Palette.text, fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const Text('間違えた画家のページを開くと、描き方の特徴がつかめます。',
                textAlign: TextAlign.center, style: TextStyle(color: Palette.textSub, fontSize: 13, height: 1.8)),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => setState(_start),
              style: FilledButton.styleFrom(
                backgroundColor: Palette.text,
                foregroundColor: Palette.room,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text('もう一度'),
            ),
          ],
        ),
      ),
    );
  }
}
