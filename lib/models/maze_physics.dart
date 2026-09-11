import 'dart:math' as math;
import 'dart:ui';

import 'maze.dart';

/// Deterministic circle/maze simulation, independent of widgets and sensors.
class MazePhysics {
  MazePhysics({
    required this.maze,
    this.position = const Offset(0.5, 0.5),
    this.velocity = Offset.zero,
  });

  static const double ballRadius = 0.18;
  final Maze maze;
  Offset position;
  Offset velocity;

  bool get completed =>
      position.dx >= maze.columns - 0.5 && position.dy >= maze.rows - 0.5;

  void step({
    required double seconds,
    required Offset gravity,
    required double gravityScale,
    required double maxSpeed,
  }) {
    if (seconds <= 0 || !seconds.isFinite) return;
    // Bound both integration time and travel per substep, even after a stall.
    final double duration = seconds.clamp(0.0, 0.05);
    final int steps = math.max(
      1,
      (maxSpeed * duration / (ballRadius / 4)).ceil(),
    );
    final double dt = duration / steps;
    for (int i = 0; i < steps; i++) {
      velocity += gravity * gravityScale * dt;
      if (velocity.distance > maxSpeed) {
        velocity = velocity / velocity.distance * maxSpeed;
      }
      velocity *= math.pow(0.94, dt * 60).toDouble();
      final Offset nextX = position + Offset(velocity.dx * dt, 0);
      if (canOccupy(nextX)) {
        position = nextX;
      } else {
        velocity = Offset(0, velocity.dy);
      }
      final Offset nextY = position + Offset(0, velocity.dy * dt);
      if (canOccupy(nextY)) {
        position = nextY;
      } else {
        velocity = Offset(velocity.dx, 0);
      }
    }
  }

  /// Tests the circle against every nearby wall segment, including endpoints.
  bool canOccupy(Offset point) {
    if (!point.dx.isFinite ||
        !point.dy.isFinite ||
        point.dx < ballRadius ||
        point.dy < ballRadius ||
        point.dx > maze.columns - ballRadius ||
        point.dy > maze.rows - ballRadius) {
      return false;
    }
    final int left = math.max(0, (point.dx - ballRadius).floor());
    final int right = math.min(
      maze.columns - 1,
      (point.dx + ballRadius).floor(),
    );
    final int top = math.max(0, (point.dy - ballRadius).floor());
    final int bottom = math.min(maze.rows - 1, (point.dy + ballRadius).floor());
    for (int row = top; row <= bottom; row++) {
      for (int col = left; col <= right; col++) {
        for (final MazeDirection direction in MazeDirection.values) {
          if (!maze.hasWall(col, row, direction)) continue;
          final double x = col.toDouble();
          final double y = row.toDouble();
          final (Offset, Offset) segment = switch (direction) {
            MazeDirection.top => (Offset(x, y), Offset(x + 1, y)),
            MazeDirection.right => (Offset(x + 1, y), Offset(x + 1, y + 1)),
            MazeDirection.bottom => (Offset(x, y + 1), Offset(x + 1, y + 1)),
            MazeDirection.left => (Offset(x, y), Offset(x, y + 1)),
          };
          final Offset nearest = Offset(
            point.dx.clamp(segment.$1.dx, segment.$2.dx),
            point.dy.clamp(segment.$1.dy, segment.$2.dy),
          );
          if ((point - nearest).distanceSquared <
              ballRadius * ballRadius - 1e-10) {
            return false;
          }
        }
      }
    }
    return true;
  }
}
