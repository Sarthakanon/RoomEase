import 'package:flutter/material.dart';

class OptimizedFutureBuilder<T> extends StatefulWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final T? initialData;
  final Duration? timeout;
  final bool showRetry;

  const OptimizedFutureBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.errorBuilder,
    this.loadingBuilder,
    this.initialData,
    this.timeout,
    this.showRetry = true,
  });

  @override
  State<OptimizedFutureBuilder<T>> createState() => _OptimizedFutureBuilderState<T>();
}

class _OptimizedFutureBuilderState<T> extends State<OptimizedFutureBuilder<T>> {
  late Future<T> _future;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _future = widget.timeout != null 
        ? widget.future.timeout(widget.timeout!)
        : widget.future;
  }

  void _retry() {
    setState(() {
      _isRetrying = true;
      _future = widget.timeout != null 
          ? widget.future.timeout(widget.timeout!)
          : widget.future;
    });
    
    // Reset retry state after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      initialData: widget.initialData,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return widget.errorBuilder?.call(context, snapshot.error!) ??
              _buildDefaultError(context, snapshot.error!);
        }

        if (snapshot.hasData) {
          return widget.builder(context, snapshot.data as T);
        }

        return widget.loadingBuilder?.call(context) ??
            _buildDefaultLoading(context);
      },
    );
  }

  Widget _buildDefaultLoading(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _isRetrying ? 'Retrying...' : 'Loading...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultError(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getErrorMessage(error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            if (widget.showRetry) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isRetrying ? null : _retry,
                icon: _isRetrying 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_isRetrying ? 'Retrying...' : 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getErrorMessage(Object error) {
    final errorStr = error.toString();
    
    if (errorStr.contains('timeout') || errorStr.contains('TimeoutException')) {
      return 'Request timed out. Please check your connection and try again.';
    }
    
    if (errorStr.contains('connection') || errorStr.contains('network')) {
      return 'Network error. Please check your internet connection.';
    }
    
    if (errorStr.contains('server') || errorStr.contains('500')) {
      return 'Server error. Please try again later.';
    }
    
    if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
      return 'Session expired. Please login again.';
    }
    
    return 'An unexpected error occurred. Please try again.';
  }
}

// Specialized builders for common use cases
class OptimizedListBuilder<T> extends StatelessWidget {
  final Future<List<T>> future;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const OptimizedListBuilder({
    super.key,
    required this.future,
    required this.itemBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.loadingBuilder,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedFutureBuilder<List<T>>(
      future: future,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
      builder: (context, items) {
        if (items.isEmpty) {
          return emptyBuilder?.call(context) ?? 
              const Center(child: Text('No items found'));
        }

        return ListView.builder(
          physics: physics,
          shrinkWrap: shrinkWrap,
          itemCount: items.length,
          itemBuilder: (context, index) => itemBuilder(context, items[index], index),
        );
      },
    );
  }
}