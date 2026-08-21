import 'package:flutter/foundation.dart';

class StartupBenchmark {
  static final Map<String, int> _marks = {};
  static final List<String> _order = [];
  static final Stopwatch _clock = Stopwatch()..start();

  static void mark(String label) {
    _marks[label] = _clock.elapsedMilliseconds;
    _order.add(label);
    if (kDebugMode) {
      debugPrint('[STARTUP] $label: ${_clock.elapsedMilliseconds}ms');
    }
  }

  static String report() {
    final buffer = StringBuffer('STARTUP BENCHMARK\n');
    for (final label in _order) {
      buffer.writeln('$label: ${_marks[label]}ms');
    }
    return buffer.toString();
  }

  static void reset() {
    _marks.clear();
    _order.clear();
    _clock.reset();
  }
}
