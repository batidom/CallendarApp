import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A [Draggable] that only starts on a long press on touch platforms, so a
/// normal scroll through a list of events doesn't get hijacked into an
/// accidental drag the instant a finger moves. Desktop keeps the plain
/// instant click-and-drag, matching mouse-driven calendar apps where an
/// accidental drag isn't a risk. `LongPressDraggable` also fires a haptic
/// tick on drag start by default, which doubles as the "you're now
/// dragging" cue this was missing.
class EventDraggable<T extends Object> extends StatelessWidget {
  const EventDraggable({
    super.key,
    required this.data,
    required this.feedback,
    required this.childWhenDragging,
    required this.child,
  });

  final T data;
  final Widget feedback;
  final Widget childWhenDragging;
  final Widget child;

  static bool get _isTouchPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (_isTouchPlatform) {
      return LongPressDraggable<T>(
        data: data,
        feedback: feedback,
        childWhenDragging: childWhenDragging,
        child: child,
      );
    }
    return Draggable<T>(
      data: data,
      feedback: feedback,
      childWhenDragging: childWhenDragging,
      child: child,
    );
  }
}
