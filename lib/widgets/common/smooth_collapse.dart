import 'package:flutter/material.dart';

/// Smoothly expands and collapses [child] with a combined vertical clip/size
/// and opacity transition, keeping [child] mounted until the collapse finishes
/// so content never pops out abruptly on the first frame.
class SmoothCollapse extends StatefulWidget {
  final bool expanded;
  final Widget child;
  final Duration duration;
  final Curve curve;

  const SmoothCollapse({
    super.key,
    required this.expanded,
    required this.child,
    this.duration = const Duration(milliseconds: 240),
    this.curve = Curves.easeInOutCubic,
  });

  @override
  State<SmoothCollapse> createState() => _SmoothCollapseState();
}

class _SmoothCollapseState extends State<SmoothCollapse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.expanded ? 1.0 : 0.0,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(SmoothCollapse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.expanded != oldWidget.expanded) {
      if (widget.expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final closed = !widget.expanded && _controller.isDismissed;
    return SizeTransition(
      sizeFactor: _curve,
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: _curve,
        child: closed ? const SizedBox(width: double.infinity) : widget.child,
      ),
    );
  }
}
