import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/motion_service.dart';

class LevelTestPage extends StatefulWidget {
  const LevelTestPage({
    super.key,
    this.accelerometerStream,
    this.gyroscopeStream,
    this.sensorTimeout = const Duration(seconds: 2),
  });

  final Stream<MotionSample>? accelerometerStream;
  final Stream<MotionSample>? gyroscopeStream;
  final Duration sensorTimeout;

  static const String routeName = '/level-test';

  @override
  State<LevelTestPage> createState() => _LevelTestPageState();
}

class _LevelTestPageState extends State<LevelTestPage> {
  static const double _levelThreshold = 1.5;

  MotionSample? _accelerometerEvent;
  MotionSample? _gyroscopeEvent;
  double _pitchOffset = 0;
  double _rollOffset = 0;
  String? _sensorError;
  String? _gyroscopeError;
  Timer? _sampleTimeout;
  DateTime _lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  StreamSubscription<MotionSample>? _accelerometerSubscription;
  StreamSubscription<MotionSample>? _gyroscopeSubscription;

  @override
  void initState() {
    super.initState();
    _armSampleTimeout();
    _accelerometerSubscription =
        (widget.accelerometerStream ?? accelerometerEventStream()).listen(
          _handleAccelerometer,
          onError: _handleSensorError,
          onDone: () => _handleSensorError(StateError('数据流已结束')),
        );
    _gyroscopeSubscription = (widget.gyroscopeStream ?? gyroscopeEventStream())
        .listen(
          _handleGyroscope,
          onError: _handleGyroscopeError,
          onDone: () => _handleGyroscopeError(StateError('数据流已结束')),
        );
  }

  @override
  void dispose() {
    _sampleTimeout?.cancel();
    unawaited(_accelerometerSubscription?.cancel());
    unawaited(_gyroscopeSubscription?.cancel());
    super.dispose();
  }

  void _handleAccelerometer(MotionSample event) {
    if (!mounted) return;
    final bool wasReady = _hasReading;
    _accelerometerEvent = event;
    _sensorError = null;
    _armSampleTimeout();
    if (!wasReady) {
      setState(() {});
    } else {
      _refreshUi();
    }
  }

  void _handleGyroscope(MotionSample event) {
    _gyroscopeEvent = event;
    _gyroscopeError = null;
    _refreshUi();
  }

  void _handleSensorError(Object error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _accelerometerEvent = null;
      _sensorError = '重力传感器不可用：$error';
    });
  }

  bool get _hasReading => _accelerometerEvent != null && _sensorError == null;

  void _armSampleTimeout() {
    _sampleTimeout?.cancel();
    _sampleTimeout = Timer(widget.sensorTimeout, () {
      _handleSensorError(StateError('等待数据超时，请检查传感器'));
    });
  }

  void _handleGyroscopeError(Object error) {
    if (!mounted) return;
    setState(() {
      _gyroscopeEvent = null;
      _gyroscopeError = '陀螺仪不可用：$error';
    });
  }

  void _refreshUi() {
    final DateTime now = DateTime.now();
    if (now.difference(_lastUiUpdate) < const Duration(milliseconds: 50)) {
      return;
    }

    _lastUiUpdate = now;
    if (mounted) {
      setState(() {});
    }
  }

  // Native motion values use the phone's axes: X is right/left and Y is
  // top/bottom. Keep those axes intact so the ball follows the phone instead
  // of swapping horizontal and vertical movement.
  double get _rawPitch {
    final MotionSample? event = _accelerometerEvent;
    if (event == null) {
      return 0;
    }

    return _toDegrees(
      math.atan2(event.y, math.sqrt(event.x * event.x + event.z * event.z)),
    );
  }

  double get _rawRoll {
    final MotionSample? event = _accelerometerEvent;
    if (event == null) {
      return 0;
    }

    return _toDegrees(
      math.atan2(event.x, math.sqrt(event.y * event.y + event.z * event.z)),
    );
  }

  double get _pitch => _rawPitch - _pitchOffset;
  double get _roll => _rawRoll - _rollOffset;

  bool get _isLevel {
    return _hasReading &&
        _pitch.abs() < _levelThreshold &&
        _roll.abs() < _levelThreshold;
  }

  void _calibrate() {
    if (_accelerometerEvent == null) {
      return;
    }

    setState(() {
      _pitchOffset = _rawPitch;
      _rollOffset = _rawRoll;
    });
  }

  void _resetCalibration() {
    setState(() {
      _pitchOffset = 0;
      _rollOffset = 0;
    });
  }

  double _toDegrees(double radians) => radians * 180 / math.pi;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final MotionSample? gyroscopeEvent = _gyroscopeEvent;

    return Scaffold(
      appBar: AppBar(title: const Text('水平测试')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 20,
            children: [
              if (_sensorError != null)
                Text(
                  _sensorError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _LevelBoard(
                      pitch: _pitch,
                      roll: _roll,
                      isLevel: _isLevel,
                      status: !_hasReading
                          ? (_sensorError == null ? '等待传感器数据' : '传感器不可用')
                          : (_isLevel ? '水平' : '未水平'),
                      colorScheme: colorScheme,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  _SensorValue(
                    label: '俯仰',
                    value: _hasReading ? _pitch : null,
                    unit: '°',
                  ),
                  const SizedBox(width: 20),
                  _SensorValue(
                    label: '横滚',
                    value: _hasReading ? _roll : null,
                    unit: '°',
                  ),
                ],
              ),
              Text(
                gyroscopeEvent == null
                    ? (_gyroscopeError ?? '陀螺仪：等待数据')
                    : '陀螺仪  X ${gyroscopeEvent.x.toStringAsFixed(3)}  '
                          'Y ${gyroscopeEvent.y.toStringAsFixed(3)}  '
                          'Z ${gyroscopeEvent.z.toStringAsFixed(3)} rad/s',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _hasReading ? _calibrate : null,
                      child: const Text('校准当前位置'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetCalibration,
                      child: const Text('恢复默认'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelBoard extends StatelessWidget {
  const _LevelBoard({
    required this.pitch,
    required this.roll,
    required this.isLevel,
    required this.status,
    required this.colorScheme,
  });

  final double pitch;
  final double roll;
  final bool isLevel;
  final String status;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double boardSize = constraints.maxWidth;
        final double maxTravel = boardSize * 0.36;
        final double offset = boardSize * 0.5 - 24;
        // X grows to the right on the phone. Y grows toward the phone's top,
        // while Flutter's screen coordinates grow downward, hence the minus.
        final double ballX = (roll / 30 * maxTravel).clamp(
          -maxTravel,
          maxTravel,
        );
        final double ballY = (-pitch / 30 * maxTravel).clamp(
          -maxTravel,
          maxTravel,
        );
        final Color ballColor = isLevel
            ? const Color(0xFF16A34A)
            : colorScheme.primary;

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: boardSize / 2 - 0.5,
                child: Container(height: 1, color: colorScheme.outlineVariant),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                left: boardSize / 2 - 0.5,
                child: Container(width: 1, color: colorScheme.outlineVariant),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 80),
                left: offset + ballX,
                top: offset + ballY,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ballColor,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Center(
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: ballColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SensorValue extends StatelessWidget {
  const _SensorValue({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final double? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value == null ? '--$unit' : '${value!.toStringAsFixed(1)}$unit',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
