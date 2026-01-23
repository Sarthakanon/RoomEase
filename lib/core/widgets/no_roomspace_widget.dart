import 'package:flutter/material.dart';

/// Widget displayed when user has no roomspaces
/// Prompts user to create or join a roomspace
class NoRoomspaceWidget extends StatelessWidget {
  final VoidCallback? onCreateRoomspace;
  final VoidCallback? onJoinRoomspace;

  const NoRoomspaceWidget({
    super.key,
    this.onCreateRoomspace,
    this.onJoinRoomspace,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.home_outlined,
                size: 60,
                color: Colors.blue[700],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              'No Roomspaces Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            // Description
            Text(
              'Create a new roomspace or join an existing one to start tracking expenses with your roommates.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // Action buttons
            Column(
              children: [
                if (onCreateRoomspace != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onCreateRoomspace,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Create Roomspace'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                
                if (onCreateRoomspace != null && onJoinRoomspace != null)
                  const SizedBox(height: 12),
                
                if (onJoinRoomspace != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onJoinRoomspace,
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Join Roomspace'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.blue[700]!, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
