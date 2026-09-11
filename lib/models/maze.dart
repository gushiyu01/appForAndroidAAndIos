import 'dart:math';

enum MazeDirection {
  top(1, 0, -1, 2),
  right(2, 1, 0, 3),
  bottom(4, 0, 1, 0),
  left(8, -1, 0, 1);

  const MazeDirection(this.bit, this.dx, this.dy, this.oppositeIndex);

  final int bit;
  final int dx;
  final int dy;
  final int oppositeIndex;

  MazeDirection get opposite => MazeDirection.values[oppositeIndex];
}

class Maze {
  Maze._({required this.columns, required this.rows, required List<int> walls})
    : _walls = walls;

  factory Maze.generate({int columns = 9, int rows = 13, Random? random}) {
    if (columns < 2 || rows < 2) {
      throw ArgumentError('A maze needs at least 2 columns and 2 rows.');
    }

    final List<int> walls = List<int>.filled(columns * rows, 15);
    final List<bool> visited = List<bool>.filled(columns * rows, false);
    final Random rng = random ?? Random();
    final List<Point<int>> stack = <Point<int>>[const Point<int>(0, 0)];
    visited[0] = true;

    while (stack.isNotEmpty) {
      final Point<int> current = stack.last;
      final List<(Point<int>, MazeDirection)> available =
          <(Point<int>, MazeDirection)>[];

      for (final MazeDirection direction in MazeDirection.values) {
        final Point<int> next = Point<int>(
          current.x + direction.dx,
          current.y + direction.dy,
        );
        if (next.x >= 0 &&
            next.x < columns &&
            next.y >= 0 &&
            next.y < rows &&
            !visited[next.y * columns + next.x]) {
          available.add((next, direction));
        }
      }

      if (available.isEmpty) {
        stack.removeLast();
        continue;
      }

      final (Point<int>, MazeDirection) choice =
          available[rng.nextInt(available.length)];
      final Point<int> next = choice.$1;
      final MazeDirection direction = choice.$2;
      final int currentIndex = current.y * columns + current.x;
      final int nextIndex = next.y * columns + next.x;
      walls[currentIndex] &= ~direction.bit;
      walls[nextIndex] &= ~direction.opposite.bit;
      visited[nextIndex] = true;
      stack.add(next);
    }

    return Maze._(columns: columns, rows: rows, walls: walls);
  }

  final int columns;
  final int rows;
  final List<int> _walls;

  bool hasWall(int column, int row, MazeDirection direction) {
    if (column < 0 || column >= columns || row < 0 || row >= rows) {
      return true;
    }
    return (_walls[row * columns + column] & direction.bit) != 0;
  }

  bool hasPathFromStartToExit() {
    final Set<int> visited = <int>{0};
    final List<int> queue = <int>[0];

    while (queue.isNotEmpty) {
      final int index = queue.removeAt(0);
      if (index == _walls.length - 1) {
        return true;
      }
      final int column = index % columns;
      final int row = index ~/ columns;
      for (final MazeDirection direction in MazeDirection.values) {
        if (hasWall(column, row, direction)) {
          continue;
        }
        final int nextColumn = column + direction.dx;
        final int nextRow = row + direction.dy;
        final int nextIndex = nextRow * columns + nextColumn;
        if (visited.add(nextIndex)) {
          queue.add(nextIndex);
        }
      }
    }
    return false;
  }
}
