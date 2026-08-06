import 'package:flutter/material.dart';

/// A [ListView] with a fade-to-background hint at the bottom edge that only
/// appears while there's more content below the visible area.
class FadingList extends StatefulWidget {
  const FadingList({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  State<FadingList> createState() => _FadingListState();
}

class _FadingListState extends State<FadingList> {
  final _controller = ScrollController();
  bool _hasMoreBelow = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateFade);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFade());
  }

  @override
  void didUpdateWidget(covariant FadingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The list content (e.g. selected day, backlog) may have changed size
    // without a scroll event, so re-check after the new layout settles.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFade());
  }

  void _updateFade() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final hasMore =
        position.maxScrollExtent > 0 &&
        position.pixels < position.maxScrollExtent - 2;
    if (hasMore != _hasMoreBelow && mounted) {
      setState(() => _hasMoreBelow = hasMore);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          controller: _controller,
          padding: widget.padding,
          children: widget.children,
        ),
        if (_hasMoreBelow)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 20,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).scaffoldBackgroundColor.withAlpha(0),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
