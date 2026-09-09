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
  bool _gameStarted = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_showSettingsDialog(initial: true));
      }
    });
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

    if (!_gameStarted || _paused || _completed || seconds <= 0) {
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

  Future<void> _showSettingsDialog({required bool initial}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !initial,
      builder: (BuildContext dialogContext) {
        return _SettingsDialog(
          initial: initial,
          speedLevel: _speedLevel,
          manualControl: _manualControl,
          onApply: (_SpeedLevel speedLevel, bool manualControl) {
            setState(() {
              _speedLevel = speedLevel;
              _manualControl = manualControl;
              _gravity = Offset.zero;
              _velocity = Offset.zero;
              _sensorError = null;
              if (initial) {
                _gameStarted = true;
                _startedAt = DateTime.now();
                _elapsed = Duration.zero;
              }
            });
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String status = _completed
        ? '抵达出口！用时 ${_formatDuration(_elapsed)}'
        : _paused
            ? '游戏已暂停'
            : _manualControl
                ? '拖动迷宫中的方向盘，让小球从左上角走到右下角'
                : '倾斜手机，让小球从左上角走到右下角';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FC),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFF8F8FC), Color(0xFFF4F0FB), Color(0xFFEFF8FC)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _MazeBackdrop()),
            SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double horizontal = constraints.maxWidth >= 600 ? 42 : 18;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 22),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Header(
                              onBack: () => Navigator.of(context).maybePop(),
                              onRestart: _restart,
                              onSettings: () => unawaited(
                                _showSettingsDialog(initial: false),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _BoardCard(
                              maze: _maze,
                              ball: _ball,
                              manualControl: _manualControl,
                              manualDirection: _gravity,
                              onPanStart: (DragStartDetails details, Size size) => _setManualDirection(details.localPosition, size),
                              onPanUpdate: (DragUpdateDetails details, Size size) => _setManualDirection(details.localPosition, size),
                              onPanEnd: (_) => _stopManualDirection(),
                              onPanCancel: _stopManualDirection,
                            ),
                            const SizedBox(height: 18),
                            _TimerCard(
                              elapsed: _elapsed,
                              paused: _paused,
                              completed: _completed,
                              onTogglePause: _completed ? _restart : _togglePause,
                            ),
                            const SizedBox(height: 18),
                            if (_sensorError != null) ...[
                              const SizedBox(height: 10),
                              Text(_sensorError!, textAlign: TextAlign.center, style: textTheme.bodySmall?.copyWith(color: const Color(0xFFB33A53), fontWeight: FontWeight.w600)),
                            ],
                            const SizedBox(height: 22),
                            Text(status, textAlign: TextAlign.center, style: textTheme.bodySmall?.copyWith(color: _completed ? const Color(0xFF51419A) : const Color(0xFF777486), fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.onRestart,
    required this.onSettings,
  });

  final VoidCallback onBack;
  final VoidCallback onRestart;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundActionButton(
          icon: Icons.arrow_back_rounded,
          tooltip: '返回',
          onPressed: onBack,
        ),
        const SizedBox(width: 18),
        const Expanded(
          child: Text(
            '重力迷宫',
            style: TextStyle(
              color: Color(0xFF17151D),
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
        ),
        _RoundActionButton(
          icon: Icons.refresh_rounded,
          tooltip: '换一张迷宫',
          onPressed: onRestart,
        ),
        const SizedBox(width: 10),
        _RoundActionButton(
          icon: Icons.settings_rounded,
          tooltip: '设置',
          onPressed: onSettings,
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.64),
        shape: const CircleBorder(),
        elevation: 5,
        shadowColor: const Color(0x40201A3D),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 62, height: 62, child: Icon(icon, color: const Color(0xFF302D3C), size: 34)),
        ),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.maze, required this.ball, required this.manualControl, required this.manualDirection, required this.onPanStart, required this.onPanUpdate, required this.onPanEnd, required this.onPanCancel});
  final Maze maze;
  final Offset ball;
  final bool manualControl;
  final Offset manualDirection;
  final void Function(DragStartDetails, Size) onPanStart;
  final void Function(DragUpdateDetails, Size) onPanUpdate;
  final void Function(DragEndDetails) onPanEnd;
  final VoidCallback onPanCancel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = math.min(constraints.maxWidth, 520);
        final Size boardSize = Size(width, width * 1.42);
        return Center(
          child: SizedBox(
            width: boardSize.width,
            height: boardSize.height,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints boardConstraints) {
                final Size size = boardConstraints.biggest;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: manualControl ? (details) => onPanStart(details, size) : null,
                  onPanUpdate: manualControl ? (details) => onPanUpdate(details, size) : null,
                  onPanEnd: manualControl ? onPanEnd : null,
                  onPanCancel: manualControl ? onPanCancel : null,
                  child: CustomPaint(painter: _MazePainter(maze: maze, ball: ball, manualControl: manualControl, manualDirection: manualDirection)),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.elapsed, required this.paused, required this.completed, required this.onTogglePause});
  final Duration elapsed;
  final bool paused;
  final bool completed;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.alarm_rounded, color: Color(0xFF6150A9), size: 38),
          const SizedBox(width: 10),
          Text(_formatDuration(elapsed), style: const TextStyle(color: Color(0xFF282532), fontSize: 38, fontWeight: FontWeight.w800, fontFeatures: [ui.FontFeature.tabularFigures()], letterSpacing: 2)),
          const Spacer(),
          _PauseButton(paused: paused, completed: completed, onPressed: onTogglePause),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.paused, required this.completed, required this.onPressed});
  final bool paused;
  final bool completed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final String label = completed ? '再来一局' : paused ? '继续' : '暂停';
    final IconData icon = completed ? Icons.replay_rounded : paused ? Icons.play_arrow_rounded : Icons.pause_rounded;
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onPressed,
      child: Row(
        children: [
          Container(width: 56, height: 56, decoration: const BoxDecoration(color: Color(0xFFF7F5FD), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x301F1A37), blurRadius: 8, offset: Offset(1, 3)), BoxShadow(color: Colors.white, blurRadius: 2, offset: Offset(-1, -1))]), child: Icon(icon, color: const Color(0xFF685B86), size: 28)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Color(0xFF282532), fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog({
    required this.initial,
    required this.speedLevel,
    required this.manualControl,
    required this.onApply,
  });

  final bool initial;
  final _SpeedLevel speedLevel;
  final bool manualControl;
  final void Function(_SpeedLevel, bool) onApply;

  @override
  Widget build(BuildContext context) {
    _SpeedLevel selectedSpeed = speedLevel;
    bool selectedManual = manualControl;

    return PopScope(
      canPop: !initial,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return _GlassCard(
              padding: const EdgeInsets.fromLTRB(22, 24, 18, 18),
              fillColor: const Color(0xF2E9E8EE),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        color: Color(0xFF514485),
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          initial ? '开始前设置' : '移动 / 控制设置',
                          style: const TextStyle(
                            color: Color(0xFF272330),
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!initial)
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: '关闭',
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    initial
                        ? '选择移动速度和控制方式，点击开始进入迷宫'
                        : '调整后点击应用，设置会立即生效',
                    style: const TextStyle(
                      color: Color(0xFF696473),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    selectedManual
                        ? '触控屏幕，让小球从左上角走到右下角'
                        : '倾斜手机，让小球从左上角走到右下角',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF211E2B),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _InstructionPill(
                    text: selectedManual
                        ? '手动模式 · 拖动控制方向 · 入口左上 · 出口右下'
                        : '重力模式 · 倾斜手机控制方向 · 入口左上 · 出口右下',
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '移动速度',
                    style: TextStyle(
                      color: Color(0xFF40394F),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SpeedSelector(
                    selected: selectedSpeed,
                    onChanged: (value) => setDialogState(() {
                      selectedSpeed = value;
                    }),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.46),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedManual
                              ? Icons.touch_app_rounded
                              : Icons.screen_rotation_alt_rounded,
                          color: const Color(0xFF5F5A67),
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '手动控制',
                                style: TextStyle(
                                  color: Color(0xFF292530),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '关闭时使用重力感应，开启后触控拖动控制',
                                style: TextStyle(
                                  color: Color(0xFF696473),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: selectedManual,
                          onChanged: (value) => setDialogState(() {
                            selectedManual = value;
                          }),
                          activeThumbColor: Colors.white,
                          activeTrackColor: const Color(0xFF575171),
                          inactiveThumbColor: const Color(0xFFF8F8FC),
                          inactiveTrackColor: const Color(0xFF9999A1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!initial)
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => onApply(selectedSpeed, selectedManual),
                        icon: Icon(
                          initial
                              ? Icons.play_arrow_rounded
                              : Icons.check_rounded,
                        ),
                        label: Text(initial ? '开始游戏' : '应用设置'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF514485),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.selected, required this.onChanged});
  final _SpeedLevel selected;
  final ValueChanged<_SpeedLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<(String, _SpeedLevel)> items = <(String, _SpeedLevel)>[('普通', _SpeedLevel.normal), ('高速', _SpeedLevel.fast), ('极速', _SpeedLevel.turbo)];
    return Container(
      height: 58,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFB7B7BF), borderRadius: BorderRadius.circular(32), boxShadow: const [BoxShadow(color: Color(0x33231D35), blurRadius: 7, offset: Offset(0, 3)), BoxShadow(color: Color(0x65FFFFFF), blurRadius: 4, offset: Offset(0, -1))]),
      child: Row(
        children: [
          for (final (String label, _SpeedLevel value) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: selected == value ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFF837AB2), Color(0xFF302A5B)]) : null, boxShadow: selected == value ? const [BoxShadow(color: Color(0x805E4DB0), blurRadius: 12, spreadRadius: 1), BoxShadow(color: Color(0xAAFFFFFF), blurRadius: 2, offset: Offset(0, -1))] : null),
                  alignment: Alignment.center,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [if (selected == value) ...[const Icon(Icons.check_rounded, color: Colors.white, size: 22), const SizedBox(width: 4)], Text(label, style: TextStyle(color: selected == value ? Colors.white : const Color(0xFF3F3B4A), fontSize: 17, fontWeight: FontWeight.w800))]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InstructionPill extends StatelessWidget {
  const _InstructionPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xB8D9C9F4), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withValues(alpha: 0.78)), boxShadow: const [BoxShadow(color: Color(0x221F1A3B), blurRadius: 8, offset: Offset(0, 2)), BoxShadow(color: Color(0x80FFFFFF), blurRadius: 3, offset: Offset(0, -1))]),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF373148), fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding = EdgeInsets.zero, this.fillColor = const Color(0xBFFFFFFF)});
  final Widget child;
  final EdgeInsets padding;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.82)), boxShadow: const [BoxShadow(color: Color(0x241D1935), blurRadius: 16, offset: Offset(0, 7)), BoxShadow(color: Color(0xA8FFFFFF), blurRadius: 4, offset: Offset(0, -2))]),
      child: child,
    );
  }
}

