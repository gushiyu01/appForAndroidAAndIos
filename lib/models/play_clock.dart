/// Monotonic active-play time. Paused/background/dialog time is excluded.
class PlayClock {
  PlayClock({Duration Function()? now}) {
    _now = now ?? (() => _source.elapsed);
  }

  final Stopwatch _source = Stopwatch()..start();
  late final Duration Function() _now;
  Duration _saved = Duration.zero;
  Duration? _runningSince;

  bool get isRunning => _runningSince != null;
  Duration get elapsed =>
      _saved +
      (_runningSince == null ? Duration.zero : _now() - _runningSince!);

  void resume() {
    _runningSince ??= _now();
  }

  void pause() {
    _saved = elapsed;
    _runningSince = null;
  }

  void reset() {
    _saved = Duration.zero;
    _runningSince = null;
  }
}
