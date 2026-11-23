import 'dart:async';

import 'package:flutter/material.dart';

/// Parent-side handle for an [AppTypewriterText].
///
/// Lets the page answer "is this page still being written?" and jump to the
/// end of the reveal without owning the ticker.
class TypewriterHandle {
  VoidCallback? _complete;
  bool Function()? _isDone;

  /// True when every character is already on screen (or there is no text).
  bool get isDone => _isDone?.call() ?? true;

  /// Reveals the rest of the current text at once.
  void complete() => _complete?.call();

  void _bind({
    required VoidCallback complete,
    required bool Function() isDone,
  }) {
    _complete = complete;
    _isDone = isDone;
  }

  void _unbind() {
    _complete = null;
    _isDone = null;
  }
}

/// Reveals [text] one character at a time, pausing on punctuation.
///
/// [charsPerSecond] <= 0 shows everything at once. Changing [text] restarts
/// the reveal from the first character.
class AppTypewriterText extends StatefulWidget {
  const AppTypewriterText({
    super.key,
    required this.text,
    required this.style,
    required this.handle,
    this.charsPerSecond = 28,
    this.maxLines,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle style;
  final TypewriterHandle handle;
  final double charsPerSecond;
  final int? maxLines;
  final TextAlign textAlign;

  @override
  State<AppTypewriterText> createState() => _AppTypewriterTextState();
}

class _AppTypewriterTextState extends State<AppTypewriterText> {
  static const Duration _frame = Duration(milliseconds: 16);

  Timer? _timer;
  List<double> _offsets = const <double>[];
  int _visible = 0;
  double _elapsedMs = 0;

  @override
  void initState() {
    super.initState();
    _bindHandle();
    _restart();
  }

  @override
  void didUpdateWidget(covariant AppTypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) {
      oldWidget.handle._unbind();
      _bindHandle();
    }
    if (oldWidget.text != widget.text ||
        oldWidget.charsPerSecond != widget.charsPerSecond) {
      _restart();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.handle._unbind();
    super.dispose();
  }

  void _bindHandle() {
    widget.handle._bind(
      complete: _complete,
      isDone: () => _visible >= widget.text.length,
    );
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    final text = widget.text;
    if (text.isEmpty || widget.charsPerSecond <= 0) {
      _visible = text.length;
      return;
    }
    _visible = 0;
    _elapsedMs = 0;
    _offsets = _schedule(text, widget.charsPerSecond);
    // Put the first character up immediately; only the rest needs the clock.
    _visible = 1;
    _timer = Timer.periodic(_frame, (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    // Counting frames instead of reading a wall clock keeps the reveal
    // deterministic in tests and immune to timer jitter.
    _elapsedMs += _frame.inMilliseconds;
    var count = 0;
    while (count < _offsets.length && _offsets[count] <= _elapsedMs) {
      count++;
    }
    if (count != _visible) {
      setState(() => _visible = count);
    }
    if (count >= widget.text.length) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _complete() {
    if (_visible >= widget.text.length) return;
    _timer?.cancel();
    _timer = null;
    setState(() => _visible = widget.text.length);
  }

  /// Milliseconds at which each character should appear.
  static List<double> _schedule(String text, double charsPerSecond) {
    final base = 1000 / charsPerSecond;
    final offsets = <double>[];
    var at = 0.0;
    for (var i = 0; i < text.length; i++) {
      offsets.add(at);
      at += base * _pauseFactor(text[i]);
    }
    return offsets;
  }

  /// Longer beats after sentence marks, short ones after clause marks.
  static double _pauseFactor(String char) {
    switch (char) {
      case '。':
      case '！':
      case '？':
      case '…':
      case '.':
      case '!':
      case '?':
        return 4;
      case '，':
      case '、':
      case '；':
      case '：':
      case '—':
      case ',':
      case ';':
      case ':':
      case '\n':
        return 2;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _visible >= widget.text.length
        ? widget.text
        : widget.text.substring(0, _visible);
    return Text(
      shown,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: TextOverflow.clip,
      textAlign: widget.textAlign,
    );
  }
}