class _MazeBackdrop extends StatelessWidget {
  const _MazeBackdrop();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _BackdropPainter());
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()..color = const Color(0x265C55A4)..style = PaintingStyle.stroke..strokeWidth = 1;
    final List<Offset> points = <Offset>[Offset(size.width * 0.02, size.height * 0.48), Offset(size.width * 0.22, size.height * 0.55), Offset(size.width * 0.08, size.height * 0.66), Offset(size.width * 0.32, size.height * 0.74), Offset(size.width * 0.86, size.height * 0.58), Offset(size.width * 1.04, size.height * 0.78), Offset(size.width * 0.81, size.height * 0.93)];
    for (int index = 0; index < points.length - 1; index++) {
      canvas.drawLine(points[index], points[index + 1], linePaint);
    }
    canvas.drawLine(Offset(size.width * 0.88, size.height * 0.02), Offset(size.width * 0.72, size.height * 0.18), linePaint);
    canvas.drawLine(Offset(size.width * 0.72, size.height * 0.18), Offset(size.width * 1.04, size.height * 0.28), linePaint);
    canvas.drawCircle(Offset(size.width * 0.84, size.height * 0.2), 110, Paint()..color = const Color(0x145B47B7));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MazePainter extends CustomPainter {
  const _MazePainter({required this.maze, required this.ball, required this.manualControl, required this.manualDirection});
  final Maze maze;
  final Offset ball;
  final bool manualControl;
  final Offset manualDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect outer = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18));
    canvas.save();
    canvas.clipRRect(outer);
    final Paint boardBackground = Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFFFDFCF9), Color(0xFFEDEBEA)]).createShader(Offset.zero & size);
    canvas.drawRRect(outer, boardBackground);
    final RRect inner = RRect.fromRectAndRadius(Rect.fromLTRB(11, 11, size.width - 11, size.height - 11), const Radius.circular(10));
    final Paint wood = Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFFB98455), Color(0xFFE2B27C), Color(0xFF8B5B3A)], stops: <double>[0, 0.45, 1]).createShader(inner.outerRect);
    canvas.drawRRect(inner, wood);
    final RRect playfield = RRect.fromRectAndRadius(Rect.fromLTRB(24, 24, size.width - 24, size.height - 24), const Radius.circular(5));
    final Paint field = Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFFF8F7F5), Color(0xFFE9E7E6)]).createShader(playfield.outerRect);
    canvas.drawRRect(playfield, field);
    canvas.restore();

    final double cellWidth = playfield.outerRect.width / maze.columns;
    final double cellHeight = playfield.outerRect.height / maze.rows;
    final Offset origin = playfield.outerRect.topLeft;
    final Rect startRect = Rect.fromLTWH(origin.dx, origin.dy, cellWidth, cellHeight);
    final Rect exitRect = Rect.fromLTWH(origin.dx + (maze.columns - 1) * cellWidth, origin.dy + (maze.rows - 1) * cellHeight, cellWidth, cellHeight);
    _drawGlow(canvas, startRect.center, const Color(0xFF73BFFF));
    _drawGlow(canvas, exitRect.center, const Color(0xFFE16FEA));

    final double stroke = math.max(6, math.min(cellWidth, cellHeight) * 0.11);
    final Paint wall = Paint()..color = const Color(0xFF6686C5)..strokeWidth = stroke..strokeCap = StrokeCap.square..style = PaintingStyle.stroke;
    for (int row = 0; row < maze.rows; row++) {
      for (int column = 0; column < maze.columns; column++) {
        final double left = origin.dx + column * cellWidth;
        final double top = origin.dy + row * cellHeight;
        if (maze.hasWall(column, row, MazeDirection.top)) _drawWall(canvas, Offset(left, top), Offset(left + cellWidth, top), wall);
        if (maze.hasWall(column, row, MazeDirection.left)) _drawWall(canvas, Offset(left, top), Offset(left, top + cellHeight), wall);
        if (maze.hasWall(column, row, MazeDirection.right)) _drawWall(canvas, Offset(left + cellWidth, top), Offset(left + cellWidth, top + cellHeight), wall);
        if (maze.hasWall(column, row, MazeDirection.bottom)) _drawWall(canvas, Offset(left, top + cellHeight), Offset(left + cellWidth, top + cellHeight), wall);
      }
    }
    _drawMarker(canvas, startRect.center, '入', const Color(0xFF3559A8));
    _drawMarker(canvas, exitRect.center, '出', const Color(0xFF8B378D));

    if (manualControl) {
      final Offset center = Offset(size.width / 2, size.height / 2);
      final double radius = math.min(size.width, size.height) * 0.19;
      canvas.drawCircle(center, radius, Paint()..color = const Color(0x265D50A1));
      final Paint directionPaint = Paint()..color = const Color(0x995E4CA5)..strokeWidth = 3..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
      canvas.drawLine(center, center + Offset(manualDirection.dx * radius, manualDirection.dy * radius), directionPaint);
    }
    final Offset ballCenter = Offset(origin.dx + ball.dx * cellWidth, origin.dy + ball.dy * cellHeight);
    _drawBall(canvas, ballCenter, math.min(cellWidth, cellHeight) * 0.18);
  }

  void _drawWall(Canvas canvas, Offset start, Offset end, Paint wall) {
    canvas.drawLine(start, end, wall);
  }

  void _drawGlow(Canvas canvas, Offset center, Color color) {
    final Paint glow = Paint()..shader = RadialGradient(colors: <Color>[color.withValues(alpha: 0.72), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: center, radius: 32));
    canvas.drawCircle(center, 32, glow);
  }

  void _drawMarker(Canvas canvas, Offset center, String label, Color color) {
    canvas.drawCircle(center, 17, Paint()..color = color.withValues(alpha: 0.15));
    final Paint outline = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(center, 15, outline);
    final TextPainter painter = TextPainter(text: TextSpan(text: label, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800)), textDirection: TextDirection.ltr)..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  void _drawBall(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center + const Offset(2, 4), radius * 1.06, Paint()..color = const Color(0x55201928));
    final Paint ball = Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.5), radius: 0.95, colors: <Color>[Color(0xFFE6F2FF), Color(0xFF5E77A2), Color(0xFF12192C)], stops: <double>[0, 0.28, 1]).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, ball);
    canvas.drawCircle(center + Offset(-radius * 0.3, -radius * 0.35), radius * 0.17, Paint()..color = const Color(0xCCFFFFFF));
  }

  @override
  bool shouldRepaint(_MazePainter oldDelegate) => oldDelegate.maze != maze || oldDelegate.ball != ball || oldDelegate.manualControl != manualControl || oldDelegate.manualDirection != manualDirection;
}
