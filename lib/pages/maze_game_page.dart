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

enum _SpeedLevel { normal, fast, turbo }

class _MazeGamePageState extends State<MazeGamePage>
    with SingleTickerProviderStateMixin {
  static const double _ballRadius = 0.18;
  static const double _normalGravityScale = 8.0;
  static const double _fastGravityScale = 14.0;
  static const double _turboGravityScale = 22.0;
  static const double _normalMaxSpeed = 5.5;
  static const double _fastMaxSpeed = 9.0;
  static const double _turboMaxSpeed = 14.0;
  static const double _frictionPerFrame = 0.94;

  Maze _maze = Maze.generate();
  Offset _ball = const Offset(0.5, 0.5);
  Offset _velocity = Offset.zero;
  Offset _gravity = Offset.zero;
  DateTime _startedAt = DateTime.now();
  Duration _elapsed = Duration.zero;
  String? _sensorError;
  bool _completed = false;
  bool _paused = false;
  _SpeedLevel _speedLevel = _SpeedLevel.fast;
  bool _manualControl = false;
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
    if (!mounted || _manualControl) {
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
    final double gravityScale = switch (_speedLevel) {
      _SpeedLevel.normal => _normalGravityScale,
      _SpeedLevel.fast => _fastGravityScale,
      _SpeedLevel.turbo => _turboGravityScale,
    };
    final double maxSpeed = switch (_speedLevel) {
      _SpeedLevel.normal => _normalMaxSpeed,
      _SpeedLevel.fast => _fastMaxSpeed,
      _SpeedLevel.turbo => _turboMaxSpeed,
    };
    final Offset acceleration = _gravity * gravityScale;
    Offset velocity = _velocity + acceleration * seconds;
    final double speed = velocity.distance;
    if (speed > maxSpeed) {
      velocity = velocity / speed * maxSpeed;
    }
    velocity *= math.pow(_frictionPerFrame, seconds * 60).toDouble();

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

  void _setManualDirection(Offset localPosition, Size boardSize) {
    if (!_manualControl || _paused || _completed) {
      return;
    }

    final Offset center = Offset(boardSize.width / 2, boardSize.height / 2);
    final Offset distance = localPosition - center;
    final Offset normalized = Offset(
      distance.dx / (boardSize.width / 2),
      distance.dy / (boardSize.height / 2),
    );
    setState(() {
      _gravity = normalized.distance > 1
          ? normalized / normalized.distance
          : normalized;
    });
  }

  void _stopManualDirection() {
    if (!_manualControl) {
      return;
    }
    setState(() {
      _gravity = Offset.zero;
      _velocity = Offset.zero;
    });
  }

  void _setControlMode(bool manual) {
    setState(() {
      _manualControl = manual;
      _gravity = Offset.zero;
      _velocity = Offset.zero;
    });
  }

  String _speedLabel(_SpeedLevel level) {
    return switch (level) {
      _SpeedLevel.normal => '普通',
      _SpeedLevel.fast => '高速',
      _SpeedLevel.turbo => '极速',
    };
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
            : _manualControl
                ? '拖动迷宫中的方向盘，让小球从左上角走到右下角'
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
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.speed, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          const Text('移动速度'),
                          const Spacer(),
                          Text(
                            _speedLabel(_speedLevel),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<_SpeedLevel>(
                        segments: const [
                          ButtonSegment(
                            value: _SpeedLevel.normal,
                            label: Text('普通'),
                          ),
                          ButtonSegment(
                            value: _SpeedLevel.fast,
                            label: Text('高速'),
                          ),
                          ButtonSegment(
                            value: _SpeedLevel.turbo,
                            label: Text('极速'),
                          ),
                        ],
                        selected: <_SpeedLevel>{_speedLevel},
                        onSelectionChanged: (Set<_SpeedLevel> selection) {
                          setState(() {
                            _speedLevel = selection.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.only(top: 10),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  secondary: Icon(
                    _manualControl ? Icons.touch_app : Icons.screen_rotation,
                    color: _manualControl
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('手动控制'),
                  subtitle: Text(
                    _manualControl ? '按住迷宫并拖动来控制方向' : '倾斜手机来控制小球',
                  ),
                  value: _manualControl,
                  onChanged: _setControlMode,
                ),
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
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final Size boardSize = constraints.biggest;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: _manualControl
                              ? (DragStartDetails details) =>
                                  _setManualDirection(details.localPosition, boardSize)
                              : null,
                          onPanUpdate: _manualControl
                              ? (DragUpdateDetails details) =>
                                  _setManualDirection(details.localPosition, boardSize)
                              : null,
                          onPanEnd: _manualControl
                              ? (_) => _stopManualDirection()
                              : null,
                          onPanCancel:
                              _manualControl ? _stopManualDirection : null,
                          child: CustomPaint(
                            painter: _MazePainter(
                              maze: _maze,
                              ball: _ball,
                              colorScheme: colorScheme,
                              manualControl: _manualControl,
                              manualDirection: _gravity,
                            ),
                          ),
                        );
                      },
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
                '${_manualControl ? '手动模式：按住迷宫并拖动控制方向' : '重力模式：倾斜手机控制方向'}  ·  入口左上  ·  出口右下',
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
    required this.manualControl,
    required this.manualDirection,
  });

  final Maze maze;
  final Offset ball;
  final ColorScheme colorScheme;
  final bool manualControl;
  final Offset manualDirection;

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

    if (manualControl) {
      final Offset center = Offset(size.width / 2, size.height / 2);
      final Paint joystickPaint = Paint()
        ..color = colorScheme.primary.withValues(alpha: 0.16)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, math.min(size.width, size.height) * 0.22, joystickPaint);
      final Paint directionPaint = Paint()
        ..color = colorScheme.primary.withValues(alpha: 0.45)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        center,
        center + Offset(
          manualDirection.dx * size.width * 0.18,
          manualDirection.dy * size.height * 0.18,
        ),
        directionPaint,
      );
    }

    final Paint ballPaint = Paint()..color = colorScheme.primary;
    canvas.drawCircle(
      Offset(ball.dx * cellWidth, ball.dy * cellHeight),
      math.min(cellWidth, cellHeight) * 0.18,
      ballPaint,
    );
  }

  @override
  bool shouldRepaint(_MazePainter oldDelegate) {
    return oldDelegate.maze != maze ||
        oldDelegate.ball != ball ||
        oldDelegate.manualControl != manualControl ||
        oldDelegate.manualDirection != manualDirection;
  }
}
