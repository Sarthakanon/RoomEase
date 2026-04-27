import 'package:flutter/material.dart';

/// Mixin to provide auto-refresh functionality after database operations
/// 
/// Usage:
/// 1. Add `with AutoRefreshMixin` to your StatefulWidget's State class
/// 2. Override `refreshData()` method to implement your refresh logic
/// 3. Call `autoRefreshAfterOperation()` after any database operation
mixin AutoRefreshMixin<T extends StatefulWidget> on State<T> {
  
  /// Override this method to implement your screen's refresh logic
  Future<void> refreshData();
  
  /// Call this method after any database operation to auto-refresh the screen
  Future<void> autoRefreshAfterOperation({
    String? successMessage,
    String? errorMessage,
    bool showLoading = false,
  }) async {
    try {
      if (showLoading && mounted) {
        // Show loading indicator if requested
        setState(() {});
      }
      
      // Refresh the data
      await refreshData();
      
      // Show success message if provided
      if (successMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        final message = errorMessage ?? 'Failed to refresh data: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }
  
  /// Wrapper for database operations that automatically refreshes data afterwards
  Future<void> performOperationWithRefresh(
    Future<void> Function() operation, {
    String? successMessage,
    String? errorMessage,
    bool showLoading = true,
  }) async {
    try {
      if (showLoading && mounted) {
        setState(() {});
      }
      
      // Perform the operation
      await operation();
      
      // Auto-refresh after successful operation
      await autoRefreshAfterOperation(
        successMessage: successMessage,
        errorMessage: errorMessage,
        showLoading: false, // Already showed loading above
      );
    } catch (e) {
      if (mounted) {
        final message = errorMessage ?? 'Operation failed: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        setState(() {}); // Reset loading state
      }
    }
  }
}