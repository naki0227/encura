import 'dart:math';

import '../models/art_knowledge.dart';

/// "Who painted this?": one work and four artists to choose from.
class QuizQuestion {
  final Artwork artwork;
  final List<String> choices;

  const QuizQuestion({required this.artwork, required this.choices});

  String get answer => artwork.artist;
}

/// Up to [count] questions, each by a different artist. Wrong choices come
/// from the same region when there are enough, so the eye has to look at the
/// painting rather than guess from where it is from.
List<QuizQuestion> makeQuiz(ArtKnowledge knowledge, Random random, {int count = 10}) {
  final artists = knowledge.artworks.map((a) => a.artist).toSet().toList();
  if (artists.length < 4) return const [];
  final works = knowledge.artworks.where((a) => a.imageUrl.isNotEmpty).toList()..shuffle(random);
  final used = <String>{};
  final questions = <QuizQuestion>[];
  for (final work in works) {
    if (questions.length >= count) break;
    if (!used.add(work.artist)) continue;
    final region = knowledge.regionOf(work.artist);
    final near = artists.where((a) => a != work.artist && knowledge.regionOf(a) == region).toList()..shuffle(random);
    final far = artists.where((a) => a != work.artist && !near.contains(a)).toList()..shuffle(random);
    final choices = [work.artist, ...[...near, ...far].take(3)]..shuffle(random);
    questions.add(QuizQuestion(artwork: work, choices: choices));
  }
  return questions;
}
