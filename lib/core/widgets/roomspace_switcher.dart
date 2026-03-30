import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/roomspace_provider.dart';
import '../../models/roomspace_data.dart';

/// Widget for switching between multiple roomspaces
/// Displays a dropdown/bottom sheet UI for roomspace selection
/// Hidden when user has only 1 roomspace
class RoomspaceSwitcher extends StatelessWidget {
  /// Whether to use a compact display (for app bars)
  final bool compact;
  
  /// Optional callback when roomspace is switched
  final VoidCallback? onRoomspaceChanged;

  const RoomspaceSwitcher({
    super.key,
    this.compact = false,
    this.onRoomspaceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomspaceProvider>(
      builder: (context, provider, child) {
        // Show error message if there's an error
        if (provider.error != null && provider.errorType != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showErrorSnackbar(context, provider);
          });
        }
        
        // Hide widget when user has only 1 roomspace
        if (!provider.hasMultipleRoomspaces) {
          return const SizedBox.shrink();
        }

        final activeRoomspace = provider.activeRoomspace;
        
        if (activeRoomspace == null) {
          return const SizedBox.shrink();
        }

        return AbsorbPointer(
          absorbing: provider.isLoading,
          child: Opacity(
            opacity: provider.isLoading ? 0.6 : 1.0,
            child: GestureDetector(
              onTap: () => _showRoomspaceSelector(context, provider),
              child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(compact ? 12 : 16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Color badge with icon
                _RoomspaceIndicator(
                  roomspace: activeRoomspace,
                  size: compact ? 32 : 40,
                ),
                SizedBox(width: compact ? 8 : 12),
                
                // Roomspace name
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        activeRoomspace.name,
                        style: TextStyle(
                          fontSize: compact ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!compact)
                        Text(
                          '${provider.roomspaceCount} roomspaces',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                
                SizedBox(width: compact ? 4 : 8),
                
                // Loading indicator or dropdown indicator
                if (provider.isLoading)
                  SizedBox(
                    width: compact ? 16 : 20,
                    height: compact ? 16 : 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.grey[600]!,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[600],
                    size: compact ? 20 : 24,
                  ),
              ],
            ),
          ),
            ),
          ),
        );
      },
    );
  }
  
  /// Show error snackbar with retry option
  void _showErrorSnackbar(BuildContext context, RoomspaceProvider provider) {
    if (provider.error == null) return;
    
    final errorMessage = provider.getUserFriendlyErrorMessage();
    final canRetry = provider.errorType == RoomspaceErrorType.networkFailure;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 5),
        action: canRetry
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  provider.clearError();
                  provider.retryLastOperation();
                },
              )
            : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    // Clear error after showing
    Future.delayed(const Duration(seconds: 5), () {
      provider.clearError();
    });
  }

  /// Show bottom sheet with roomspace selection options
  void _showRoomspaceSelector(BuildContext context, RoomspaceProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _RoomspaceSelectorSheet(
        provider: provider,
        onRoomspaceChanged: onRoomspaceChanged,
      ),
    );
  }
}

/// Visual indicator showing roomspace color and icon
class _RoomspaceIndicator extends StatelessWidget {
  final RoomspaceData roomspace;
  final double size;

  const _RoomspaceIndicator({
    required this.roomspace,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: roomspace.visualColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size / 4),
        border: Border.all(
          color: roomspace.visualColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Icon(
        roomspace.visualIcon,
        color: roomspace.visualColor,
        size: size * 0.5,
      ),
    );
  }
}

/// Bottom sheet for selecting a roomspace
class _RoomspaceSelectorSheet extends StatefulWidget {
  final RoomspaceProvider provider;
  final VoidCallback? onRoomspaceChanged;

  const _RoomspaceSelectorSheet({
    required this.provider,
    this.onRoomspaceChanged,
  });

  @override
  State<_RoomspaceSelectorSheet> createState() => _RoomspaceSelectorSheetState();
}

class _RoomspaceSelectorSheetState extends State<_RoomspaceSelectorSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeRoomspaceId = widget.provider.activeRoomspace?.id;
    final isLoading = widget.provider.isLoading;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFF8F9FA),
                Colors.white,
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                
                // Header with gradient background
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6366F1).withValues(alpha: 0.1),
                        const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          color: Color(0xFF6366F1),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Switch Roomspace',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A2E),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Select your active space',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${widget.provider.roomspaceCount}/5',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Roomspace list
                Flexible(
                  child: isLoading
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF6366F1),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Switching roomspace...',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Please wait a moment',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          physics: const BouncingScrollPhysics(),
                          itemCount: widget.provider.roomspaces.length,
                          itemBuilder: (context, index) {
                            final roomspace = widget.provider.roomspaces[index];
                            final isActive = roomspace.id == activeRoomspaceId;
                            
                            return _RoomspaceListItem(
                              roomspace: roomspace,
                              isActive: isActive,
                              isDisabled: isLoading,
                              onTap: () async {
                                if (!isActive) {
                                  await widget.provider.setActiveRoomspace(roomspace.id);
                                  widget.onRoomspaceChanged?.call();
                                }
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                            );
                          },
                        ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual roomspace item in the selector list
class _RoomspaceListItem extends StatelessWidget {
  final RoomspaceData roomspace;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDisabled;

  const _RoomspaceListItem({
    required this.roomspace,
    required this.isActive,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 14),
      child: AbsorbPointer(
        absorbing: isDisabled,
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              splashColor: roomspace.visualColor.withValues(alpha: 0.1),
              highlightColor: roomspace.visualColor.withValues(alpha: 0.05),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? LinearGradient(
                          colors: [
                            roomspace.visualColor.withValues(alpha: 0.12),
                            roomspace.visualColor.withValues(alpha: 0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isActive ? null : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? roomspace.visualColor.withValues(alpha: 0.4)
                        : Colors.grey[200]!,
                    width: isActive ? 2.5 : 1.5,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: roomspace.visualColor.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    // Visual indicator with enhanced styling
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            roomspace.visualColor.withValues(alpha: 0.2),
                            roomspace.visualColor.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: roomspace.visualColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: roomspace.visualColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        roomspace.visualIcon,
                        color: roomspace.visualColor,
                        size: 28,
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Roomspace info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  roomspace.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isActive
                                        ? roomspace.visualColor
                                        : const Color(0xFF1A1A2E),
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        roomspace.visualColor,
                                        roomspace.visualColor.withValues(alpha: 0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: roomspace.visualColor.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Active',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.people_rounded,
                                      size: 13,
                                      color: Colors.grey[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${roomspace.memberCount}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.key_rounded,
                                      size: 13,
                                      color: Colors.grey[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      roomspace.inviteCode,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey[700],
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Arrow/Check indicator
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? roomspace.visualColor.withValues(alpha: 0.15)
                            : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive
                            ? Icons.check_circle_rounded
                            : Icons.arrow_forward_ios_rounded,
                        color: isActive ? roomspace.visualColor : Colors.grey[400],
                        size: isActive ? 22 : 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Error display widget for roomspace operations
class RoomspaceErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const RoomspaceErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.red[900],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onDismiss,
                  color: Colors.red[700],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
