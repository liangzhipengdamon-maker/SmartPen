import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartpen_frontend/main.dart';
import 'package:smartpen_frontend/models/character.dart';
import 'package:smartpen_frontend/widgets/character_display.dart';
import 'package:smartpen_frontend/widgets/score_panel.dart';

void main() {
  group('SmartPen App Tests', () {
    testWidgets('App should start with HomeScreen', (tester) async {
      await tester.pumpWidget(const SmartPenApp());

      expect(find.text('智笔 - AI 书法教学'), findsOneWidget);
    });
  });

  group('Character Model Tests', () {
    test('PointData should convert from Hanzi 1024 coordinates', () {
      final point = PointData.fromHanzi1024(512, 512);

      expect(point.x, closeTo(0.5, 0.001));
      expect(point.y, closeTo(0.5, 0.001));
    });

    test('PointData should convert to Hanzi 1024 coordinates', () {
      final point = PointData(x: 0.5, y: 0.5);
      final (x, y) = point.toHanzi1024();

      expect(x, 512);
      expect(y, 512);
    });

    test('ScoreResult should return correct grade', () {
      final excellent = ScoreResult(
        totalScore: 95,
        strokeCount: 5,
        perfectStrokes: 5,
        averageScore: 0.95,
      );
      expect(excellent.grade, '优秀');

      final good = ScoreResult(
        totalScore: 75,
        strokeCount: 5,
        perfectStrokes: 3,
        averageScore: 0.75,
      );
      expect(good.grade, '良好');

      final pass = ScoreResult(
        totalScore: 55,
        strokeCount: 5,
        perfectStrokes: 1,
        averageScore: 0.55,
      );
      expect(pass.grade, '及格');

      final fail = ScoreResult(
        totalScore: 35,
        strokeCount: 5,
        perfectStrokes: 0,
        averageScore: 0.35,
      );
      expect(fail.grade, '需练习');
    });

    test('CharacterData should create empty character', () {
      final character = CharacterData.empty('永');

      expect(character.character, '永');
      expect(character.strokes.isEmpty, true);
      expect(character.strokeCount, 0);
    });
  });

  group('Widget Tests', () {
    testWidgets('ScorePanel should display score', (tester) async {
      final score = ScoreResult(
        totalScore: 85.5,
        strokeCount: 5,
        perfectStrokes: 3,
        averageScore: 0.85,
        feedback: '书写工整，继续保持',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScorePanel(score: score),
          ),
        ),
      );

      expect(find.text('85.5 分'), findsOneWidget);
      expect(find.text('良好'), findsOneWidget);
      expect(find.text('书写工整，继续保持'), findsOneWidget);
    });

    testWidgets('CharacterDisplay should show character info', (tester) async {
      final character = CharacterData(
        character: '永',
        strokes: [],
        strokeCount: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterDisplay(character: character),
          ),
        ),
      );

      expect(find.text('范字'), findsOneWidget);
      expect(find.text('笔画: 5'), findsOneWidget);
    });
  });
}
