import 'package:flutter/material.dart';

/// Skeleton loader widget for showing loading placeholders
/// Used while fetching roomspace data and other content
class SkeletonLoader extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final EdgeInsets? margin;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height = 20,
    this.borderRadius,
    this.margin,
  });

  /// Creates a circular skeleton loader (for avatars, icons, etc.)
  const SkeletonLoader.circular({
    super.key,
    required double size,
    this.margin,
  })  : width = size,
        height = size,
        borderRadius = null;

  /// Creates a rectangular skeleton loader with rounded corners
  const SkeletonLoader.rounded({
    super.key,
    this.width,
    required this.height,
    double radius = 8,
    this.margin,
  }) : borderRadius = const BorderRadius.all(Radius.circular(8));

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ??
        (widget.width == widget.height
            ? BorderRadius.circular(widget.height / 2)
            : BorderRadius.circular(4));

    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.grey[300]!,
                  Colors.grey[200]!,
                  Colors.grey[300]!,
                ],
                stops: [
                  _animation.value - 0.3,
                  _animation.value,
                  _animation.value + 0.3,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton loader for roomspace list items
class RoomspaceListSkeleton extends StatelessWidget {
  final int itemCount;

  const RoomspaceListSkeleton({
    super.key,
    this.itemCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              // Icon skeleton
              const SkeletonLoader.circular(size: 48),
              const SizedBox(width: 16),
              // Text skeletons
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader.rounded(
                      width: double.infinity,
                      height: 16,
                      margin: const EdgeInsets.only(bottom: 8),
                    ),
                    SkeletonLoader.rounded(
                      width: 120,
                      height: 14,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Skeleton loader for dashboard cards
class DashboardCardSkeleton extends StatelessWidget {
  const DashboardCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader.rounded(
            width: 100,
            height: 14,
            margin: const EdgeInsets.only(bottom: 12),
          ),
          SkeletonLoader.rounded(
            width: double.infinity,
            height: 24,
            margin: const EdgeInsets.only(bottom: 8),
          ),
          SkeletonLoader.rounded(
            width: 150,
            height: 14,
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for expense list items
class ExpenseListSkeleton extends StatelessWidget {
  final int itemCount;

  const ExpenseListSkeleton({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const SkeletonLoader.circular(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader.rounded(
                      width: double.infinity,
                      height: 16,
                      margin: const EdgeInsets.only(bottom: 8),
                    ),
                    SkeletonLoader.rounded(
                      width: 100,
                      height: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SkeletonLoader.rounded(
                width: 60,
                height: 20,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Skeleton loader for analytics charts
class AnalyticsChartSkeleton extends StatelessWidget {
  const AnalyticsChartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader.rounded(
            width: 150,
            height: 18,
            margin: const EdgeInsets.only(bottom: 16),
          ),
          SkeletonLoader.rounded(
            width: double.infinity,
            height: 200,
          ),
        ],
      ),
    );
  }
}
