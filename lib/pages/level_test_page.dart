import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class LevelTestPage extends StatefulWidget {
  const LevelTestPage({super.key});

  static const String routeName = '/level-test';

  @override
  State<LevelTestPage> createState() => _LevelTestPageState();
}

class _LevelTestPageState extends State<LevelTestPage> {
  static const double _levelThreshold = 1.5;

  AccelerometerEvent? _accelerometerEvent;
  GyroscopeEvent? _gyroscopeEvent;
  double _pitchOffset = 0;
  double _rollOffset = 0;
  String? _sensorError;
  DateTime _lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  @override
  void initState() {
    super.initState();
    _accelerometerSubscription = accelerometerEventStream().listen(
      _handleAccelerometer,
      onError: _handleSensorError,
    );
    _gyroscopeSubscription = gyroscopeEventStream().listen(
      _handleGyroscope,
      onError: _handleSensorError,
    );
  }

  @override
  void dispose() {
    unawaited(_accelerometerSubscription?.cancel());
    unawaited(_gyroscopeSubscription?.cancel());
    super.dispose();
  }

  void _handleAccelerometer(AccelerometerEvent event) {
    _accelerometerEvent = event;
    _refreshUi();
  }

  void _handleGyroscope(GyroscopeEvent event) {
    _gyroscopeEvent = event;
    _refreshUi();
  }

  void _handleSensorError(Object error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _sensorError = '传感器不可用：$error';
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

  double get _rawPitch {
    final AccelerometerEvent? event = _accelerometerEvent;
    if (event == null) {
      return 0;
    }

    return _toDegrees(
      math.atan2(
        event.x,
        math.sqrt(event.y * event.y + event.z * event.z),
      ),
    );
  }

  double get _rawRoll {
    final AccelerometerEvent? event = _accelerometerEvent;
    if (event == null) {
      return 0;
    }

    return _toDegrees(
      math.atan2(
        event.y,
        math.sqrt(event.x * event.x + event.z * event.z),
      ),
    );
  }

  double get _pitch => _rawPitch - _pitchOffset;
  double get _roll => _rawRoll - _rollOffset;

  bool get _isLevel {
    return _pitch.abs() < _levelThreshold && _roll.abs() < _levelThreshold;
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
    final GyroscopeEvent? gyroscopeEvent = _gyroscopeEvent;

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
                      colorScheme: colorScheme,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  _SensorValue(label: '俯仰', value: _pitch, unit: '°'),
                  const SizedBox(width: 20),
                  _SensorValue(label: '横滚', value: _roll, unit: '°'),
                ],
              ),
              Text(
                gyroscopeEvent == null
                    ? '陀螺仪：等待数据'
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
                      onPressed: _calibrate,
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
    required this.colorScheme,
  });

  final double pitch;
  final double roll;
  final bool isLevel;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double boardSize = constraints.maxWidth;
        final double maxTravel = boardSize * 0.36;
        final double offset = boardSize * 0.5 - 24;
        final double ballX =
            (roll / 30 * maxTravel).clamp(-maxTravel, maxTravel);
        final double ballY =
            (pitch / 30 * maxTravel).clamp(-maxTravel, maxTravel);
        final Color ballColor =
            isLevel ? const Color(0xFF16A34A) : colorScheme.primary;

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
                    isLevel ? '水平' : '未水平',
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
  final double value;
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
            '${value.toStringAsFixed(1)}$unit',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
