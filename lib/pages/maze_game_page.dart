import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/maze.dart';
import '../services/motion_service.dart';

class MazeGamePage extends StatefulWidget {
  const MazeGamePage({super.key});

  static const String routeName = '/maze-game';

  @override
  State<MazeGamePage> createState() => _MazeGamePageState();
}

class _MazeGamePageState extends State<MazeGamePage>
    with SingleTickerProviderStateMixin {
  static const double _ballRadius = 0.18;
  static const double _gravityScale = 6.5;
  static const double _maxSpeed = 4.2;

  Maze _maze = Maze.generate();
  Offset _ball = const Offset(0.5, 0.5);
  Offset _velocity = Offset.zero;
  Offset _gravity = Offset.zero;
  DateTime _startedAt = DateTime.now();
  Duration _elapsed = Duration.zero;
  String? _sensorError;
  bool _completed = false;
  bool _paused = false;
  Duration _lastTick = Duration.zero;

  late final Ticker _ticker;
  StreamSubscription<MotionSample>? _accelerometerSubscription;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _startedAt = DateTime.now();
    _accelerometerSubscription = accelerometerEventStream().listen(
      _handleAccelerometer,
      onError: _handleSensorError,
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_accelerometerSubscription?.cancel());
    super.dispose();
  }

  void _handleAccelerometer(MotionSample event) {
    if (!mounted) {
      return;
    }

    // The phone's X axis maps to the board's horizontal axis. Flutter's Y
    // coordinate grows downward, so invert the phone's Y axis for the board.
    final Offset target = Offset(
      event.x / 9.80665,
      -event.y / 9.80665,
    );
    setState(() {
      _gravity = Offset(
        _gravity.dx * 0.8 + target.dx * 0.2,
        _gravity.dy * 0.8 + target.dy * 0.2,
      );
      _sensorError = null;
    });
  }

  void _handleSensorError(Object error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _sensorError = '传感器不可用，小球暂时无法移动：$error';
    });
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final double seconds =
        ((elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond)
            .clamp(0.0, 0.05).toDouble();
    _lastTick = elapsed;

    if (_paused || _completed || seconds <= 0) {
      return;
    }

    _moveBall(seconds);
    if (mounted) {
      setState(() {
        _elapsed = DateTime.now().difference(_startedAt);
      });
    }
  }

  void _moveBall(double seconds) {
    final Offset acceleration = _gravity * _gravityScale;
    Offset velocity = _velocity + acceleration * seconds;
    final double speed = velocity.distance;
    if (speed > _maxSpeed) {
      velocity = velocity / speed * _maxSpeed;
    }
    velocity *= math.pow(0.82, seconds * 60).toDouble();

    double x = _ball.dx + velocity.dx * seconds;
    double y = _ball.dy + velocity.dy * seconds;
    final int column = _ball.dx.floor().clamp(0, _maze.columns - 1).toInt();
    final int row = _ball.dy.floor().clamp(0, _maze.rows - 1).toInt();

    if (velocity.dx > 0 &&
        _maze.hasWall(column, row, MazeDirection.right) &&
        x + _ballRadius > column + 1) {
      x = column + 1 - _ballRadius;
      velocity = Offset(0, velocity.dy);
    } else if (velocity.dx < 0 &&
        _maze.hasWall(column, row, MazeDirection.left) &&
        x - _ballRadius < column) {
      x = column + _ballRadius;
      velocity = Offset(0, velocity.dy);
    }

    if (velocity.dy > 0 &&
        _maze.hasWall(column, row, MazeDirection.bottom) &&
        y + _ballRadius > row + 1) {
      y = row + 1 - _ballRadius;
      velocity = Offset(velocity.dx, 0);
    } else if (velocity.dy < 0 &&
        _maze.hasWall(column, row, MazeDirection.top) &&
        y - _ballRadius < row) {
      y = row + _ballRadius;
      velocity = Offset(velocity.dx, 0);
    }

    _ball = Offset(
      x.clamp(_ballRadius, _maze.columns - _ballRadius).toDouble(),
      y.clamp(_ballRadius, _maze.rows - _ballRadius).toDouble(),
    );
    _velocity = velocity;

    if (_ball.dx >= _maze.columns - 0.5 &&
        _ball.dy >= _maze.rows - 0.5) {
      _completed = true;
      _elapsed = DateTime.now().difference(_startedAt);
    }
  }

  void _restart() {
    setState(() {
      _maze = Maze.generate();
      _ball = const Offset(0.5, 0.5);
      _velocity = Offset.zero;
      _gravity = Offset.zero;
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
      _completed = false;
      _paused = false;
      _lastTick = Duration.zero;
    });
  }

  void _togglePause() {
    if (_completed) {
      return;
    }
    setState(() {
      _paused = !_paused;
    });
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String status = _completed
        ? '抵达出口！用时 ${_formatDuration(_elapsed)}'
        : _paused
            ? '游戏已暂停'
            : '倾斜手机，让小球从左上角走到右下角';

    return Scaffold(
      appBar: AppBar(
        title: const Text('重力迷宫'),
        actions: [
          IconButton(
            onPressed: _restart,
            tooltip: '换一张迷宫',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(_elapsed),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFeatures: const [ui.FontFeature.tabularFigures()],
                        ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _completed ? _restart : _togglePause,
                    icon: Icon(_completed
                        ? Icons.replay
                        : _paused
                            ? Icons.play_arrow
                            : Icons.pause),
                    label: Text(_completed ? '再来一局' : _paused ? '继续' : '暂停'),
                  ),
                ],
              ),
              if (_sensorError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _sensorError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _maze.columns / _maze.rows,
                    child: CustomPaint(
                      painter: _MazePainter(
                        maze: _maze,
                        ball: _ball,
                        colorScheme: colorScheme,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _completed
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '入口：左上角  ·  出口：右下角  ·  每次重新开始都会生成随机路线',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MazePainter extends CustomPainter {
  const _MazePainter({
    required this.maze,
    required this.ball,
    required this.colorScheme,
  });

  final Maze maze;
  final Offset ball;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final double cellWidth = size.width / maze.columns;
    final double cellHeight = size.height / maze.rows;
    final Paint background = Paint()..color = colorScheme.surfaceContainerLowest;
    canvas.drawRect(Offset.zero & size, background);

    final Paint startPaint = Paint()..color = colorScheme.primaryContainer;
    final Paint exitPaint = Paint()..color = colorScheme.tertiaryContainer;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cellWidth, cellHeight),
      startPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        (maze.columns - 1) * cellWidth,
        (maze.rows - 1) * cellHeight,
        cellWidth,
        cellHeight,
      ),
      exitPaint,
    );

    final Paint wallPaint = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int row = 0; row < maze.rows; row++) {
      for (int column = 0; column < maze.columns; column++) {
        final double left = column * cellWidth;
        final double top = row * cellHeight;
        if (maze.hasWall(column, row, MazeDirection.top)) {
          canvas.drawLine(Offset(left, top), Offset(left + cellWidth, top), wallPaint);
        }
        if (maze.hasWall(column, row, MazeDirection.left)) {
          canvas.drawLine(Offset(left, top), Offset(left, top + cellHeight), wallPaint);
        }
        if (maze.hasWall(column, row, MazeDirection.right)) {
          canvas.drawLine(
            Offset(left + cellWidth, top),
            Offset(left + cellWidth, top + cellHeight),
            wallPaint,
          );
        }
        if (maze.hasWall(column, row, MazeDirection.bottom)) {
          canvas.drawLine(
            Offset(left, top + cellHeight),
            Offset(left + cellWidth, top + cellHeight),
            wallPaint,
          );
        }
      }
    }

    final TextPainter labels = TextPainter(textDirection: TextDirection.ltr);
    labels.text = TextSpan(
      text: '入',
      style: TextStyle(
        color: colorScheme.onPrimaryContainer,
        fontSize: cellHeight * 0.28,
        fontWeight: FontWeight.w700,
      ),
    );
    labels.layout();
    labels.paint(canvas, Offset(cellWidth * 0.5 - labels.width / 2, cellHeight * 0.36));
    labels.text = TextSpan(
      text: '出',
      style: TextStyle(
        color: colorScheme.onTertiaryContainer,
        fontSize: cellHeight * 0.28,
        fontWeight: FontWeight.w700,
      ),
    );
    labels.layout();
    labels.paint(
      canvas,
      Offset(
        (maze.columns - 0.5) * cellWidth - labels.width / 2,
        (maze.rows - 0.64) * cellHeight,
      ),
    );

    final Paint ballPaint = Paint()..color = colorScheme.primary;
    canvas.drawCircle(
      Offset(ball.dx * cellWidth, ball.dy * cellHeight),
      math.min(cellWidth, cellHeight) * 0.18,
      ballPaint,
    );
  }

  @override
  bool shouldRepaint(_MazePainter oldDelegate) {
    return oldDelegate.maze != maze || oldDelegate.ball != ball;
  }
}
