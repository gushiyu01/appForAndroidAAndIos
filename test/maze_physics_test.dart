import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:app_for_android_a_and_ios/models/maze.dart';
import 'package:app_for_android_a_and_ios/models/maze_physics.dart';

void main() {
  test('turbo diagonal travel cannot cross a closed corner', () {
    int checked = 0;
    for (int seed = 0; seed < 20; seed++) {
      final Maze maze = Maze.generate(random: Random(seed));
      for (int row = 0; row < maze.rows - 1; row++) {
        for (int col = 0; col < maze.columns - 1; col++) {
          if (maze.hasWall(col, row, MazeDirection.right) ||
              maze.hasWall(col, row, MazeDirection.bottom) ||
              !maze.hasWall(col + 1, row, MazeDirection.bottom) ||
              !maze.hasWall(col, row + 1, MazeDirection.right)) {
            continue;
          }
          final MazePhysics physics = MazePhysics(
            maze: maze,
            position: Offset(col + 0.7, row + 0.7),
            velocity: const Offset(8, 8),
          );
          expect(physics.canOccupy(physics.position), isTrue);
          expect(physics.canOccupy(Offset(col + 0.9, row + 0.9)), isFalse);
          physics.step(
            seconds: 0.05,
            gravity: const Offset(1, 1),
            gravityScale: 22,
            maxSpeed: 14,
          );
          expect(physics.canOccupy(physics.position), isTrue);
          expect(
            physics.position.dx > col + 1 && physics.position.dy > row + 1,
            isFalse,
          );
          checked++;
        }
      }
    }
    expect(checked, greaterThan(0));
  });

  test('ball moves through an open passage but never through walls', () {
    final Maze maze = Maze.generate(random: Random(7));
    final bool right = !maze.hasWall(0, 0, MazeDirection.right);
    final MazePhysics physics = MazePhysics(maze: maze);
    final Offset gravity = right ? const Offset(1, 0) : const Offset(0, 1);
    for (int i = 0; i < 100; i++) {
      physics.step(
        seconds: 0.05,
        gravity: gravity,
        gravityScale: 22,
        maxSpeed: 14,
      );
      expect(physics.canOccupy(physics.position), isTrue);
    }
    expect(right ? physics.position.dx : physics.position.dy, greaterThan(1));
  });

  test(
    'random high-speed inputs and stalled frames retain circle clearance',
    () {
      for (int seed = 0; seed < 20; seed++) {
        final Random random = Random(seed);
        final MazePhysics physics = MazePhysics(
          maze: Maze.generate(random: random),
        );
        for (int i = 0; i < 300; i++) {
          physics.step(
            seconds: i % 10 == 0 ? 1 : 1 / 60,
            gravity: Offset(
              random.nextDouble() * 2 - 1,
              random.nextDouble() * 2 - 1,
            ),
            gravityScale: 22,
            maxSpeed: 14,
          );
          expect(physics.canOccupy(physics.position), isTrue);
        }
      }
    },
  );
}
