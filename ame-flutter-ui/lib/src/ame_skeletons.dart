import 'package:flutter/material.dart';

/// Shimmer placeholder widget for unresolved Ref nodes during streaming.
///
/// Per streaming.md:
/// - MUST occupy the layout slot where the resolved component will appear
/// - SHOULD render as a shimmer rectangle (animated sweeping gradient)
/// - MUST NOT be interactive
class AmeSkeleton extends StatefulWidget {
  final double height;

  const AmeSkeleton({super.key, this.height = 48});

  @override
  State<AmeSkeleton> createState() => _AmeSkeletonState();
}

class _AmeSkeletonState extends State<AmeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = _controller.value * 3.0 - 1.0;
        return Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(offset - 1.0, 0),
              end: Alignment(offset + 1.0, 0),
              colors: const [
                Color(0x4DD0D0D0),
                Color(0x1AD0D0D0),
                Color(0x4DD0D0D0),
              ],
            ),
          ),
        );
      },
    );
  }
}
