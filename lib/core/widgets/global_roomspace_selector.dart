import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/roomspace_provider.dart';
import '../../models/roomspace_data.dart';

/// Global roomspace selector widget for app bar
/// Displays current roomspace/personal space and allows switching
class GlobalRoomspaceSelector extends StatefulWidget {
  final VoidCallback? onRoomspaceChanged;

  const GlobalRoomspaceSelector({
    super.key,
    this.onRoomspaceChanged,
  });

  @override
  State<GlobalRoomspaceSelector> createState() => _GlobalRoomspaceSelectorState();
}

class _GlobalRoomspaceSelectorState extends State<GlobalRoomspaceSelector> {
  @override
  Widget build(BuildContext context) {
    return Consumer<RoomspaceProvider>(
      builder: (context, roomspaceProvider, child) {
        final activeRoomspace = roomspaceProvider.activeRoomspace;
        final primaryColor = Theme.of(context).colorScheme.primary;

        return GestureDetector(
          onTap: () => _showRoomspaceMenu(context, roomspaceProvider, primaryColor),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.9),
                  primaryColor.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                if (activeRoomspace != null)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      activeRoomspace.visualIcon,
                      size: 14,
                      color: Colors.white,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                const SizedBox(width: 8),
                // Text
                Flexible(
                  child: Text(
                    activeRoomspace?.name ?? 'Personal',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                // Dropdown arrow
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRoomspaceMenu(
    BuildContext context,
    RoomspaceProvider roomspaceProvider,
    Color primaryColor,
  ) {
    final activeRoomspace = roomspaceProvider.activeRoomspace;
    final roomspaces = roomspaceProvider.roomspaces;

    final items = <PopupMenuEntry<String>>[
      // Personal Space option
      PopupMenuItem<String>(
        value: 'personal',
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.person_rounded,
                size: 14,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Personal Space',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Your personal expenses',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (activeRoomspace == null)
              Icon(
                Icons.check_rounded,
                size: 16,
                color: primaryColor,
              ),
          ],
        ),
      ),
      // Divider
      if (roomspaces.isNotEmpty)
        const PopupMenuDivider(),
      // Roomspaces
      ...roomspaces.map((roomspace) {
        final isActive = activeRoomspace?.id == roomspace.id;
        return PopupMenuItem<String>(
          value: roomspace.id,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: roomspace.visualColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  roomspace.visualIcon,
                  size: 14,
                  color: roomspace.visualColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      roomspace.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${roomspace.memberCount} member${roomspace.memberCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: primaryColor,
                ),
            ],
          ),
        );
      }).toList(),
      // Divider before Add New
      const PopupMenuDivider(),
      // Add New Roomspace option
      PopupMenuItem<String>(
        value: 'add_new',
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.add_rounded,
                size: 14,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Add New Roomspace',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 200,
        kToolbarHeight + 10,
        20,
        0,
      ),
      items: items,
      elevation: 8,
    ).then((value) {
      if (value != null) {
        // Handle navigation immediately without async
        if (value == 'add_new') {
          if (mounted) {
            Navigator.pushNamed(context, '/settings');
          }
          return;
        }
        
        // Handle personal space
        if (value == 'personal') {
          _switchToPersonalSpace(context, roomspaceProvider);
          return;
        }
        
        // Handle roomspace switching (async operation)
        _switchRoomspace(context, roomspaceProvider, value);
      }
    });
  }
  
  Future<void> _switchToPersonalSpace(
    BuildContext context,
    RoomspaceProvider roomspaceProvider,
  ) async {
    try {
      await roomspaceProvider.switchToPersonalSpace();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Switched to Personal Space'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        widget.onRoomspaceChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to switch to personal space'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _switchRoomspace(
    BuildContext context,
    RoomspaceProvider roomspaceProvider,
    String roomspaceId,
  ) async {
    try {
      await roomspaceProvider.setActiveRoomspace(roomspaceId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to "${roomspaceProvider.getRoomspaceById(roomspaceId)?.name ?? 'Roomspace'}"'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        widget.onRoomspaceChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to switch roomspace'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
