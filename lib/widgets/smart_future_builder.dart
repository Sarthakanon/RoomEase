import 'package:flutter/material.dart';
import '../services/smart_api_service.dart';
import '../services/state_management_service.dart';

/// Smart future builder with advanced caching, pull-to-refresh, and state management
class SmartFutureBuilder<T> extends StatefulWidget {
  final String screenKey;
  final Future<T> Function({bool forceRefresh}) dataLoader;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final T? initialData;
  final bool enablePullToRefresh;
  final bool enableAutoRefresh;
  final Duration? autoRefreshInterval;
  final String? emptyMessage;

  const SmartFutureBuilder({
    Key? key,
    required this.screenKey,
    required this.dataLoader,
    required this.builder,
    this.errorBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.initialData,
    this.enablePullToRefresh = true,
    this.enableAutoRefresh = false,
    this.autoRefreshInterval,
    this.emptyMessage,
  }) : super(key: key);

  @override
  State<SmartFutureBuilder<T>> createState() => _SmartFutureBuilderState<T>();
}

class _SmartFutureBuilderState<T> extends State<SmartFutureBuilder<T>>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  
  final SmartApiService _smartApi = SmartApiService();
  final StateManagementService _state = StateManagementService();
  
  late Future<T> _future;
  T? _currentData;
  bool _isRefreshing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    
    // Setup auto-refresh if enabled
    if (widget.enableAutoRefresh && widget.autoRefreshInterval != null) {
      _setupAutoRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check if we need to refresh when app comes back to foreground
      if (_state.needsRefresh(widget.screenKey)) {
        _refreshData();
      }
    }
  }

  void _loadData({bool forceRefresh = false}) {
    setState(() {
      _future = widget.dataLoader(forceRefresh: forceRefresh);
    });
  }

  void _refreshData() {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    _loadData(forceRefresh: true);
    
    // Reset refreshing state after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    });
  }

  void _setupAutoRefresh() {
    if (widget.autoRefreshInterval == null) return;
    
    Future.delayed(widget.autoRefreshInterval!, () {
      if (mounted && _state.needsRefresh(widget.screenKey)) {
        _refreshData();
        _setupAutoRefresh(); // Schedule next refresh
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return FutureBuilder<T>(
      future: _future,
      initialData: widget.initialData ?? _currentData,
      builder: (context, snapshot) {
        // Update current data when we get new data
        if (snapshot.hasData && snapshot.data != null) {
          _currentData = snapshot.data;
        }

        // Build the content
        Widget content;
        
        if (snapshot.hasError && _currentData == null) {
          content = _buildError(context, snapshot.error!);
        } else if (snapshot.hasData || _currentData != null) {
          final data = snapshot.data ?? _currentData!;
          
          // Check if data is empty (for lists)
          if (_isDataEmpty(data)) {
            content = _buildEmpty(context);
          } else {
            content = widget.builder(context, data);
          }
        } else {
          content = _buildLoading(context);
        }

        // Wrap with pull-to-refresh if enabled
        if (widget.enablePullToRefresh) {
          return RefreshIndicator(
            onRefresh: () async {
              _refreshData();
              // Wait for the future to complete
              try {
                await _future;
              } catch (e) {
                // Ignore errors in refresh indicator
              }
            },
            child: _wrapWithScrollable(content),
          );
        }

        return content;
      },
    );
  }

  Widget _wrapWithScrollable(Widget child) {
    // If the child is already scrollable, return as is
    if (child is ListView || child is GridView || child is CustomScrollView) {
      return child;
    }
    
    // Wrap non-scrollable content to make pull-to-refresh work
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: child,
    );
  }

  bool _isDataEmpty(T data) {
    if (data is List) return data.isEmpty;
    if (data is Map) {
      final mapData = data as Map<String, dynamic>;
      if (mapData.containsKey('data')) {
        final innerData = mapData['data'];
        if (innerData is List) return innerData.isEmpty;
        if (innerData is Map) return innerData.isEmpty;
      }
      return mapData.isEmpty;
    }
    return false;
  }

  Widget _buildLoading(BuildContext context) {
    if (widget.loadingBuilder != null) {
      return widget.loadingBuilder!(context);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            _isRefreshing ? 'Refreshing...' : 'Loading...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error);
    }

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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            if (widget.enablePullToRefresh)
              Text(
                'Or pull down to refresh',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    if (widget.emptyBuilder != null) {
      return widget.emptyBuilder!(context);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No data available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.emptyMessage ?? 'There\'s nothing to show here yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
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

/// Smart list builder with advanced caching and pull-to-refresh
class SmartListBuilder<T> extends StatelessWidget {
  final String screenKey;
  final Future<List<T>> Function({bool forceRefresh}) dataLoader;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;
  final String? emptyMessage;
  final bool enablePullToRefresh;

  const SmartListBuilder({
    Key? key,
    required this.screenKey,
    required this.dataLoader,
    required this.itemBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.loadingBuilder,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.emptyMessage,
    this.enablePullToRefresh = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SmartFutureBuilder<List<T>>(
      screenKey: screenKey,
      dataLoader: dataLoader,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
      emptyMessage: emptyMessage,
      enablePullToRefresh: enablePullToRefresh,
      emptyBuilder: emptyBuilder,
      builder: (context, items) {
        return ListView.builder(
          physics: physics,
          shrinkWrap: shrinkWrap,
          padding: padding,
          itemCount: items.length,
          itemBuilder: (context, index) => itemBuilder(context, items[index], index),
        );
      },
    );
  }
}