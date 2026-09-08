import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_for_android_a_and_ios/models/maze.dart';

void main() {
  test('generated maze always connects the fixed entrance and exit', () {
    for (int seed = 0; seed < 20; seed++) {
      final Maze maze = Maze.generate(random: Random(seed));
      expect(maze.hasPathFromStartToExit(), isTrue);
      expect(maze.hasWall(0, 0, MazeDirection.left), isTrue);
      expect(
        maze.hasWall(maze.columns - 1, maze.rows - 1, MazeDirection.right),
        isTrue,
      );
    }
  });

  test('shared walls are symmetrical', () {
    final Maze maze = Maze.generate(random: Random(7));
    for (int row = 0; row < maze.rows; row++) {
      for (int column = 0; column < maze.columns; column++) {
        if (column + 1 < maze.columns) {
          expect(
            maze.hasWall(column, row, MazeDirection.right),
            maze.hasWall(column + 1, row, MazeDirection.left),
          );
        }
        if (row + 1 < maze.rows) {
          expect(
            maze.hasWall(column, row, MazeDirection.bottom),
            maze.hasWall(column, row + 1, MazeDirection.top),
          );
        }
      }
    }
  });
}
